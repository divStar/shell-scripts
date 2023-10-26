# shell-scripts

This repository contains a few shell scripts for `bash`. They have been tested
using [`bats`](https://bats-core.readthedocs.io/en/stable/).

To read more about each script, open each script in an editor.

## Testing methodology

All succes cases (happy paths) as well as all anticipated failure cases of all scripts have been covered.

Note: a script should be tested in order to easily be able to tell if something was changed. In particular the tests help determine whether the scripts are compatible or contain any breaking changes.

Note: if you mock core functions (such as `rm`), make sure to implement an `if`-condition, that covers `bats` itself calling the function. In case of `rm` `bats` uses this function to remove temporarily created files and if there is a mock, it will be used instead of the real command.


## TODOs
- [x] write a `.gitlab-ci.yml`, that executes the `bats`-tests in a GitLab CI pipeline
- [x] copy the `create-docs.sh` script from the `dial2-doxy-gen` repository
- [ ] have the script be pulled in the `dial2-doxy-gen` instead of including it there
