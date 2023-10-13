#!/usr/bin/bats
setup() {
  bats_require_minimum_version 1.10.0
  bats_load_library bats-support
  bats_load_library bats-assert
  load '../scripts/logging-func.sh'
}

@test "log_info: should log 'test'" {
  run log_info "test"
  assert_success
  assert_output "test"
}

@test "log_info: should log nothing" {
  run log_info
  assert_success
  assert_output ""
}

@test "log_error: should log 'test' to STDERR" {
  run log_error "test"
  # Note: it's not tested, that `log_error` outputs to STDERR
  assert_success
  assert_output "test"
}

@test "log_error: should log nothing" {
  run log_error
  assert_success
  assert_output ""
}

@test "log_success: should log 'test'" {
  run log_success "test"
  assert_success
  assert_output "test"
}

@test "log_success: should log nothing" {
  run log_success
  assert_success
  assert_output ""
}

@test "log_highlight: should log 'test'" {
  run log_highlight "test"
  assert_success
  assert_output "test"
}

@test "log_highlight: should log nothing" {
  run log_highlight
  assert_success
  assert_output ""
}

@test "log_newline: should log a newline character" {
  run log_newline
  assert_success
  assert_output "$(printf "\n")"
}

@test "log_application_header: should log an application header" {
  run log_application_header
  assert_success
  assert_line --index 0 --partial "logging-func.sh - "
  assert_line --index 1 --partial "---------------"
}

@test "log_application_header: should log a somewhat broken application header" {
  SCRIPT_NAME="" SCRIPT_VERSION="" run log_application_header
  assert_success
  assert_line --index 0 " - "
  assert_line --index 1 "---"
}