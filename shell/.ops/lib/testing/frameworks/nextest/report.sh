#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh"

:<<'MODULE'
What a nextest run of a suite leaves behind: the profile it runs under, the
tool config that defines that profile with the JUnit report enabled, and where
the report lands. Shared by the run and by every reader of the report.
MODULE

: <<'CONST'
The tool config every run loads beneath the repository's own nextest config:
it defines the profile a suite runs under, with the JUnit report enabled.
CONST
__testing__frameworks__nextest__TOOL_CONFIG="$SHELLOPS_DIR/lib/testing/frameworks/nextest/nextest.toml"

:<<'FUN'
The nextest profile the suite config names (`profile`), defaulting to "tia", the
profile the runner's tool config defines. A top-level helper shared by the run
roles and the report path.

args:
  $1  The effective suite config
FUN
__testing__frameworks__nextest__profile() {
  @get __testing__frameworks__nextest__profile__out "$1" '.profile' 'tia'
  println "$__testing__frameworks__nextest__profile__out"
}

:<<'PUB_FUN'
The absolute path of the JUnit report a run of the suite leaves behind:
junit.xml under nextest's store directory for the profile, which sits in the
workspace's target directory (CARGO_TARGET_DIR when set). This is the path the
escape join reads, so the writer's config and the reader agree on it here.

  testing__frameworks__nextest__junit_path '{"manifest": "engine/Cargo.toml"}'
  -> $PROJ/engine/target/nextest/tia/junit.xml

args:
  $1  The effective suite config
PUB_FUN
testing__frameworks__nextest__junit_path() {
  __testing__frameworks__nextest__junit_path__target="${CARGO_TARGET_DIR:-$(testing__frameworks__cargo__workspace_root "$1")/target}"
  printf '%s/nextest/%s/junit.xml' \
    "$__testing__frameworks__nextest__junit_path__target" \
    "$(__testing__frameworks__nextest__profile "$1")"
}
