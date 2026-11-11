#!/usr/bin/env bash

# llvm-cov runner plugin for Test Impact Analysis (TIA): cargo tests run under
# cargo-llvm-cov, yielding region coverage. The helpers it calls live beside it
# by concern: report.sh, harness.sh and run.sh.

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/nextest/report.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/llvm_cov/report.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/llvm_cov/harness.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/llvm_cov/run.sh"

:<<'DOC'
The llvm-cov runner; inner @-roles re-home to llvm_cov_<role> on load. Package
selection and crate discovery are cargo's, so an llvm-cov suite selects and
discovers exactly as a cargo suite does and differs only in how the run is
instrumented and what it leaves behind. The suite's harness says which test
runner cargo-llvm-cov drives: cargo test, or nextest, which also leaves the
JUnit report the escape join reads from the same run.
DOC
@runner.llvm_cov() {
  :<<'FUN'
Runs the packages owning the selected files (each a $PROJ-relative path) under
cargo-llvm-cov, in the workspace named by the suite config. With no member left
to select, measures the whole workspace. Passes the exit code through.
FUN
  @run_selected() {
    __llvm_cov_run_selected__cfg="$1"
    shift
    __llvm_cov_run_selected__packages="$(testing__frameworks__cargo__selected_packages "$__llvm_cov_run_selected__cfg" "$@")" || return 1

    mapfile -t __llvm_cov_run_selected__args < <(__testing__frameworks__llvm_cov__selection_args \
      "$__llvm_cov_run_selected__cfg" \
      "$__llvm_cov_run_selected__packages"
    )
    __testing__frameworks__llvm_cov__run "$__llvm_cov_run_selected__cfg" "${__llvm_cov_run_selected__args[@]}"
  }

  :<<'FUN'
Measures the whole workspace named by the suite config under cargo-llvm-cov,
passing the exit code through.
FUN
  @run_all() {
    mapfile -t __llvm_cov_run_all__args < <(__testing__frameworks__llvm_cov__whole_workspace_args "$1")
    __testing__frameworks__llvm_cov__run "$1" "${__llvm_cov_run_all__args[@]}"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for an llvm-cov suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/llvm_cov/suite.schema.json"
  }

  :<<'FUN'
The discovery strategies cargo opts into; an llvm-cov suite is a cargo suite for
discovery purposes.
FUN
  @strategies() {
    cargo_strategies
  }

  :<<'FUN'
cargo's default suite config under this runner's id, with the tests driven by
cargo test, the export written to target/coverage/llvm-cov and the
instrumented run made with --no-default-features --locked.
FUN
  @suite_defaults() {
    @arr __at1 --no-default-features --locked
    @set __at_out "$(cargo_suite_defaults)" \
      '.runner' "llvm_cov" \
      '.harness' "cargo" \
      '.report_dir' "target/coverage/llvm-cov" \
      '.cargo_args' "$__at1"
    println "$__at_out"
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

  :<<'FUN'
How the escape join reads the JUnit the suite's run wrote: under nextest a
classname is a package, as it is for the nextest runner; under cargo test no
JUnit is written, and the join's default reading stands.

args:
  $1  The effective suite config
FUN
  @escape_key() {
    if [ "$(__testing__frameworks__llvm_cov__under_nextest "$1")" = true ]; then
      printf 'package\n'
    else
      printf 'file-path\n'
    fi
  }

  :<<'FUN'
The packages a selection of files (each a $PROJ-relative path) narrows the run
to under nextest, exactly as run_selected picks them; [] when it would measure
the whole workspace, and [] under cargo test, whose run leaves nothing for a
package key to join.

args:
  $1  The effective suite config
  $@  Test file paths, relative to $PROJ
FUN
  @selected_packages() {
    if [ "$(__testing__frameworks__llvm_cov__under_nextest "$1")" != true ]; then
      @arr __at_out
      println "$__at_out"
      return 0
    fi
    testing__frameworks__cargo__selected_packages "$@"
  }

  :<<'FUN'
The JUnit report a run of the suite leaves behind: nextest's, at the path the
nextest runner names, under nextest; nothing under cargo test, whose run writes
none.

args:
  $1  The effective suite config
FUN
  @junit_path() {
    if [ "$(__testing__frameworks__llvm_cov__under_nextest "$1")" = true ]; then
      testing__frameworks__nextest__junit_path "$1"
    fi
  }

  :<<'FUN'
Prints the last run's coverage report, normalized to the shape lib/coverage/api.sh
works on (metric "regions"), with every file attributed to the suite the config
names (defaulting to this runner's id). Fails when no export exists yet.

args:
  $1  The effective suite config
FUN
  @coverage_summary() {
    __llvm_cov_coverage_summary__report="$(__testing__frameworks__llvm_cov__report_path "$1")"
    if [ ! -f "$__llvm_cov_coverage_summary__report" ]; then
      error "llvm_cov: no export at $__llvm_cov_coverage_summary__report; run the suite first"
      return 1
    fi

    @get __at2 "$1" '.suite' 'llvm_cov'
    @run_awk __at_out "$SHELLOPS_DIR/lib/testing/frameworks/llvm_cov/report.awk" \
      "$(cat "$__llvm_cov_coverage_summary__report")" \
      --arg root "$PROJ" \
      --arg suite "$__at2" \
      --load "$SHELLOPS_DIR/lib/coverage/coverage.awk" || return 1
    println "$__at_out"
  }
}
