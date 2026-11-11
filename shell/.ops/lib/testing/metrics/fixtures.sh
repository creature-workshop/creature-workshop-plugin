#!/bin/sh

import "$SHELLOPS_DIR/lib/testing/metrics/api.sh"

:<<'FRAGMENT'
Test fixtures for the metrics module: records built the way the module builds
them, for suites that need records on disk without caring how they got there.

Fixtures sit beside the API rather than inside it, so importing the module for
production use does not also import them. Each takes the directory it builds
into as an argument and touches nothing else.
FRAGMENT

:<<'PUB_FUN'
Writes one record through the module's own emit path, from a controlled
decision with one suite row whose duration is the one given: the row is built
the way the module builds it, then its measured duration is replaced, since
the module reads the clock twice and a second boundary between the reads
would make the value drift. Every field a caller asserts on is an argument,
so no case depends on wall-clock timing.

  $1 dir  $2 mode  $3 reason  $4 selected  $5 total  $6 duration  $7 status
PUB_FUN
testing__metrics__fixture_record() {
  __testing__metrics__fixture_record__testing_metrics_fixture__record__run="$(testing__metrics__begin)"
  @set __testing__metrics__fixture_record__testing_metrics_fixture__record__row \
    "$(testing__metrics__suite_row unit bats "$4" "$5" "$(time__epoch_seconds)" "$7" "")" \
    '.duration_seconds' \
    "$6"
  @arr __testing__metrics__fixture_record__arr_1 lib
  @false __testing__metrics__fixture_record__false_2
  @obj __testing__metrics__fixture_record__testing_metrics_fixture__record__decision \
    '.mode' "$2" \
    '.reason' "$3" \
    '.areas' "$__testing__metrics__fixture_record__arr_1" \
    '.dispatch' "$__testing__metrics__fixture_record__false_2" \
    '.status' "$7"
  # A subshell keeps the directory override out of the caller's environment.
  (
    TESTING_METRICS_DIR="$1"
    export TESTING_METRICS_DIR
    @arr __testing__metrics__fixture_record__arr_3 "$__testing__metrics__fixture_record__testing_metrics_fixture__record__row"
    testing__metrics__emit \
      "$__testing__metrics__fixture_record__testing_metrics_fixture__record__run" \
      "$__testing__metrics__fixture_record__testing_metrics_fixture__record__decision" \
      "$__testing__metrics__fixture_record__arr_3" \
      > /dev/null
  )
}

:<<'PUB_FUN'
Places a hand-written record in <dir> directly, for callers exercising reading
and aggregation rather than writing: the run duration is what the rollup
measures against, and only a hand-written record can state one.

  $1 dir  $2 name  $3 mode  $4 reason  $5 selected  $6 total  $7 run seconds
  $8 status (default passed)
PUB_FUN
testing__metrics__fixture_staged_record() {
  mkdir -p "$1"
  @wrap __testing__metrics__fixture_staged_record__wrap_4 "$2"
  @wrap __testing__metrics__fixture_staged_record__wrap_5 2026-08-16T12:00:00Z
  @false __testing__metrics__fixture_staged_record__false_6
  @obj __testing__metrics__fixture_staged_record__obj_7 \
      '.id' "$__testing__metrics__fixture_staged_record__wrap_4" \
      '.started_at' "$__testing__metrics__fixture_staged_record__wrap_5" \
      '.duration_seconds' "$7" \
      '.status' "${8:-passed}" \
      '.dispatch' "$__testing__metrics__fixture_staged_record__false_6"
  @arr __testing__metrics__fixture_staged_record__arr_8 lib
  @obj __testing__metrics__fixture_staged_record__obj_9 \
      '.mode' "$3" \
      '.reason' "$4" \
      '.areas' "$__testing__metrics__fixture_staged_record__arr_8" \
      '.selected' "$5" \
      '.total' "$6"
  @arr __testing__metrics__fixture_staged_record__arr_10
  @obj __testing__metrics__fixture_staged_record__record \
    '.run' "$__testing__metrics__fixture_staged_record__obj_7" \
    '.selection' "$__testing__metrics__fixture_staged_record__obj_9" \
    '.suites' "$__testing__metrics__fixture_staged_record__arr_10"
  @dump __testing__metrics__fixture_staged_record__out "$__testing__metrics__fixture_staged_record__record"
  println "$__testing__metrics__fixture_staged_record__out" > "$1/20260816T120000Z-$2.json"
}

:<<'PUB_FUN'
Puts the escape check's verdict on a staged record, through the module's own
verdict path.

  $1 dir  $2 name  $3 escapes (struct array), empty for a clean run
PUB_FUN
testing__metrics__fixture_verdict() {
  testing__metrics__record_verdict "$1/20260816T120000Z-$2.json" "$3" > /dev/null 2>&1
}
