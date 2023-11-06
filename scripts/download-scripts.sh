#!/bin/bash
export SCRIPT_NAME="download-scripts.sh" # Script name
export SCRIPT_VERSION="unset"            # Script version

# download-scripts.sh
#
# This script downloads scripts to the current working directory.
#
# Usage:
#   - run this script
#   - specify the scripts you want to download
#   - specify configuration (necessary if not using default values)
#
# Exit codes:
#   1 - Script exits, because an unknown argument was given
#   2 - Script exits, because no scripts to extract are present
#   3 - Script exits, because the list of asset archives could not be downloaded
#   4 - Script exits, because the asset archive could not be downloaded
#   5 - Script exits, because the desired scripts could not be extracted
#
# Notes:
#   1. This script is self-sufficient, because unlike other scripts it does not 'source' any other script
#   2. See 'handle_arguments' for configuration details
#   3. 'shell_scripts_url' and 'filter_asset_type_value' are functions;
#      this is because they must re-evaluate their variables everytime they're executed

LATEST_URL_SUFFIX="permalink/latest"

shell_scripts_project_id="14"
shell_scripts_version=""
base_url="https://gitlab.my.family"
private_token="f4Dw3zX2cwhPcfZ61Akf"
asset_type="zip"
dashes="---"

declare -a scripts

# Determine if we have a Terminal capable of at least 8 colors
if [ -t 1 ] && [ "$(tput colors)" -ge 8 ]; then
  ERROR_COLOR="\033[31m"
  SUCCESS_COLOR="\033[32m"
  HIGHLIGHT_COLOR="\033[34m"
  RESET="\033[0m"
fi

shell_scripts_url() {
  echo "$base_url/api/v4/projects/$shell_scripts_project_id/releases"
}

filter_asset_type_value() {
  echo ".assets.sources[] | select(.format == \"$asset_type\").url"
}

# Logs the application header to STDOUT. See function itself for template.
# Parameters: none.
log_application_header() {
  local total_length
  total_length=$((${#SCRIPT_NAME} + ${#SCRIPT_VERSION} + 3))
  dashes=$(printf '%0.s-' $(seq 1 $total_length))
  printf "%s - $HIGHLIGHT_COLOR%s$RESET\n%s\n" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$dashes"
}

log_global_variables() {
  printf "%s: $HIGHLIGHT_COLOR%s$RESET\n" "shell_scripts_project_id" "$shell_scripts_project_id"
  printf "%s: $HIGHLIGHT_COLOR%s$RESET\n" "shell_scripts_version" "${shell_scripts_version:-latest}"
  printf "%s: $HIGHLIGHT_COLOR%s$RESET\n" "base_url" "$base_url"
  printf "%s: $HIGHLIGHT_COLOR%s$RESET\n" "private_token" "*******"
  printf "%s: $HIGHLIGHT_COLOR%s$RESET\n" "asset_type" "$asset_type"

  local joined_scripts
  joined_scripts="${scripts[*]}"
  printf "scripts: $HIGHLIGHT_COLOR%s$RESET\n" "${joined_scripts// /, }"
}

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS] <script1> [<script2>...]

Options:
  -ssid, --shell-scripts-project-id   sets the Shell Scripts project ID (default: 14)
  -v, --shell-scripts-version         sets the version of the Shell Scripts repository to use (default: latest)
  -u, --base-url                      sets the base URL for the request (default: https://gitlab.my.family)
  -p, --private-token                 sets the PRIVATE-TOKEN value (default is set)
  -t, --asset-type                    sets the type of asset to process (values: zip, tar, tar.gz, tar.bz2; default is zip)
  -h, --help                          displays this help message and exit.

<script*>                             script to download including path (e.g. 'scripts/create-docs.sh')

Examples:
  $0 "create-docs" "utils-func" "logging-func"
EOF
}

# Handles script input arguments.
# Parameters: none.
# Returns: none.
# Exit codes:
#   1 - Script exits, because an unknown argument was given
#   2 - Script exits, because no scripts to extract are present
handle_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -ssid | --shell-scripts-project-id)
      shell_scripts_project_id="$2"
      shift 1
      ;;
    -v | --shell-scripts-version)
      shell_scripts_version="$2"
      shift 1
      ;;
    -u | --base-url)
      base_url="$2"
      shift 1
      ;;
    -p | --private-token)
      private_token="$2"
      shift 1
      ;;
    -t | --asset-type)
      asset_type="$2"
      shift 1
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    -*)
      echo "Unknown parameter: $1"
      exit 1
      ;;
    *)
      break # Exit the loop if a positional argument is encountered
      ;;
    esac
    shift
  done

  # Collect all remaining arguments as script names
  while [[ "$#" -gt 0 ]]; do
    scripts+=("$1")
    shift
  done

  # Check if the scripts array is empty
  if [[ ${#scripts[@]} -eq 0 ]]; then
    printf "$ERROR_COLOR%s$RESET\n" "Error: No scripts specified. Please specify the scripts to download."
    exit 2
  fi
}

# Downloads a list of asset archives for the given version.
# Parameters: none.
# Returns:
#   the result of `yq eval ...`
# Exit codes:
#   3 - Script exits, because the list of asset archives could not be downloaded
# Notes:
#   Subsequent functions expect the filtered output of `yq eval ...` if they're executed
get_asset_archive_url() {
  # Send the HTTP request and save the response body to a temporary file
  local response_body
  local status_code
  response_body=$(mktemp)
  status_code=$(curl --silent --location --max-redirs 1 --write-out "%{http_code}" --header "PRIVATE-TOKEN: $private_token" "$(shell_scripts_url)/${shell_scripts_version:-$LATEST_URL_SUFFIX}" -o "$response_body")

  # Check the status code for a 2xx response
  if [[ $status_code == 2* ]]; then
    # On a 2xx response, process the response body with yq
    yq eval "$(filter_asset_type_value)" "$response_body"
  else
    # On a non-2xx response, display an error message and exit
    printf "$ERROR_COLOR%s$RESET\n" "Could not get release information: received HTTP status code $status_code" >&2
    exit 3
  fi

  # Clean up the temporary file
  rm "$response_body"
}

# Downloads an asset archive.
# Parameters:
#   $1 - URL of the asset to download
# Returns: nothing.
# Exit codes:
#   4 - Script exits, because the asset archive could not be downloaded
# Notes:
#   1. Function does not return anything, but does download a file
#   2. Subsequent functions expect the file to be present
download_asset_archive() {
  local asset_url
  local status_code

  asset_url="$1"
  status_code=$(curl --silent --write-out "%{http_code}" --header "PRIVATE-TOKEN: $private_token" --remote-name "$asset_url")

  # Check the status code for a 2xx response
  if ! [[ $status_code == 2* ]]; then
    # On a non-2xx response, display an error message and exit
    printf "${ERROR_COLOR}Could not download '%s': received HTTP status code %s$RESET\n" "$asset_url" "$status_code" >&2
    exit 4
  fi
}

# Extracts given ${scripts} from the asset archive (zip, tar, tar.gz or tar.bz2) into the current working directory.
# Parameters:
#   $1 - filename of the asset archive (without the extension, e.g. 'shell-scripts-v1.0.11')
#   $2 - extension of the asset archive ($asset_type, one of [zip, tar, tar.gz, tar.bz2], default: zip)
# Returns: nothing.
# Exit codes:
#   5 - Script exits, because the desired scripts could not be extracted
# Notes:
#   1. tar.gz or tar.bz2 are the smallest
#   2. 'unzip' and 'tar' commands are used; these might not work on Windows
#   3. tools are quite; they mostly report errors only
# shellcheck disable=2086
extract_asset_archive() {
  local asset_archive_filename
  local asset_archive_extension
  local script
  local scripts_arg
  local exit_code

  asset_archive_filename="$1"
  asset_archive_extension="$2"

  for script in "${scripts[@]}"; do
    scripts_arg+="$asset_archive_filename/$script "
  done

  case "$asset_type" in
  "zip")
    unzip -j -o -q "$asset_archive_filename.$asset_archive_extension" $scripts_arg
    ;;
  "tar")
    tar --strip-components=2 -xf "$asset_archive_filename.$asset_archive_extension" $scripts_arg
    ;;
  "tar.gz")
    tar --strip-components=2 -zxf "$asset_archive_filename.$asset_archive_extension" $scripts_arg
    ;;
  "tar.bz2")
    tar --strip-components=2 -jxf "$asset_archive_filename.$asset_archive_extension" $scripts_arg
    ;;
  *)
    printf "$ERROR_COLOR%s$RESET\n" "Error: unknown asset archive type ('$asset_type')."
    exit 5
    ;;
  esac

  exit_code=$?
  if [[ exit_code -gt 0 ]]; then
    printf "$ERROR_COLOR%s$RESET\n" "Error: scripts could not be extracted (see actual error above)."
    exit 6
  fi
}

# Main function of the script. It downloads the desired scripts using the given configuration.
# Parameters: see `handle_arguments` for allowed script arguments.
# Returns: nothing.
# Notes:
#   1. individual functions handle the possible errors they can run into
#   2. while this function does not return anything, upon completion it
#      should have downloaded all desired scripts or failed doing so with a proper error message
main() {
  log_application_header
  handle_arguments "$@"
  log_global_variables

  printf "%s\n" "$dashes"

  local asset_url
  asset_url=$(get_asset_archive_url)
  printf "Asset URL: $SUCCESS_COLOR%s$RESET\n" "$asset_url"

  download_asset_archive "$asset_url"
  printf "Asset archive '$SUCCESS_COLOR%s$RESET' downloaded ${SUCCESS_COLOR}successfully$RESET\n" "$asset_url"

  local filename
  [[ $asset_url =~ /([^/]+)\.$asset_type$ ]]
  filename="${BASH_REMATCH[1]}"
  extract_asset_archive "$filename" "$asset_type"
  printf "%s script(s) ${SUCCESS_COLOR}successfully$RESET extracted from $HIGHLIGHT_COLOR%s$RESET\n" "${#scripts[@]}" "$filename.$asset_type"
}

# Check if the script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
