#!/bin/bash
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

# Definitions
SCRIPT_NAME="logging-func.sh" # Script name
SCRIPT_VERSION="1.0.0"        # Script version

# Determine if we have a Terminal capable of at least 8 colors
if [ -t 1 ] && [ "$(tput colors)" -ge 8 ]; then
  ERROR_COLOR="\033[31m"
  SUCCESS_COLOR="\033[32m"
  RETRIEVED_VALUE_COLOR="\033[34m"
  RESET="\033[0m"
fi

# Functions
log_info() {
  printf "%s" "$*"
}

log_error() {
  printf "$ERROR_COLOR%s$RESET" "$*" >&2
}

log_success() {
  printf "$SUCCESS_COLOR%s$RESET" "$*"
}

log_highlight() {
  printf "$RETRIEVED_VALUE_COLOR%s$RESET" "$*"
}

log_newline() {
  printf "\n"
}

log_application_header() {
  local total_length
  local dashes
  total_length=$((${#SCRIPT_NAME} + ${#SCRIPT_VERSION} + 3))
  dashes=$(printf '%0.s-' $(seq 1 $total_length))
  printf "%s - $RETRIEVED_VALUE_COLOR%s$RESET\n%s\n" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$dashes"
}
