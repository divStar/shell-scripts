#!/bin/bash
export SCRIPT_NAME="logging-func.sh" # Script name
export SCRIPT_VERSION="v1.0.4-BETA"        # Script version

# logging-func.sh
#
# This script contains logging-related functions.
#
# Note: if used standalone, this script does nothing.
# Note: if this script is placed next to the script, that is importing it,
# you can use the following commands to determine the current directory:
#   script_dir=$(dirname "${BASH_SOURCE[0]}")
#   source "$script_dir/logging-func.sh"
#
# Usage:
#   - source it or include it in your script
#   - use the provided functions

# Determine if we have a Terminal capable of at least 8 colors
if [ -t 1 ] && [ "$(tput colors)" -ge 8 ]; then
  ERROR_COLOR="\033[31m"
  SUCCESS_COLOR="\033[32m"
  HIGHLIGHT_COLOR="\033[34m"
  RESET="\033[0m"
fi

# Functions

# Logs a given string to STDOUT.
# Parameters:
#   $1 -  string to log
log_info() {
  printf "%s" "$*"
}

# Logs a given string to STDOUT and STDERR using $ERROR_COLOR color if available.
# Parameters:
#   $1 -  string to log
log_error() {
  printf "$ERROR_COLOR%s$RESET" "$*" >&2
}

# Logs a given string to STDOUT using $SUCCESS_COLOR if available.
# Parameters:
#   $1 -  string to log
log_success() {
  printf "$SUCCESS_COLOR%s$RESET" "$*"
}

# Logs a given string to STDOUT using $HIGHLIGHT_COLOR if available.
# Parameters:
#   $1 -  string to log
log_highlight() {
  printf "$HIGHLIGHT_COLOR%s$RESET" "$*"
}

# Logs a newline (\n) to STDOUT.
# Parameters: none.
log_newline() {
  printf "\n"
}

# Logs the application header to STDOUT. See function itself for template.
# Parameters: none.
log_application_header() {
  local total_length
  local dashes
  total_length=$((${#SCRIPT_NAME} + ${#SCRIPT_VERSION} + 3))
  dashes=$(printf '%0.s-' $(seq 1 $total_length))
  printf "%s - $HIGHLIGHT_COLOR%s$RESET\n%s\n" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$dashes"
}
