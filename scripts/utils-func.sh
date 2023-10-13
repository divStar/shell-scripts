#!/bin/bash
# utils-func.sh
#
# This script contains utility functions.
#
# Note: if used standalone, this script does nothing.
# Note: if this script is placed next to the script, that is importing it,
# you can use the following commands to determine the current directory:
#   script_dir=$(dirname "${BASH_SOURCE[0]}")
#   source "$script_dir/utils-func.sh"
#
# Usage:
#   - source it or include it in your script
#   - use the provided functions

# Determine current path and source the libraries
script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/logging-func.sh"

# Definitions
SCRIPT_NAME="utils-func.sh" # Script name
SCRIPT_VERSION="1.0.0"      # Script version

# Exists with a given error
# Parameters:
#   $1 -  error code to exit the script with
# Returns nothing.
exit_with_error() {
  local errorCode
  errorCode="$1"
  shift
  exit "$errorCode"
}

# Checks whether a given command exists.
# Parameters:
#   $1 -  command to test for
# Returns log information about whether the command exists or not and exits if the latter is the case.
command_exists() {
  local command_to_check
  command_to_check="$1"
  shift
  log_info "Checking if '"; log_highlight "$command_to_check"; log_info "' is installed... "
  if ! command -v "$command_to_check" >/dev/null 2>&1; then
    log_error "✖ FAILED"
    log_newline
    log_error "'$command_to_check' was not found. Aborting generation!"
    exit_with_error 2
  else
    log_success " ✔ DONE"
    log_newline
  fi
}
