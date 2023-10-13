#!/usr/bin/bats
setup() {
  bats_require_minimum_version 1.10.0
  bats_load_library bats-support
  bats_load_library bats-assert
  load '../scripts/utils-func.sh'
}

@test "exit_with_error: should exit upon provided errorCode" {
  run exit_with_error 1
  assert_failure 1
  assert_output ""
}

@test "exit_with_error: should exit with 'numeric argument required' error if no code is provided" {
  run exit_with_error
  assert_failure 2
  assert_output --partial "numeric argument required"
}

@test "command_exists: command should exist" {
  run command_exists "ls"
  assert_success
  assert_output "Checking if 'ls' is installed...  ✔ DONE"
}

@test "command_exists: command should not exist, 'non-existing-command' provided" {
  run command_exists "non-existing-command"
  assert_failure 2
  assert_output --partial "Checking if 'non-existing-command' is installed... ✖ FAILED"
  assert_output --partial "'non-existing-command' was not found. Aborting generation!"
}

@test "command_exists: command should not exist, no command provided" {
  run command_exists
  assert_failure 2
  assert_output --partial "Checking if '' is installed... ✖ FAILED"
  assert_output --partial "'' was not found. Aborting generation!"
}
