#!/bin/bash
export SCRIPT_NAME="create-docs-versions.sh" # Script name
export SCRIPT_VERSION="v1.0.1-BETA"                # Script version

# create-docs-versions.sh
#
# This script creates the `docs-versions.json` for a given folder (e.g. `./public`).
# It iterates over the sub-folders, takes their names as versions and outputs the desired JSON,
# which is used by the `versions-loader.js` script of the doxygen documentation.
#
# Usage:
#   - ensure `./public` output folder exists and is writable
#   - ensure the tools `yq` is installed and available
#   - run this script; if the working directory is not `./`, add the folder as a parameter
#     Example: ./create-docs-versions.sh
#     Example: ./public/create-docs-versions.sh ./public
#
# Exit codes:
#   0 - Script exited successfully (without an error).
#   2 - Script exited, because a tool is not installed or available (see [Prerequisites](#prerequisites)).

# Determine current path and source the libraries
script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/logging-func.sh"
source "$script_dir/utils-func.sh"

# Definitions
SEMVER_REGEX="^v[0-9]+\.[0-9]+\.[0-9]+$" # Regular expression to determine version tags
DOC_VERSIONS_JSON="doc-versions.json"    # File to output

# Configurable global variables
public_directory=./ # script-relative path to the public directory
json_echo=true      # whether to echo the JSON to STDOUT or not

# Handles script input arguments.
# Parameters: none.
# Returns: none unless provided options are unknown (in this case it exits with code 1).
handle_arguments() {
  while (("$#")); do
    case $1 in
    --no-json-echo)
      json_echo=false
      shift # Remove processed argument
      ;;
    --public-directory=* | --pd=*)
      public_directory="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    esac
  done
}

# Iterates over the folders in a given directory and returns their names as versions.
# Parameters:
#   $1 -  directory to scan
# Returns a newline-separated list of found versions.
get_versions_from_directory() {
  local dir="$1"
  local found_versions=()
  local subdir
  for subdir in "$dir"/*; do
    if [[ -d $subdir ]]; then
      version_name=$(basename "$subdir")
      found_versions+=("$version_name")
    fi
  done
  log_info "${found_versions[@]}"
  log_newline
}

# Filters out the semantic versions (according to $SEMVER_REGEX) from all given versions and returns them.
# Parameters: none.
# Returns a newline-separated list of semantic versions (according to $SEMVER_REGEX).
filter_semantic_versions() {
  local sem_versions=()
  local version
  for version in "$@"; do
    [[ $version =~ $SEMVER_REGEX ]] && sem_versions+=("$version")
  done
  for version in "${sem_versions[@]}"; do
    log_info "$version"
    log_newline
  done
}

# Determines the hint to set for any given version in relation to the highest available version.
# This only makes sense if the versions are comparable (e.g. both are semantic versions).
# Parameters:
#   $1 -  version to check
#   $2 -  version to check against
# Returns `latest`, `deprecated` or `beta` depending on the outcome.
determine_hint() {
  local version="$1"
  local highest_version="$2"
  if [[ $version == "$highest_version" ]]; then
    echo "latest"
  elif [[ $version =~ $SEMVER_REGEX ]]; then
    echo "deprecated"
  else
    echo "beta"
  fi
}

# Constructs the full JSON containing all available versions, their index.html path and the hint.
# Parameters:
#   $1 -  highest available version
#   ...-  all available versions
# Returns a JSON string with all the versions, their index.html paths and hints.
construct_json() {
  local highest_version=$1
  shift
  local all_versions=("$@")
  local json_output="[]"
  local hint
  for version_name in "${all_versions[@]}"; do
    hint=$(determine_hint "$version_name" "$highest_version")
    export version_name
    export hint
    json_output=$(echo "$json_output" | yq eval '. += {"version": env(version_name),"url": "../" + env(version_name) + "/index.html","hint": env(hint)}' -o=json -)
  done
  echo "$json_output"
}

# Main function of the script. It produces JSON output for the $DOC_VERSIONS_JSON.
# Parameters: see `handle_arguments` for allowed script arguments.
# Returns: a $DOC_VERSIONS_JSON file (and/or STDOUT) with all available doc versions.
main() {
  handle_arguments "$@"
  log_application_header
  command_exists "yq"

  local -a versions
  local semantic_versions
  local sorted
  local final_json_output

  mapfile -t versions < <(get_versions_from_directory "$public_directory")
  mapfile -t semantic_versions < <(filter_semantic_versions "${versions[@]}")
  mapfile -t sorted < <(printf "%s\n" "${semantic_versions[@]}" | sort -V)

  highest_version="${sorted[-1]}"

  json_output=$(construct_json "$highest_version" "${versions[@]}")
  final_json_output=$(echo "$json_output" | yq eval '.' - -P -o=json)
  echo "$final_json_output" >$DOC_VERSIONS_JSON
  if $json_echo; then
    echo "$final_json_output" | yq eval '.' - -P -o=json
  fi
}

# Check if the script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
