#!/usr/bin/bats
setup() {
  bats_require_minimum_version 1.10.0
  bats_load_library bats-support
  bats_load_library bats-assert
  load '../scripts/create-docs.sh'
}

@test "find_metadata_source: should find a library.json successfully" {
  echo "" >"$LIBRARY_JSON_SOURCE"
  find_metadata_source
  assert_equal "$metadata_source_filename" "$LIBRARY_JSON_SOURCE"
  assert_equal "$inputType" "json"
  assert_equal "${metadata_mappings["PRJ_NAME"]}" ".name"
  assert_equal "${metadata_mappings["PRJ_DESCRIPTION"]}" ".description"
  assert_equal "${metadata_mappings["PRJ_VERSION"]}" ".version"
  assert_equal "${metadata_mappings["PRJ_AUTHOR"]}" ".authors.name"
  assert_equal "${metadata_mappings["PRJ_LOGO"]}" ".logo"
  rm "$LIBRARY_JSON_SOURCE"
}

@test "find_metadata_source: should find a platformio.ini successfully" {
  echo "" >"$PLATFORMIO_INI_SOURCE"
  find_metadata_source
  assert_equal "$metadata_source_filename" "$PLATFORMIO_INI_SOURCE"
  assert_equal "$inputType" "props"
  assert_equal "${metadata_mappings["PRJ_NAME"]}" ".name"
  assert_equal "${metadata_mappings["PRJ_DESCRIPTION"]}" ".description"
  assert_equal "${metadata_mappings["PRJ_VERSION"]}" ".custom_version"
  assert_equal "${metadata_mappings["PRJ_AUTHOR"]}" ".custom_authors"
  assert_equal "${metadata_mappings["PRJ_LOGO"]}" ".custom_logo"
  rm "$PLATFORMIO_INI_SOURCE"
}

@test "find_metadata_source: should not find a metadata file" {
  run find_metadata_source
  assert_failure 1
}

@test "build_yq_filter: should build 'yq_filter' as successfully" {
  metadata_mappings["PRJ_NAME"]=".name"
  metadata_mappings["PRJ_DESCRIPTION"]=".description"
  metadata_mappings["PRJ_VERSION"]=".version"
  metadata_mappings["PRJ_AUTHOR"]=".authors.name"
  metadata_mappings["PRJ_LOGO"]=".logo"
  expected_yq_filter='{"PRJ_AUTHOR": .authors.name,"PRJ_LOGO": .logo,"PRJ_VERSION": .version,"PRJ_NAME": .name,"PRJ_DESCRIPTION": .description} |
      to_entries |
      .[] |
      select(.value | length > 0) |
      "export " + .key + "=\"" + .value + "\""'
  build_yq_filter
  assert_equal "$yq_filter" "$expected_yq_filter"
}

@test "build_yq_filter: should fail to build 'yq_filter' because no mappings are set" {
  run build_yq_filter
  assert_failure 3
}

@test "get_metadata: should retrieve metadata from 'library.json' successfully" {
  echo '{
    "name": "Example Application",
    "keywords": "test, demo",
    "description": "A simple test application",
    "version": "1.0.1",
    "authors": {
      "name": "Igor Voronin",
      "url": "https://github.com/divStar"
    },
    "repository": {
      "type": "git",
      "url": "https://github.com/divStar/ahmsville-dial2-abstract-sensors.git"
    },
    "logo": "./some-logo.png",
    "export": {
      "exclude": [
        ".idea",
        ".pio",
        "cmake-build-*",
        "platformio.ini"
      ]
    },
    "frameworks": "*",
    "platforms": "*",
    "build": {
      "libArchive": false
    }
  }' >"$LIBRARY_JSON_SOURCE"
  metadata_source_filename="$LIBRARY_JSON_SOURCE"
  inputType="json"
  yq_filter='{"PRJ_AUTHOR": .authors.name,"PRJ_LOGO": .logo,"PRJ_VERSION": .version,"PRJ_NAME": .name,"PRJ_DESCRIPTION": .description} |
    to_entries |
    .[] |
    select(.value | length > 0) |
    "export " + .key + "=\"" + .value + "\""'
  declare -a expected_metadata_values
  expected_metadata_values[0]="export PRJ_AUTHOR=\"Igor Voronin\""
  expected_metadata_values[1]="export PRJ_LOGO=\"./some-logo.png\""
  expected_metadata_values[2]="export PRJ_VERSION=\"1.0.1\""
  expected_metadata_values[3]="export PRJ_NAME=\"Example Application\""
  expected_metadata_values[4]="export PRJ_DESCRIPTION=\"A simple test application\""

  get_metadata

  assert_equal "${#metadata_values[@]}" "${#expected_metadata_values[@]}"
  assert_equal "${metadata_values[*]}" "${expected_metadata_values[*]}"

  rm "$LIBRARY_JSON_SOURCE"
}

@test "get_metadata: should retrieve metadata from 'platformio.ini' successfully" {
  echo '[platformio]
name = Example Application
description = A simple test application
default_envs = zeroUSB

[env]
custom_version = 1.0.1
custom_authors = Igor Voronin
custom_logo = ./some-logo.png
build_flags = -std=gnu++17
build_unflags = -std=gnu++11

[env:zeroUSB]
platform = atmelsam
board = zeroUSB' >"$PLATFORMIO_INI_SOURCE"
  metadata_source_filename="$PLATFORMIO_INI_SOURCE"
  inputType="props"
  yq_filter='{"PRJ_AUTHOR": .custom_authors,"PRJ_LOGO": .custom_logo,"PRJ_VERSION": .custom_version,"PRJ_NAME": .name,"PRJ_DESCRIPTION": .description} |
    to_entries |
    .[] |
    select(.value | length > 0) |
    "export " + .key + "=\"" + .value + "\""'
  declare -a expected_metadata_values
  expected_metadata_values[0]="export PRJ_AUTHOR=\"Igor Voronin\""
  expected_metadata_values[1]="export PRJ_LOGO=\"./some-logo.png\""
  expected_metadata_values[2]="export PRJ_VERSION=\"1.0.1\""
  expected_metadata_values[3]="export PRJ_NAME=\"Example Application\""
  expected_metadata_values[4]="export PRJ_DESCRIPTION=\"A simple test application\""

  get_metadata

  assert_equal "${#metadata_values[@]}" "${#expected_metadata_values[@]}"
  assert_equal "${metadata_values[*]}" "${expected_metadata_values[*]}"

  rm "$PLATFORMIO_INI_SOURCE"
}

@test "get_metadata: should fail to retrieve metadata, because there is no source" {
  metadata_source_filename="$LIBRARY_JSON_SOURCE"

  run get_metadata

  assert_failure 4
}

@test "get_metadata: should fail to retrieve metadata, because source is empty" {
  echo '{}' >"$LIBRARY_JSON_SOURCE"
  metadata_source_filename="$LIBRARY_JSON_SOURCE"
  inputType="json"
  yq_filter='{"PRJ_AUTHOR": .authors.name,"PRJ_LOGO": .logo,"PRJ_VERSION": .version,"PRJ_NAME": .name,"PRJ_DESCRIPTION": .description} |
    to_entries |
    .[] |
    select(.value | length > 0) |
    "export " + .key + "=\"" + .value + "\""'

  run get_metadata

  assert_failure 5

  rm "$LIBRARY_JSON_SOURCE"
}
