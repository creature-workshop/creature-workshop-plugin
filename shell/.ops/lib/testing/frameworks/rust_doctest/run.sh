#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/rust_doctest/report.sh"

:<<'FRAGMENT'
Making a doctest run for a suite: the cargo arguments it takes and the
invocation itself, always the whole workspace.
FRAGMENT

:<<'FUN'
Prints the cargo arguments a doctest run of the suite takes, one per line: the
doctest target, the whole workspace, the suite's manifest when it names one,
and its cargo_args.

args:
  $1  The effective suite config
FUN
__testing__frameworks__rust_doctest__cargo_args() {
  printf '%s\n' test --doc --workspace
  testing__frameworks__cargo__manifest_args "$1"
  testing__frameworks__cargo__lines "$(testing__frameworks__cargo__extra_args "$1")"
}

:<<'FUN'
Runs every doctest in the workspace named by the suite config. The run's
output streams to stdout as the job log and is kept as run.log in the report
directory; the JUnit report is translated from it once the run ends. Passes
the cargo exit code through. A top-level helper shared by the run roles, which
both run everything: a doctest cannot be selected on stable Rust.

args:
  $1  The effective suite config
FUN
__testing__frameworks__rust_doctest__run() {
  __testing__frameworks__rust_doctest__run__dir="$(__testing__frameworks__rust_doctest__report_dir "$1")"
  mkdir -p "$__testing__frameworks__rust_doctest__run__dir"
  mapfile -t __testing__frameworks__rust_doctest__run__args < <(__testing__frameworks__rust_doctest__cargo_args "$1")

  cargo "${__testing__frameworks__rust_doctest__run__args[@]}" 2>&1 | tee "$__testing__frameworks__rust_doctest__run__dir/run.log"
  __testing__frameworks__rust_doctest__run__status="${PIPESTATUS[0]}"

  awk -f "$__testing__frameworks__rust_doctest__DIR/results.awk" "$__testing__frameworks__rust_doctest__run__dir/run.log" \
    | __testing__frameworks__rust_doctest__junit \
    > "$(__testing__frameworks__rust_doctest__junit_path "$1")"
  return "$__testing__frameworks__rust_doctest__run__status"
}
