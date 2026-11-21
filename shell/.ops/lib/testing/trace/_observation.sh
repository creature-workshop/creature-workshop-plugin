#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh"

: <<'FRAGMENT'
Reading a trace back as the observation a test leaves: the tracked files it
read and probed for, the programs it started, the internet addresses it
reached for. Private to lib/testing/trace.
FRAGMENT

__testing__trace__DIR="$SHELLOPS_DIR/lib/testing/trace"

: <<'FUN'
Prints the facts a trace holds, one per line as "<kind>TAB<value>", sorted.
A file outside the repository or off the tracked list is left out; given a
test file, only the facts of that file's runner count (see runner.awk).

  __testing__trace__facts trace.txt /repo /repo tracked.txt
  ->  exec	jq
      probe	lib/missing.sh
      read	lib/string/api.sh

args:
  $1  The trace file (from __testing__trace__record)
  $2  The repository's absolute path
  $3  The absolute directory the traced command started in
  $4  A file listing the tracked files, one repository-relative path per line
  $5  The test file whose runner's facts count, or empty for every process's
FUN
__testing__trace__facts() {
  awk \
    -v root="$2" \
    -v cwd="$3" \
    -v runner="${5:-}" \
    -f "$__testing__trace__DIR/lines.awk" \
    -f "$__testing__trace__DIR/paths.awk" \
    -f "$__testing__trace__DIR/runner.awk" \
    -f "$__testing__trace__DIR/reads.awk" \
    "$4" \
    "$1" \
    "$1" \
    | LC_ALL=C sort
}

: <<'FUN'
Prints the observation a trace leaves as one struct, {reads, probes, execs,
connects}, each a sorted array, over the files git tracks in $PROJ, where
every runner starts a suite.

  __testing__trace__observation trace.txt test/string.api.bats
  ->  {"reads":["lib/string/api.sh"],"probes":[],"execs":["bats"],"connects":[]}

args:
  $1  The trace file (from __testing__trace__record)
  $2  The test file whose runner's facts count, or empty for every process's
FUN
__testing__trace__observation() {
  __testing__trace__observation__root="$(cd "$PROJ" && pwd -P)" || return 1
  __testing__trace__observation__tracked="$(mktemp)" || return 1
  git__tracked_files "$PROJ" > "$__testing__trace__observation__tracked" || {
    rm -f "$__testing__trace__observation__tracked"
    return 1
  }

  __testing__trace__observation__facts="$(__testing__trace__facts \
    "$1" \
    "$__testing__trace__observation__root" \
    "$__testing__trace__observation__root" \
    "$__testing__trace__observation__tracked" \
    "${2:-}"
  )"
  __testing__trace__observation__status=$?
  rm -f "$__testing__trace__observation__tracked"
  [ "$__testing__trace__observation__status" -eq 0 ] || return 1

  @split __testing__trace__observation__split_1 "$__testing__trace__observation__facts"
  @run_awk __testing__trace__observation__out "$__testing__trace__DIR/observation.awk" \
    "$__testing__trace__observation__split_1" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__trace__observation__out"
}
