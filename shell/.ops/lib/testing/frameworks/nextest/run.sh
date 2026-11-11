#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/rust/tools.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/nextest/report.sh"

:<<'MODULE'
Making a nextest run for a suite: the arguments every run takes, and the cargo
invocation itself. Shared with every runner that drives its tests through
nextest, so they cannot disagree on how a run is made.
MODULE

:<<'PUB_FUN'
Prints the arguments every nextest run of the suite takes, one per line: the
whole workspace, the profile, the tool config that defines it, a selection
reaching no test as a warning rather than a failure (as it is under cargo
test), and the suite's manifest when it names one.

args:
  $1  The effective suite config
PUB_FUN
testing__frameworks__nextest__run_args() {
  printf '%s\n' \
    --workspace \
    --profile "$(__testing__frameworks__nextest__profile "$1")" \
    --tool-config-file "shellops:$__testing__frameworks__nextest__TOOL_CONFIG" \
    --no-tests=warn
  testing__frameworks__cargo__manifest_args "$1"
}

:<<'FUN'
Runs cargo-nextest over the whole workspace named by the suite config, with the
trailing arguments narrowing the run, after asserting the tool is provisioned.
The run reports on stderr as the job log and writes the JUnit report at the
suite's report path. Passes the exit code through.

args:
  $1  The effective suite config
  $@  Narrowing arguments
FUN
__testing__frameworks__nextest__run() {
  __testing__frameworks__nextest__run__cfg="$1"
  shift
  rust__assert_cargo_tool cargo-nextest || return 1

  mapfile -t __testing__frameworks__nextest__run__args < <(testing__frameworks__nextest__run_args "$__testing__frameworks__nextest__run__cfg")
  mapfile -t __testing__frameworks__nextest__run__cargo_args < <(testing__frameworks__cargo__lines "$(testing__frameworks__cargo__extra_args "$__testing__frameworks__nextest__run__cfg")")

  cargo nextest run \
    "${__testing__frameworks__nextest__run__args[@]}" \
    "${__testing__frameworks__nextest__run__cargo_args[@]}" \
    "$@"
}
