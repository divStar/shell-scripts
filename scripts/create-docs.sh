#!/bin/bash
export SCRIPT_NAME="create-docs.sh" # Script name
export SCRIPT_VERSION="v1.0.1-BETA"       # Script version

# create-docs.sh
#
# This script creates the documentation for a PlatformIO project using Doxygen.
# It contains many steps and relies on particular files, folders and tools to be present.
#
# Usage:
#   - ensure `./public` output folder exists and is writable
#   - ensure `./library.json` or `./platformio.ini` (with custom tags) exists
#   - ensure the tools `yq`, `envsubst` and `doxygen` are installed and available
#   - run this script
#
# Exit codes:
#   0   - Script exited successfully (without an error).
#   1   - Script exited, because neither a `./library.json` nor a `./platformio.ini` was found.
#   2   - Script exited, because a tool is not installed or available (see [Prerequisites](#prerequisites)).
#   3   - Script exited, because the source file (`./library.json` or `./platformio.ini`) does not exist.
#   4   - Script exited, because the source file does not contain any relevant metadata fields.
#   5   - Script exited, because values could not be retrieved from either `./library.json` or `./platformio.ini`.
#   6   - Script exited, because an expected template file does not exist.
#   7   - Script exited, because it failed to successfully execute `doxygen`.
#   8   - Script exited, because it failed to copy misc files.
#   9   - Script exited, because it failed to delete templated files.
#   10  - Script exited, because it failed to delete an existing vx.x.x directory.
#   11  - Script exited, because it failed to move generated html directory into the public directory.

script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/logging-func.sh"
source "$script_dir/utils-func.sh"

# Inputs / mounts
GEN_TARGET="./public"                  # target folder (usually output is written to $GEN_TARGET/html)
LIBRARY_JSON_SOURCE="library.json"     # default custom_file to use to retrieve metadata
PLATFORMIO_INI_SOURCE="platformio.ini" # another source for metadata
# also: ./src and ./include, since these folders are the sources

# Definitions
DOXY_CONFIG="./doxy-config"                        # configuration folder containing various Doxygen-related files
DOXY_FILE="Doxyfile"                               # Doxygen configuration custom_file
DOXY_HEADER_TEMPLATE="doxy-header-template.html"   # Doxygen HTML header template
DOXY_HEADER="doxy-header.html"                     # Doxygen HTML header
DOXY_FOOTER_TEMPLATE="doxy-footer-template.html"   # Doxygen HTML footer template
DOXY_FOOTER="doxy-footer.html"                     # Doxygen HTML footer
DOXY_STYLESHEET_TEMPLATE="doxy-style-template.css" # Doxygen CSS stylesheet template
DOXY_STYLESHEET="doxy-style.css"                   # Doxygen CSS stylesheet
MISC_SOURCE="./doxy-misc"                          # folder containing additional files for documentation
MISC_TARGET="$GEN_TARGET/html"                     # actual target folder

declare -Ag metadata_mappings
declare -ag metadata_values
metadata_source_filename=''
inputType=''
yq_filter=''

# Functions

# Check if either 'library.json' or 'platformio.ini' is present
find_metadata_source() {
  log_info "Finding 'library.json' or 'platformio.ini' to use..."
  if [[ -f "$LIBRARY_JSON_SOURCE" ]]; then
    metadata_source_filename="$LIBRARY_JSON_SOURCE"
    inputType="json"
    metadata_mappings["PRJ_NAME"]=".name"
    metadata_mappings["PRJ_DESCRIPTION"]=".description"
    metadata_mappings["PRJ_VERSION"]=".version"
    metadata_mappings["PRJ_AUTHOR"]=".authors.name"
    metadata_mappings["PRJ_LOGO"]=".logo"
  elif [[ -f "$PLATFORMIO_INI_SOURCE" ]]; then
    metadata_source_filename="$PLATFORMIO_INI_SOURCE"
    inputType="props"
    metadata_mappings["PRJ_NAME"]=".name"
    metadata_mappings["PRJ_DESCRIPTION"]=".description"
    metadata_mappings["PRJ_VERSION"]=".custom_version"
    metadata_mappings["PRJ_AUTHOR"]=".custom_authors"
    metadata_mappings["PRJ_LOGO"]=".custom_logo"
  else
    log_error " ✖ FAILED"
    log_newline
    log_error "Error: Neither 'library.json' nor 'platformio.ini' were found!"
    log_newline
    exit 1
  fi
  log_info "'"
  log_highlight "$metadata_source_filename"
  log_info "'"
  log_success " ✔ DONE"
  log_newline
}

# Find metadata_mappings and build 'yq' filter
build_yq_filter() {
  local metadata_mapping

  log_info "Finding "
  log_highlight "metadata_mappings"
  log_info " and building '"
  log_highlight "yq"
  log_info "' filter..."
  if [[ ${#metadata_mappings[@]} -gt 0 ]]; then
    yq_filter='{'
    for metadata_mapping in "${!metadata_mappings[@]}"; do
      value="${metadata_mappings[$metadata_mapping]}"
      yq_filter+="\"$metadata_mapping\": $value,"
    done
    yq_filter=${yq_filter%,} # Remove trailing comma
    yq_filter+='} |
      to_entries |
      .[] |
      select(.value | length > 0) |
      "export " + .key + "=\"" + .value + "\""'
    log_success " ✔ DONE"
    log_newline
  else
    log_error " ✖ FAILED"
    log_newline
    log_error "No valid metadata found in '$metadata_source_filename'!"
    log_newline
    exit 3
  fi
}

# Retrieve values using 'yq'
get_metadata() {
  local yq_output
  local metadata_value
  local yq_error

  log_info "Retrieving values from '"
  log_highlight "$metadata_source_filename"
  log_info "'..."

  if [[ ! -f "$metadata_source_filename" ]]; then
    log_error " ✖ FAILED"
    log_newline
    log_error "File '$metadata_source_filename' does not exist!"
    log_newline
    exit 4
  fi

  yq_output=$(yq 'eval' "$yq_filter" "$metadata_source_filename" -r -p="$inputType" -o=props)

  if [[ ${#yq_output} -ne 0 ]]; then
    mapfile -t metadata_values <<<"$yq_output"
    log_success " ✔ DONE"
    log_newline
    for metadata_value in "${metadata_values[@]}"; do
      log_highlight "${metadata_value:7}"
      log_newline
    done
  else
    log_error " ✖ FAILED"
    log_newline
    log_error "$yq_error"
    log_newline
    log_error "Could not retrieve values from '$metadata_source_filename'!"
    log_newline
    exit 5
  fi
}

# Process environment variables on header and footer HTML templates
preprocess_templates() {
  local variables_to_substitute
  local metadata_value
  local subst_var_name

  log_info "Preprocess template HTML and CSS files..."
  eval "${metadata_values[*]}"

  # Check if the template files are present and exit if not
  local template_file
  for template_file in \
    "$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE" \
    "$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE" \
    "$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE"; do
    if [[ ! -e $template_file ]]; then
      log_error " ✖ FAILED"
      log_newline
      log_error "Template file '$template_file' does not exist!"
      log_newline
      exit 6
    fi
  done

  # Extract variable names from metadata_values (just the PRJ_* part), prepend each with a '$' and join using ','
  variables_to_substitute=""
  for metadata_value in "${metadata_values[@]}"; do
    subst_var_name="${metadata_value#* }"
    subst_var_name="${subst_var_name%%=*}"
    if [ -z "$variables_to_substitute" ]; then
      variables_to_substitute="\$$subst_var_name"
    else
      variables_to_substitute="$variables_to_substitute,\$$subst_var_name"
    fi
  done

  # Filter header and footer HTML files
  envsubst "$variables_to_substitute" <"$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE" >"$DOXY_CONFIG/$DOXY_HEADER"
  envsubst "$variables_to_substitute" <"$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE" >"$DOXY_CONFIG/$DOXY_FOOTER"
  envsubst "$variables_to_substitute" <"$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE" >"$DOXY_CONFIG/$DOXY_STYLESHEET"
  log_success " ✔ DONE"
  log_newline
}

# Generate docs using doxygen
generate_docs() {
  local doxygen_run

  log_info "Generating docs using '"
  log_highlight "doxygen $DOXY_CONFIG/$DOXY_FILE"
  log_info "'..."
  if doxygen_run=$(doxygen "$DOXY_CONFIG/$DOXY_FILE" 2>&1 >/dev/null); then
    log_success " ✔ DONE"
    log_newline
  else
    log_error " ✖ FAILED"
    log_newline
    log_error "doxygen failed to generate docs!"
    log_newline
    log_error "$doxygen_run"
    log_newline
    exit 7
  fi
}

# Copy misc files
copy_misc_files() {
  # Copy misc directory contents to public directory
  log_info "Copying '"
  log_highlight "$MISC_SOURCE/*"
  log_info "' to '"
  log_highlight "$MISC_TARGET"
  log_info "'..."

  if cp "$MISC_SOURCE/"* "$MISC_TARGET"; then
    log_success " ✔ DONE"
    log_newline
  else
    log_error " ✖ FAILED"
    log_newline
    log_error "Failed to copy misc files!"
    log_newline
    exit 8
  fi
}

# Remove templated files after the docs have been generated
delete_generated_template_files() {
  log_info "Deleting templated files..."

  for generated_file in \
    "$DOXY_CONFIG/$DOXY_HEADER" \
    "$DOXY_CONFIG/$DOXY_FOOTER" \
    "$DOXY_CONFIG/$DOXY_STYLESHEET"; do
    if ! rm -rf "$generated_file"; then
      log_error " ✖ FAILED"
      log_newline
      log_error "Could not delete generated file '$generated_file'!"
      log_newline
      exit 9
    fi
  done

  log_success " ✔ DONE"
  log_newline
}

# Rename html directory to version
rename_html_directory() {
  log_info "Renaming '"
  log_highlight "$GEN_TARGET/html/"
  log_info "' to '"
  log_highlight "$GEN_TARGET/v$PRJ_VERSION/"
  log_info "'..."
  if test -e "$GEN_TARGET/v$PRJ_VERSION"; then
    # Attempt to delete the file or directory
    rm -rf "$GEN_TARGET/v$PRJ_VERSION" || {
      # Log an error and exit if the deletion fails
      log_error " ✖ FAILED"
      log_newline
      log_error "Could not delete '$GEN_TARGET/v$PRJ_VERSION'!"
      log_newline
      exit 10
    }
  fi
  if ! mv "$GEN_TARGET/html" "$GEN_TARGET/v$PRJ_VERSION" >/dev/null; then
    log_error " ✖ FAILED"
    log_newline
    log_error "Could not move '$GEN_TARGET/html' to '$GEN_TARGET/v$PRJ_VERSION'!"
    log_newline
    exit 11
  fi
  log_success " ✔ DONE"
  log_newline
}

# Main script
main() {
  log_application_header

  find_metadata_source

  command_exists 'envsubst'
  command_exists 'yq'
  command_exists 'doxygen'

  build_yq_filter

  get_metadata

  preprocess_templates

  generate_docs

  copy_misc_files

  delete_generated_template_files

  rename_html_directory
}

# Check if the script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
