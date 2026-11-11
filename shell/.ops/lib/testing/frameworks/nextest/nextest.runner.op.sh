#!/usr/bin/env bash

# nextest runner plugin for Test Impact Analysis (TIA): cargo tests run under
# cargo-nextest, leaving a JUnit report behind. The helpers it calls live
# beside it by concern: report.sh, selection.sh and run.sh.

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/nextest/report.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/nextest/selection.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/nextest/run.sh"

:<<'DOC'
The nextest runner; inner @-roles re-home to nextest_<role> on load. Package
selection and crate discovery are cargo's, so a nextest suite selects and
discovers exactly as a cargo suite does and differs in how the run is narrowed
and what it leaves behind: the whole workspace is built and the run filtered to
the selected packages, so the features each crate is built with are the same
whether one package or all of them run, and a JUnit report lands at the suite's
report path.
DOC
@runner.nextest() {
  :<<'FUN'
Runs the packages owning the selected files (each a $PROJ-relative path) under
nextest, in the workspace named by the suite config. Only that workspace's own
members are selectable; with no member left to select, runs the whole suite.
Passes the exit code through.
FUN
  @run_selected() {
    __nextest_run_selected__cfg="$1"
    shift
    __nextest_run_selected__packages="$(testing__frameworks__cargo__selected_packages "$__nextest_run_selected__cfg" "$@")" || return 1

    mapfile -t __nextest_run_selected__args < <(testing__frameworks__nextest__selection_args "$__nextest_run_selected__packages")
    __testing__frameworks__nextest__run "$__nextest_run_selected__cfg" "${__nextest_run_selected__args[@]}"
  }

  :<<'FUN'
Runs the whole workspace named by the suite config under nextest, passing the
exit code through.
FUN
  @run_all() {
    __testing__frameworks__nextest__run "$1"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a nextest suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/nextest/suite.schema.json"
  }

  :<<'FUN'
The discovery strategies cargo opts into; a nextest suite is a cargo suite for
discovery purposes.
FUN
  @strategies() {
    cargo_strategies
  }

  :<<'FUN'
cargo's default suite config under this runner's id, run under the "tia"
profile.
FUN
  @suite_defaults() {
    @set __at_out "$(cargo_suite_defaults)" \
      '.runner' "nextest" \
      '.profile' "tia"
    println "$__at_out"
  }

  :<<'FUN'
The escape join reads a nextest classname as a package, whatever the suite
config says: it is the binary id, the package name with a ::binary suffix for
a test binary other than the library's own.
FUN
  @escape_key() {
    printf 'package\n'
  }

  :<<'FUN'
The packages a selection of files (each a $PROJ-relative path) narrows the run
to, exactly as run_selected picks them; [] when it would run the whole
workspace.

args:
  $1  The effective suite config
  $@  Test file paths, relative to $PROJ
FUN
  @selected_packages() {
    testing__frameworks__cargo__selected_packages "$@"
  }

  :<<'FUN'
The JUnit report a run of the suite leaves behind.

args:
  $1  The effective suite config
FUN
  @junit_path() {
    testing__frameworks__nextest__junit_path "$1"
  }

  :<<'FUN'
cargo's "native" discovery for every area at once.
FUN
  @discover_all() {
    cargo_discover_all "$@"
  }

  :<<'FUN'
cargo's "native" discovery for a single area.
FUN
  @discover() {
    cargo_discover "$@"
  }
}
