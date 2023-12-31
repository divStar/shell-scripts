#!/usr/bin/bats
setup() {
  bats_require_minimum_version 1.10.0
  bats_load_library bats-support
  bats_load_library bats-assert
  load '../scripts/create-doc-versions.sh'

  #shellcheck disable=2317
  yq() {
    return 0
  }

  versions=("develop" "master" "v1.0.0" "v1.0.2" "v2.0.1" "v1.0rc3" "feature-some-stuff")
  versions_json='[
    {
      "version": "develop",
      "url": "../develop/index.html",
      "hint": "beta"
    },
    {
      "version": "master",
      "url": "../master/index.html",
      "hint": "beta"
    },
    {
      "version": "v1.0.0",
      "url": "../v1.0.0/index.html",
      "hint": "deprecated"
    },
    {
      "version": "v1.0.2",
      "url": "../v1.0.2/index.html",
      "hint": "deprecated"
    },
    {
      "version": "v2.0.1",
      "url": "../v2.0.1/index.html",
      "hint": "latest"
    },
    {
      "version": "v1.0rc3",
      "url": "../v1.0rc3/index.html",
      "hint": "beta"
    },
    {
      "version": "feature-some-stuff",
      "url": "../feature-some-stuff/index.html",
      "hint": "beta"
    }
  ]
  '
}

@test "filter_semantic_versions: should find only tags successfully" {
  run filter_semantic_versions "${versions[@]}"

  expectedArray=("v1.0.0" "v1.0.2" "v2.0.1")
  local -a expected
  expected=$(printf "%s\n" "${expectedArray[@]}")

  assert_output "${expected[@]}"
}

@test "determine_hint: should find 'deprecated' hint" {
  run determine_hint "${versions[2]}" "${versions[4]}"

  local expected
  expected="deprecated"
  assert_output "$expected"
}

@test "determine_hint: should find 'latest' hint" {
  run determine_hint "${versions[4]}" "${versions[4]}"

  local expected
  expected="latest"
  assert_output "$expected"
}

@test "determine_hint: should find 'beta' hint" {
  run determine_hint "${versions[0]}" "${versions[3]}"

  local expected
  expected="beta"
  assert_output "$expected"
}

@test "construct_json: should construct proper versions_json" {
  # Given
  # Mock
  yq() {
    echo $(($(cat "$yq_counter_file") + 1)) >"$yq_counter_file"
    echo "$(cat) $version_name"
    return 0
  }

  local yq_counter_file
  yq_counter_file=$(mktemp)
  echo 0 >"$yq_counter_file"

  # When
  run construct_json "${versions[4]}" "${versions[@]}"

  # Then
  assert_equal "$(cat "$yq_counter_file")" "${#versions[@]}"
  assert_output "[] ${versions[*]}"

  # Cleanup
  rm "$yq_counter_file"
  unset -f yq
}

@test "handle_arguments: should handle --public-directory=... properly" {
  handle_arguments --public-directory=test
  assert_equal "$public_directory" "test"
}

@test "handle_arguments: should handle --no-json-echo properly" {
  handle_arguments --no-json-echo
  assert_equal "$json_echo" "false"
}

@test "main: should create proper 'doc-versions.json'" {
  # Export versions so that they can be used inside the mock function
  export VERSIONS="${versions[*]}"
  # Mock `get_versions_from_directory` function to provide controlled output
  # shellcheck disable=2317
  get_versions_from_directory() {
    local versions_with_newlines

    # Replace spaces with newlines
    versions_with_newlines="${VERSIONS// /$'\n'}"

    # Read the modified string into an array
    mapfile -t array <<<"$versions_with_newlines"
    for version in "${array[@]}"; do
      printf "%s\n" "$version"
    done
  }

  # Given
  local main_output
  local resultHeader
  local header_length
  local header_dashes
  local expectedHeader
  local resultJson
  local expectedJson

  main_output=$(DOC_VERSIONS_JSON=/dev/null main)

  # Compare the header of the command with the expected one
  resultHeader=$(echo "$main_output" | head -n 3)
  header_length=$((${#SCRIPT_NAME} + ${#SCRIPT_VERSION} + 3))
  header_dashes=$(printf '%0.s-' $(seq 1 $header_length))
  expectedHeader=$(printf "%s - $RETRIEVED_VALUE_COLOR%s$RESET\n%s\n%s" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$header_dashes" "Checking if 'yq' is installed...  ✔ DONE")
  assert_equal "$resultHeader" "$expectedHeader"

  # Compare the JSON output with the expected one
  resultJson=$(echo "$main_output" | tail -n +4 | yq eval -o=json -)
  expectedJson=$(echo "$versions_json" | yq eval -o=json -)
  assert_equal "$resultJson" "$expectedJson"

  # Cleanup
  unset -f get_versions_from_directory
}
