#!/usr/bin/bats
setup() {
  bats_require_minimum_version 1.10.0
  bats_load_library bats-support
  bats_load_library bats-assert
  load '../scripts/download-scripts.sh'
}

@test "shell_scripts_url: should return the full URL successfully" {
  base_url="base-url"
  shell_scripts_project_id=9
  expected_url="$base_url/api/v4/projects/$shell_scripts_project_id/releases"

  run shell_scripts_url

  assert_success
  assert_output "$expected_url"
}

@test "filter_asset_type_value: should return 'yq' filter value successfully" {
  asset_type="zip"
  expected_value=".assets.sources[] | select(.format == \"zip\").url"

  run filter_asset_type_value

  assert_success
  assert_output "$expected_value"
}

@test "log_application_header: should log an application header" {
  run log_application_header

  assert_success
  assert_line --index 0 --partial "download-scripts.sh"
  assert_line --index 1 --partial "-------------"
}

@test "log_application_header: should log a somewhat broken application header" {
  SCRIPT_NAME=""
  SCRIPT_VERSION=""

  run log_application_header

  assert_success
  assert_line --index 0 " - "
  assert_line --index 1 "---"
}

@test "log_global_variables: should log global variables with default values successfully" {
  run log_global_variables

  assert_success
  assert_line --index 0 "shell_scripts_project_id: 14"
  assert_line --index 1 "shell_scripts_version: latest"
  assert_line --index 2 "base_url: https://gitlab.my.family"
  assert_line --index 3 "private_token: *******"
  assert_line --index 4 "asset_type: zip"
  assert_line --index 5 "scripts: "
}

@test "log_global_variables: should log global variables with modified values successfully" {
  shell_scripts_project_id=9
  shell_scripts_version="v1.0.11"
  base_url="https://gitlab.com"
  private_token="some-custom-value"
  asset_type="tar.gz"
  declare -a scripts
  scripts+=("some-script1.sh")
  scripts+=("some-folder1/some-script2.sh")

  run log_global_variables

  assert_success
  assert_line --index 0 "shell_scripts_project_id: 9"
  assert_line --index 1 "shell_scripts_version: v1.0.11"
  assert_line --index 2 "base_url: https://gitlab.com"
  assert_line --index 3 "private_token: *******"
  assert_line --index 4 "asset_type: tar.gz"
  assert_line --index 5 "scripts: some-script1.sh, some-folder1/some-script2.sh"
}

@test "handle_arguments: should handle -ssid / --shell-scripts-project-id properly" {
  declare -a scripts
  scripts+=("dummy.sh")

  handle_arguments -ssid 5
  assert_equal "$shell_scripts_project_id" 5

  handle_arguments --shell-scripts-project-id 9
  assert_equal "$shell_scripts_project_id" 9
}

@test "handle_arguments: should handle -v / --shell-scripts-version properly" {
  declare -a scripts
  scripts+=("dummy.sh")

  handle_arguments -v "v1.0.11"
  assert_equal "$shell_scripts_version" "v1.0.11"

  handle_arguments --shell-scripts-version "v1.0.10"
  assert_equal "$shell_scripts_version" "v1.0.10"
}

@test "handle_arguments: should handle -u / --base-url properly" {
  declare -a scripts
  scripts+=("dummy.sh")

  handle_arguments -u "custom-base-url1"
  assert_equal "$base_url" "custom-base-url1"

  handle_arguments --base-url "custom-base-url2"
  assert_equal "$base_url" "custom-base-url2"
}

@test "handle_arguments: should handle -p / --base-url properly" {
  declare -a scripts
  scripts+=("dummy.sh")

  handle_arguments -p "custom-token-value1"
  assert_equal "$private_token" "custom-token-value1"

  handle_arguments --private-token "custom-token-value2"
  assert_equal "$private_token" "custom-token-value2"
}

@test "handle_arguments: should handle -t / --asset-type properly" {
  declare -a scripts
  scripts+=("dummy.sh")

  handle_arguments -t "tar"
  assert_equal "$asset_type" "tar"

  handle_arguments --asset-type "tar.bz2"
  assert_equal "$asset_type" "tar.bz2"
}

@test "handle_arguments: should handle -h / --help properly" {
  show_help() {
    cat <<EOF
(show_help mock)
EOF
  }
  declare -a scripts
  scripts+=("dummy.sh")

  local mock_show_help_output

  mock_show_help_output=$(handle_arguments -h)
  assert_equal "$mock_show_help_output" "(show_help mock)"

  mock_show_help_output=$(handle_arguments --help)
  assert_equal "$mock_show_help_output" "(show_help mock)"
}

@test "handle_arguments: should exit on unknown parameter -*" {
  declare -a scripts
  scripts+=("dummy.sh")

  run handle_arguments -xy "weird-value"

  assert_failure 1
}

@test "handle_arguments: should handle requested scripts properly" {
  handle_arguments "script1.sh" "folder1/script2.sh"

  assert_equal "${#scripts[@]}" "2"
}

@test "handle_arguments: should exit if no scripts are requested" {
  run handle_arguments "$@"

  assert_failure 2
}

# shellcheck disable=2317
@test "get_asset_archive_url: should retrieve asset archive URL successfully" {
  # Given
  local expected_url
  expected_url="https://example.com/filtered/url/fix"
  curl() {
    echo "200"
    return 0
  }
  yq() {
    echo "$expected_url"
    return 0
  }
  export -f curl yq

  # When
  run get_asset_archive_url

  # Then
  assert_success
  assert_output "$expected_url"

  # Cleanup
  unset -f curl yq
}

# shellcheck disable=2317
@test "get_asset_archive_url: should fail to retrieve asset archive URL" {
  # Given
  curl() {
    echo "404"
    return 1
  }
  export -f curl

  # When
  run get_asset_archive_url

  # Then
  assert_failure 3
  assert_output "Could not get release information: received HTTP status code 404"

  # Cleanup
  unset -f curl
}

# shellcheck disable=2317
@test "download_asset_archive: should download the asset archive successfully" {
  # Given
  curl() {
    echo "200"
    return 0
  }
  export -f curl

  # When
  run download_asset_archive "some-download.address/asset_archive.zip"

  # Then
  assert_success
  assert_output ""

  # Cleanup
  unset -f curl
}

# shellcheck disable=2317
@test "download_asset_archive: should fail to download the asset archive" {
  # Given
  local dummy_asset_url
  dummy_asset_url="some-invalid-download.address/asset_archive.zip"
  curl() {
    echo "403"
    return 1
  }
  export -f curl

  # When
  run download_asset_archive "$dummy_asset_url"

  # Then
  assert_failure 4
  assert_output "Could not download '$dummy_asset_url': received HTTP status code 403"

  # Cleanup
  unset -f curl
}

@test "extract_asset_archive: should extract scripts from zip asset archive successfully" {
  asset_type="zip"

  declare -a scripts
  scripts+=("some-script1.sh")
  scripts+=("some-folder1/some-script2.sh")

  local temp_file
  temp_file="$(mktemp)"

  # shellcheck disable=2317
  unzip() {
    echo "$*" > "$temp_file"
    return 0
  }
  export -f unzip

  run extract_asset_archive "some-file" "$asset_type"
  local unzip_cli_args
  unzip_cli_args=$(< "$temp_file")

  assert_success
  assert_equal "$unzip_cli_args" "-j -o -q some-file.zip some-file/some-script1.sh some-file/some-folder1/some-script2.sh"

  rm "$temp_file"
  unset -f unzip
}

@test "extract_asset_archive: should extract scripts from tar asset archive successfully" {
  asset_type="tar"

  declare -a scripts
  scripts+=("some-script1.sh")
  scripts+=("some-folder1/some-script2.sh")

  local temp_file
  temp_file="$(mktemp)"

  # shellcheck disable=2317
  tar() {
    echo "$*" > "$temp_file"
    return 0
  }
  export -f tar

  run extract_asset_archive "some-file" "$asset_type"
  local tar_cli_args
  tar_cli_args=$(< "$temp_file")

  assert_success
  assert_equal "$tar_cli_args" "--strip-components=2 -xf some-file.tar some-file/some-script1.sh some-file/some-folder1/some-script2.sh"

  rm "$temp_file"
  unset -f tar
}

@test "extract_asset_archive: should extract scripts from tar.gz asset archive successfully" {
  asset_type="tar.gz"

  declare -a scripts
  scripts+=("some-script1.sh")
  scripts+=("some-folder1/some-script2.sh")

  local temp_file
  temp_file="$(mktemp)"

  # shellcheck disable=2317
  tar() {
    echo "$*" > "$temp_file"
    return 0
  }
  export -f tar

  run extract_asset_archive "some-file" "$asset_type"
  local tar_cli_args
  tar_cli_args=$(< "$temp_file")

  assert_success
  assert_equal "$tar_cli_args" "--strip-components=2 -zxf some-file.tar.gz some-file/some-script1.sh some-file/some-folder1/some-script2.sh"

  rm "$temp_file"
  unset -f tar
}

@test "extract_asset_archive: should extract scripts from tar.bz2 asset archive successfully" {
  asset_type="tar.bz2"

  declare -a scripts
  scripts+=("some-script1.sh")
  scripts+=("some-folder1/some-script2.sh")

  local temp_file
  temp_file="$(mktemp)"

  # shellcheck disable=2317
  tar() {
    echo "$*" > "$temp_file"
    return 0
  }
  export -f tar

  run extract_asset_archive "some-file" "$asset_type"
  local tar_cli_args
  tar_cli_args=$(< "$temp_file")

  assert_success
  assert_equal "$tar_cli_args" "--strip-components=2 -jxf some-file.tar.bz2 some-file/some-script1.sh some-file/some-folder1/some-script2.sh"

  rm "$temp_file"
  unset -f tar
}

@test "extract_asset_archive: should fail to extract scripts from asset archive with unknown asset archive type" {
  asset_type="unknown"

  declare -a scripts
  scripts+=("some-script1.sh")
  scripts+=("some-folder1/some-script2.sh")

  run extract_asset_archive "some-file" "$asset_type"

  assert_failure 5
  assert_output "Error: unknown asset archive type ('unknown')."
}

@test "extract_asset_archive: should fail to extract scripts from zip asset archive" {
  asset_type="zip"

  declare -a scripts
  scripts+=("some-script1.sh")
  scripts+=("some-folder1/some-script2.sh")

  # shellcheck disable=2317
  unzip() {
    return 1
  }
  export -f unzip

  run extract_asset_archive "some-file" "$asset_type"

  assert_failure 6
  assert_output "Error: scripts could not be extracted (see actual error above)."

  unset -f unzip
}

@test "main: should successfully extract scripts" {
    # Given
  local expected_url
  expected_url="https://example.com/some/path/file.zip"
  curl() {
    echo "200"
    return 0
  }
  yq() {
    echo "$expected_url"
    return 0
  }
  unzip() {
    return 0
  }
  export -f curl yq unzip

  run main some-script1.sh some-folder1/some-script2.sh

  assert_success
  assert_line --index 0 --partial "download-scripts.sh"
  assert_line --index 1 --partial "--------"
  assert_line --index 9 "Asset URL: $expected_url"
  assert_line --index 10 "Asset archive '$expected_url' downloaded successfully"
  assert_line --index 11 "2 script(s) successfully extracted from file.zip"

  unset -f curl yq unzip
}