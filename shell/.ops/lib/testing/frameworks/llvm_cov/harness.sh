#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/rust/tools.sh"

:<<'FRAGMENT'
The harness that drives the tests under coverage, cargo test or nextest, and
what each one asks of the run: the tools it needs and the cargo-llvm-cov
subcommand it goes through.
FRAGMENT

:<<'FUN'
The harness that drives the tests under coverage, from the suite config's
`harness`: "cargo" (cargo test, the default) or "nextest". A top-level helper
shared by the run roles and the escape join roles.

args:
  $1  The effective suite config
FUN
__testing__frameworks__llvm_cov__harness() {
  @get __testing__frameworks__llvm_cov__harness__out "$1" '.harness' 'cargo'
  println "$__testing__frameworks__llvm_cov__harness__out"
}

:<<'FUN'
Prints true when the suite drives its tests through nextest, false when
through cargo test.

args:
  $1  The effective suite config
FUN
__testing__frameworks__llvm_cov__under_nextest() {
  @succeeds __testing__frameworks__llvm_cov__under_nextest__out [ "$(__testing__frameworks__llvm_cov__harness "$1")" = nextest ]
  println "$__testing__frameworks__llvm_cov__under_nextest__out"
}

:<<'FUN'
Asserts the tools a run of the suite needs: cargo-llvm-cov and the llvm-tools
component always, cargo-nextest when it is the harness.

args:
  $1  The effective suite config
FUN
__testing__frameworks__llvm_cov__assert_tools() {
  rust__assert_cargo_tool cargo-llvm-cov || return 1
  rust__assert_rustup_component llvm-tools || return 1
  if [ "$(__testing__frameworks__llvm_cov__under_nextest "$1")" = true ]; then
    rust__assert_cargo_tool cargo-nextest || return 1
  fi
}

:<<'FUN'
Prints the cargo-llvm-cov subcommand the harness calls for, one line: "nextest"
under nextest, nothing under cargo test, whose run is llvm-cov's own.

args:
  $1  The effective suite config
FUN
__testing__frameworks__llvm_cov__subcommand() {
  if [ "$(__testing__frameworks__llvm_cov__under_nextest "$1")" = true ]; then
    printf 'nextest\n'
  fi
}
