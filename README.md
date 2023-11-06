# shell-scripts

This repository contains a few shell scripts for `bash`. They have been tested
using [`bats`](https://bats-core.readthedocs.io/en/stable/).

To read more about each script, open each script in an editor.

## Testing methodology

All success cases (happy paths) as well as all anticipated failure cases of all scripts have been covered.

A script should be tested in order to easily be able to tell if something was changed. In particular the tests help determine
whether the scripts are compatible or contain any breaking changes.

If you mock functions and export them, make sure to also unset them.

### Set up `bats`

`bats` or rather `bats-core` can be set up in various ways on almost every operating system.

To install `bats-core`, follow [this installation guide from the official website](https://bats-core.readthedocs.io/en/v1.3.0/installation.html).

#### MacOS Ventura and Sonoma

In contrast to the official documentation, `bats-support` and `bats-assert` are not part of the this (`shell-scripts`) repository.
Instead, they must be installed on the system or be present in the docker image, that runs tests.

On MacOS you can simply use `brew` to install these extensions like this:
```shell
brew install bats-core bats-support bats-assert
```
Make sure to add the following line into the `rc` file of your shell (e.g. `.zshrc`) in order for `bats` to be picked up:
```shell
export BATS_LIB_PATH=/opt/homebrew/lib/
```
Restart the shell or `source` that `rc` file.

In order to run your tests (and scripts) in a much more similar way to how they will run on servers,
you may want to also install `bash`, because the `bash`, that comes with the OS itself, is heavily outdated.
You may also want to install `gnu-sed`, because the default `sed` on MacOS is a FreeBSD version of the tool and therefore
has a slightly different syntax than the `sed` used on typical Linux systems.

#### `bats/bats` Docker image

The `bats` Docker image includes `bats-support` and `bats-assert`, but the image passes all arguments to `bats` directly,
which makes it harder to use this image in a `.gitlab-ci.yml`-based pipeline.

Check the `.gitlab-ci.yml` to see what arguments are required to make it work nonetheless.

If you want to run the image locally to see if the Linux `bats-core` environment will be able to successfully execute the tests,
you can use the following command from the root of this git repository:
```shell
docker run -it -v ./:/code bats/bats:latest tests
```
This command mounts the current directory to the `/code` in the container and executes the tests.
You can see the output immediately on STDOUT.

**Note:** this requires a working Docker environment (e.g. Docker Desktop for Mac or `colima`).

### Test template

```shell
...
setup() {
  bats_require_minimum_version 1.10.0 # adjust version as necessary
  bats_load_library bats-support # only necessary if you use bats-support and bats-assert
  bats_load_library bats-assert # only necessary if you use bats-support and bats-assert
  load '../scripts/<script to test>.sh'
}
...
@test "<function>: should (fail to) <verb> (successfully)" {
  # Given
  curl() { # any function you want to mock - nearly all commands can be mocked this way
    return 0
  }
  export -f curl # export the mocked command
  
  some_var="some value" # you can set global variables of the script you are testing for this test
  # note: the test is run in a subshell, which is why values are copied, but modifications aren't written back
  # do some other setup stuff if necessary
  
  # When
  run function "function-args" # you may drop 'run' and capture the result to evaluate the contents of the variable
  
  # Then
  assert_success # or assert_failure; note: this only works if you used 'run' in the statement above
  assert_output # or assert_line; note: this only works if you used 'run' in the statement above
  # assert_equals "$actual" "$expected" # use this to compare variables
    
  # Cleanup
  unset -f curl # this is crucial in order to ensure the mocked commands are unset after the test is done
}
...
```

The template above contains a `setup()` function, that ensures `bats` has all necessary imports etc. to run the script.
It also features a `@test` template. For more information, checkout the existing tests and the
[bats-core website](https://bats-core.readthedocs.io/en/v1.3.0/writing-tests.html).

#### Mocking functions

Should you decide to mock functions, try to keep them in the smallest scope possible. E.g. if you need to mock a function
for just one test, prefer to mock, export and unset the mocked function within that test.

If you need to mock one or several functions for multiple tests, consider mocking them in the `setup()` function while
unsetting them in a `teardown` function.

## Notes

### `download-scripts.sh`

The purpose of `download-scripts.sh` is to download other scripts from the GitLab release API of the `shell-scripts` git repository.

This script is **self-sustained** and **should be copied directly into the directory it will be used in**.
It is versioned the same way all other scripts are, but has to be copied into place and updated manually.