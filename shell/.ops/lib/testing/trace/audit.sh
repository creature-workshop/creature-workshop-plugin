#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Auditing the static selection against the trace map: every file a test was
seen to read is a file whose change must select that test, and a pair the
static selection does not answer for is a dependency no scanner saw.

  testing__trace__audit   the findings, grouped by file
  testing__trace__reach   the suites seen reaching outside their tree unmarked
MODULE

__testing__trace__AUDIT="$SHELLOPS_DIR/lib/testing/trace/audit.awk"
__testing__trace__REACH="$SHELLOPS_DIR/lib/testing/trace/reach.awk"

: <<'PUB_FUN'
The findings of a map against the attached areas: per file, the area it
falls under and the tests that read it and that a change to it would not
select. Empty when the static selection answers for every read.

  testing__trace__audit "$map" "$attached"
  ->  [{"file": ".envrc", "area": "repo.envrc", "tests": ["test/a.bats"]}]

args:
  $1  The trace map (from testing__trace__latest_map)
  $2  The attached areas (from testing__attach_tests)
PUB_FUN
testing__trace__audit() {
  @run_awk __testing__trace__audit__out "$__testing__trace__AUDIT" "$1" \
    --with "$2" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__trace__audit__out"
}

: <<'PUB_FUN'
The suites the map shows reaching outside their process tree while the
config leaves them in_tree: per suite, the tests that connected to an
address other than loopback or started a program that reaches another host
or a container. An out_of_tree suite is what it says and is not reported.

  testing__trace__reach "$map" "$suites"
  ->  [{"suite": "unit", "tests": [{"test": "test/a.bats", "connects": ["93.184.216.34"], "execs": ["curl"]}]}]

args:
  $1  The trace map (from testing__trace__latest_map)
  $2  The effective suites (from testing__effective_suites)
PUB_FUN
testing__trace__reach() {
  @run_awk __testing__trace__reach__out "$__testing__trace__REACH" "$1" \
    --with "$2" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__trace__reach__out"
}
