#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/nextest/run.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/nextest/selection.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/llvm_cov/report.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/llvm_cov/harness.sh"

:<<'FRAGMENT'
Making a cargo-llvm-cov run for a suite: the selection in the harness's own
spelling, and the cargo invocation itself.
FRAGMENT

:<<'FUN'
Runs cargo-llvm-cov over the selection given as trailing arguments, after
asserting the tooling is provisioned. Under cargo test the selection is -p
pairs or --workspace; under nextest it is the nextest run arguments and a
filterset. The test run reports on stderr as the job log; the JSON export
lands at the suite's report path for coverage_summary to read. The ignore
patterns are joined with | into one --ignore-filename-regex. Passes the exit
code through. A top-level helper shared by the run roles.

args:
  $1  The effective suite config
  $@  Selection arguments
FUN
__testing__frameworks__llvm_cov__run() {
  __testing__frameworks__llvm_cov__run__cfg="$1"
  shift
  __testing__frameworks__llvm_cov__assert_tools "$__testing__frameworks__llvm_cov__run__cfg" || return 1

  __testing__frameworks__llvm_cov__run__report="$(__testing__frameworks__llvm_cov__report_path "$__testing__frameworks__llvm_cov__run__cfg")"
  mkdir -p "$(dirname "$__testing__frameworks__llvm_cov__run__report")"

  mapfile -t __testing__frameworks__llvm_cov__run__subcommand < <(__testing__frameworks__llvm_cov__subcommand "$__testing__frameworks__llvm_cov__run__cfg")
  mapfile -t __testing__frameworks__llvm_cov__run__cargo_args < <(testing__frameworks__cargo__lines "$(testing__frameworks__cargo__extra_args "$__testing__frameworks__llvm_cov__run__cfg")")
  @join __testing__frameworks__llvm_cov__run__ignore "$(testing__frameworks__cargo__ignore_patterns "$__testing__frameworks__llvm_cov__run__cfg")" '|'

  __testing__frameworks__llvm_cov__run__args=(
    llvm-cov
    "${__testing__frameworks__llvm_cov__run__subcommand[@]}"
    "${__testing__frameworks__llvm_cov__run__cargo_args[@]}"
    --json
    --output-path "$__testing__frameworks__llvm_cov__run__report"
  )
  if @defined "$__testing__frameworks__llvm_cov__run__ignore"; then
    __testing__frameworks__llvm_cov__run__args+=(--ignore-filename-regex "$__testing__frameworks__llvm_cov__run__ignore")
  fi

  cargo "${__testing__frameworks__llvm_cov__run__args[@]}" "$@"
}

:<<'FUN'
Prints the selection arguments for the packages a narrowed run measures, one
per line, in the harness's own spelling. Under cargo test: the manifest, then
-p per package, or --workspace when no package is left. Under nextest: the
run arguments (whole workspace, profile, manifest) and the filterset narrowing
the run, or no filterset when no package is left.

args:
  $1  The effective suite config
  $2  Package names (struct array)
FUN
__testing__frameworks__llvm_cov__selection_args() {
  if [ "$(__testing__frameworks__llvm_cov__under_nextest "$1")" = true ]; then
    testing__frameworks__nextest__run_args "$1"
    testing__frameworks__nextest__selection_args "$2"
    return 0
  fi

  testing__frameworks__cargo__manifest_args "$1"
  if @empty "$2"; then
    println --workspace
    return 0
  fi
  testing__frameworks__cargo__package_args "$2"
}

:<<'FUN'
Prints the arguments measuring the whole workspace, one per line, in the
harness's own spelling.

args:
  $1  The effective suite config
FUN
__testing__frameworks__llvm_cov__whole_workspace_args() {
  if [ "$(__testing__frameworks__llvm_cov__under_nextest "$1")" = true ]; then
    testing__frameworks__nextest__run_args "$1"
    return 0
  fi

  println --workspace
  testing__frameworks__cargo__manifest_args "$1"
}
