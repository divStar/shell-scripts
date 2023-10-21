#!/usr/bin/bats
# Mock doxygen command
doxygen() {
  if [[ $1 == "success_config/doxyfile" ]] || [[ $1 == "./Doxyfile" ]]; then
    # Simulate success
    return 0
  else
    # Simulate failure
    return 1
  fi
}

cp() {
  if [[ $1 == "non-existing-file/*" ]]; then
    # Simulate failure
    return 1
  else
    # Simulate success
    return 0
  fi
}

# Mock log functions to output received text
log_info() { printf "%s" "$1"; }
log_hightlight() { printf "%s" "$1"; }
log_success() { printf "%s" "$1"; }
log_error() { printf "%s" "$1"; }
log_newline() { printf "\n"; }

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

@test "preprocess_templates: should preprocess templates successfully" {
  # Given
  # Prepare `create-docs.sh` script variables
  metadata_values[0]="export SOME_VAR=\"Some variable\""
  metadata_values[1]="export SOME_OTHER_VAR=\"Some other variable\""
  metadata_values[2]="export SOME_ANOTHER_VAR=\"Some another variable\""

  DOXY_CONFIG="."
  DOXY_HEADER_TEMPLATE="preprocess_templates_header.template"
  DOXY_FOOTER_TEMPLATE="preprocess_templates_footer.template"
  DOXY_STYLESHEET_TEMPLATE="preprocess_templates_stylesheet.template"
  DOXY_HEADER="preprocess_templates_header.output"
  DOXY_FOOTER="preprocess_templates_footer.output"
  DOXY_STYLESHEET="preprocess_templates_stylesheet.output"

  # Write templates
  # Note: the variables are not evaluated below (hence the $ sign in the variable is escaped).
  # This is what `preprocess_templates` is for.
  local template_pattern
  template_pattern="var = \$SOME_VAR\nLine 2: '\$SOME_OTHER_VAR'\nLine 3: \"\$SOME_ANOTHER_VAR\""
  printf "Header-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE
  printf "Footer-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE
  printf "Stylesheet-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE

  # Prepare expected output
  local expected_header_contents
  local expected_footer_contents
  local expected_stylesheet_contents
  local expected_template_values
  expected_template_values="var = Some variable\nLine 2: 'Some other variable'\nLine 3: \"Some another variable\""
  expected_header_contents="Header-Template: $expected_template_values"
  expected_footer_contents="Footer-Template: $expected_template_values"
  expected_stylesheet_contents="Stylesheet-Template: $expected_template_values"

  # When
  run preprocess_templates

  # Then
  local actual_header_contents
  local actual_footer_contents
  local actual_stylesheet_contents
  local awk_command
  # shellcheck disable=SC2016
  awk_command='{ if(NR>1) printf "\\n"; printf "%s", $0 }'
  actual_header_contents=$(awk "$awk_command" "$DOXY_CONFIG/$DOXY_HEADER")
  actual_footer_contents=$(awk "$awk_command" "$DOXY_CONFIG/$DOXY_FOOTER")
  actual_stylesheet_contents=$(awk "$awk_command" "$DOXY_CONFIG/$DOXY_STYLESHEET")

  assert_success
  assert_output "Preprocess template HTML and CSS files... ✔ DONE"
  assert_equal "$actual_header_contents" "$expected_header_contents"
  assert_equal "$actual_footer_contents" "$expected_footer_contents"
  assert_equal "$actual_stylesheet_contents" "$expected_stylesheet_contents"

  # Cleanup
  rm "$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_HEADER"
  rm "$DOXY_CONFIG/$DOXY_FOOTER"
  rm "$DOXY_CONFIG/$DOXY_STYLESHEET"
}

@test "preprocess_templates: should process templates successfully even with empty metadata_values" {
  # Given
  # Prepare `create-docs.sh` script variables
  metadata_values=() # Empty array

  DOXY_CONFIG="."
  DOXY_HEADER_TEMPLATE="preprocess_templates_header.template"
  DOXY_FOOTER_TEMPLATE="preprocess_templates_footer.template"
  DOXY_STYLESHEET_TEMPLATE="preprocess_templates_stylesheet.template"
  DOXY_HEADER="preprocess_templates_header.output"
  DOXY_FOOTER="preprocess_templates_footer.output"
  DOXY_STYLESHEET="preprocess_templates_stylesheet.output"

  # Write templates without variables to substitute
  local template_pattern
  template_pattern="var = \$SOME_VAR\nLine 2: '\$SOME_OTHER_VAR'\nLine 3: \"\$SOME_ANOTHER_VAR\""
  printf "Header-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE
  printf "Footer-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE
  printf "Stylesheet-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE

  # Prepare expected output - should be identical to input templates as there are no variables to substitute
  local expected_header_contents="Header-Template: $template_pattern"
  local expected_footer_contents="Footer-Template: $template_pattern"
  local expected_stylesheet_contents="Stylesheet-Template: $template_pattern"

  # When
  run preprocess_templates

  # Then
  local actual_header_contents
  local actual_footer_contents
  local actual_stylesheet_contents
  local awk_command
  # shellcheck disable=SC2016
  awk_command='{ if(NR>1) printf "\\n"; printf "%s", $0 }'
  actual_header_contents=$(awk "$awk_command" "$DOXY_CONFIG/$DOXY_HEADER")
  actual_footer_contents=$(awk "$awk_command" "$DOXY_CONFIG/$DOXY_FOOTER")
  actual_stylesheet_contents=$(awk "$awk_command" "$DOXY_CONFIG/$DOXY_STYLESHEET")

  assert_success
  assert_output "Preprocess template HTML and CSS files... ✔ DONE"
  assert_equal "$actual_header_contents" "$expected_header_contents"
  assert_equal "$actual_footer_contents" "$expected_footer_contents"
  assert_equal "$actual_stylesheet_contents" "$expected_stylesheet_contents"

  # Cleanup
  rm "$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_HEADER"
  rm "$DOXY_CONFIG/$DOXY_FOOTER"
  rm "$DOXY_CONFIG/$DOXY_STYLESHEET"
}

@test "preprocess_templates: should fail, because header-template is absent" {
  # Given
  # Prepare `create-docs.sh` script variables
  metadata_values=()

  DOXY_CONFIG="."
  DOXY_HEADER_TEMPLATE="preprocess_templates_header.template"
  DOXY_FOOTER_TEMPLATE="preprocess_templates_footer.template"
  DOXY_STYLESHEET_TEMPLATE="preprocess_templates_stylesheet.template"
  DOXY_HEADER="preprocess_templates_header.output"
  DOXY_FOOTER="preprocess_templates_footer.output"
  DOXY_STYLESHEET="preprocess_templates_stylesheet.output"

  # When
  run preprocess_templates

  # Then
  assert_failure 6
  assert_output --partial "Template file '$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE' does not exist!"
}

@test "preprocess_templates: should fail, because footer-template is absent" {
  # Given
  # Prepare `create-docs.sh` script variables
  metadata_values=()

  DOXY_CONFIG="."
  DOXY_HEADER_TEMPLATE="preprocess_templates_header.template"
  DOXY_FOOTER_TEMPLATE="preprocess_templates_footer.template"
  DOXY_STYLESHEET_TEMPLATE="preprocess_templates_stylesheet.template"
  DOXY_HEADER="preprocess_templates_header.output"
  DOXY_FOOTER="preprocess_templates_footer.output"
  DOXY_STYLESHEET="preprocess_templates_stylesheet.output"

  # Write templates without variables to substitute
  local template_pattern
  template_pattern="var = \$SOME_VAR\nLine 2: '\$SOME_OTHER_VAR'\nLine 3: \"\$SOME_ANOTHER_VAR\""
  printf "Header-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE

  # When
  run preprocess_templates

  # Then
  assert_failure 6
  assert_output --partial "Template file '$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE' does not exist!"

  # Cleanup
  rm "$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE"
}

@test "preprocess_templates: should fail, because stylesheet-template is absent" {
  # Given
  # Prepare `create-docs.sh` script variables
  metadata_values=()

  DOXY_CONFIG="."
  DOXY_HEADER_TEMPLATE="preprocess_templates_header.template"
  DOXY_FOOTER_TEMPLATE="preprocess_templates_footer.template"
  DOXY_STYLESHEET_TEMPLATE="preprocess_templates_stylesheet.template"
  DOXY_HEADER="preprocess_templates_header.output"
  DOXY_FOOTER="preprocess_templates_footer.output"
  DOXY_STYLESHEET="preprocess_templates_stylesheet.output"

  # Write templates without variables to substitute
  local template_pattern
  template_pattern="var = \$SOME_VAR\nLine 2: '\$SOME_OTHER_VAR'\nLine 3: \"\$SOME_ANOTHER_VAR\""
  printf "Header-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE
  printf "Footer-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE

  # When
  run preprocess_templates

  # Then
  assert_failure 6
  assert_output --partial "Template file '$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE' does not exist!"

  # Cleanup
  rm "$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE"
}

@test "generate_docs: should succeed when doxygen succeeds" {
  # Set up
  DOXY_CONFIG="success_config"
  DOXY_FILE="doxyfile"

  # Run
  run generate_docs

  # Assert
  assert_success
  assert_output "Generating docs using 'doxygen $DOXY_CONFIG/$DOXY_FILE'... ✔ DONE"
}

@test "generate_docs: should fail when doxygen fails" {
  # Set up
  DOXY_CONFIG="fail_config"
  DOXY_FILE="doxyfile"

  # Run
  run generate_docs

  # Assert
  assert_failure 7
  assert_line "Generating docs using 'doxygen $DOXY_CONFIG/$DOXY_FILE'... ✖ FAILED"
  assert_line "doxygen failed to generate docs!"
}

@test "copy_misc_files: should copy misc files successfully" {
  # Run
  run copy_misc_files

  # Assert
  assert_success
  assert_output "Copying '$MISC_SOURCE/*' to '$GEN_TARGET/html'... ✔ DONE"
}

@test "copy_misc_files: should fail to copy non-existing folder" {
  # Set up
  MISC_SOURCE="non-existing-file"

  # Run
  run copy_misc_files

  # Assert
  assert_failure 8
  assert_line "Copying '$MISC_SOURCE/*' to '$GEN_TARGET/html'... ✖ FAILED"
  assert_line "Failed to copy misc files!"
}

@test "delete_generated_template_files: should delete generated files successfully" {
  # Set up
  rm() {
    return 0
  }

  # Run
  run delete_generated_template_files

  # Assert
  assert_success
  assert_output "Deleting templated files... ✔ DONE"
}

@test "delete_generated_template_files: should fail to delete the DOXY_HEADER" {
  # Set up
  rm() {
    # $1 is '-rf' while $2 is the file/folder to delete
    if [[ $2 == "$DOXY_CONFIG/$DOXY_HEADER" ]]; then
      # Simulate failure
      return 1
    else
      # Simulate success (on other calls)
      return 0
    fi
  }

  # Run
  run delete_generated_template_files

  # Assert
  assert_failure 9
  assert_line "Deleting templated files... ✖ FAILED"
  assert_line "Could not delete generated file '$DOXY_CONFIG/$DOXY_HEADER'!"
}

@test "delete_generated_template_files: should fail to delete DOXY_FOOTER" {
  # Set up
  rm() {
    # $1 is '-rf' while $2 is the file/folder to delete
    if [[ $2 == "$DOXY_CONFIG/$DOXY_FOOTER" ]]; then
      # Simulate failure
      return 1
    else
      # Simulate success (on other calls)
      return 0
    fi
  }

  # Run
  run delete_generated_template_files

  # Assert
  assert_failure 9
  assert_line "Deleting templated files... ✖ FAILED"
  assert_line "Could not delete generated file '$DOXY_CONFIG/$DOXY_FOOTER'!"
}

@test "delete_generated_template_files: should fail to delete DOXY_STYLESHEET" {
  # Set up
  rm() {
    # $1 is '-rf' while $2 is the file/folder to delete
    if [[ $2 == "$DOXY_CONFIG/$DOXY_STYLESHEET" ]]; then
      # Simulate failure
      return 1
    else
      # Simulate success (on other calls)
      return 0
    fi
  }

  # Run
  run delete_generated_template_files

  # Assert
  assert_failure 9
  assert_line "Deleting templated files... ✖ FAILED"
  assert_line "Could not delete generated file '$DOXY_CONFIG/$DOXY_STYLESHEET'!"
}

@test "rename_html_directory: should rename the generated docs folder successfully" {
  # Set up
  test() {
    return 0
  }
  rm() {
    return 0
  }
  mv() {
    return 0
  }

  # Run
  run rename_html_directory

  # Assert
  assert_success
  assert_output "Renaming '$GEN_TARGET/html/' to '$GEN_TARGET/v$PRJ_VERSION/'... ✔ DONE"
}

@test "rename_html_directory: should fail, because existing vx.x.x folder is not a directory" {
  # Set up
  test() {
    return 1
  }

  # Run
  run rename_html_directory

  # Assert
  assert_failure 10
  assert_line "Renaming '$GEN_TARGET/html/' to '$GEN_TARGET/v$PRJ_VERSION/'... ✖ FAILED"
  assert_line "Could not delete '$GEN_TARGET/v$PRJ_VERSION'!"
}

@test "rename_html_directory: should fail to remove an existing project folder" {
  # Set up
  test() {
    return 0
  }
  rm() {
    return 1
  }



  # Run
  run rename_html_directory

  # Assert
  assert_failure 10
  assert_line "Renaming '$GEN_TARGET/html/' to '$GEN_TARGET/v$PRJ_VERSION/'... ✖ FAILED"
  assert_line "Could not delete '$GEN_TARGET/v$PRJ_VERSION'!"
}

@test "rename_html_directory: should fail to move the new folder into its place" {
  # Set up
  test() {
    return 0
  }
  rm() {
    return 0
  }
  mv() {
    return 1
  }

  # Run
  run rename_html_directory

  # Assert
  assert_failure 11
  assert_line "Renaming '$GEN_TARGET/html/' to '$GEN_TARGET/v$PRJ_VERSION/'... ✖ FAILED"
  assert_line "Could not move '$GEN_TARGET/html' to '$GEN_TARGET/v$PRJ_VERSION'!"
}

@test "main: should successfully generate docs" {
  # Given
  # Mocks
  test() {
    return 0
  }
  mv() {
    return 0
  }
  # Files
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

  DOXY_CONFIG="."
  DOXY_HEADER_TEMPLATE="preprocess_templates_header.template"
  DOXY_FOOTER_TEMPLATE="preprocess_templates_footer.template"
  DOXY_STYLESHEET_TEMPLATE="preprocess_templates_stylesheet.template"
  DOXY_HEADER="preprocess_templates_header.output"
  DOXY_FOOTER="preprocess_templates_footer.output"
  DOXY_STYLESHEET="preprocess_templates_stylesheet.output"

  # Write templates without variables to substitute
  local template_pattern
  template_pattern="var = \$SOME_VAR\nLine 2: '\$SOME_OTHER_VAR'\nLine 3: \"\$SOME_ANOTHER_VAR\""
  printf "Header-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE
  printf "Footer-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE
  printf "Stylesheet-Template: %s" "$template_pattern" >$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE

  # When
  run main

  # Then
  assert_success
  assert_line --partial "'library.json'"
  assert_line --partial "Finding"
  assert_line --partial "Retrieving values"
  assert_line --partial "Preprocess template"
  assert_line --partial "Generating"
  assert_line --partial "Copying"
  assert_line --partial "Deleting"
  assert_line --partial "Renaming"

  # Cleanup
  rm "$LIBRARY_JSON_SOURCE"
  rm "$DOXY_CONFIG/$DOXY_HEADER_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_FOOTER_TEMPLATE"
  rm "$DOXY_CONFIG/$DOXY_STYLESHEET_TEMPLATE"
}
