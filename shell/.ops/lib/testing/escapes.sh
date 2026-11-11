#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'MODULE'
Would-be escapes: the failing tests a selection would have skipped, whether it
narrowed the run to some tests or found nothing to run at all.

A full-suite failure whose test the record's selection did not include is a
mapping bug -- selection would have gone green while the suite went red. The
comparison is per pipeline and per suite: the record says what each suite's
run was allowed to select and how its runner spells a JUnit classname (its
escape_key), the suite's junit reports say what actually failed, and both come
from the same review's run. A run that ran everything left nothing out and
has no escapes to find.
MODULE

__testing__escapes__DIR="$SHELLOPS_DIR/lib/testing"

:<<'PUB_FUN'
The classnames a directory of junit reports marks failed, as a struct array,
deduplicated across reports. A classname reads as the runner wrote it: a test
file for bats, a package with an optional ::binary suffix for nextest. An
absent directory or one holding no reports yields the empty array.

Usage: testing__escapes_failed_tests ".ops/test-reports/unit"
PUB_FUN
testing__escapes_failed_tests() {
  if [ ! -d "$1" ]; then
    @arr __testing__escapes_failed_tests__out
    println "$__testing__escapes_failed_tests__out"
    return 0
  fi

  __testing__escapes_failed_tests__testing_escapes__failed_tests__lines="$(
    cat "$1"/*.xml 2>/dev/null \
    | awk -f "$__testing__escapes__DIR/junit_failures.awk" \
    || true
  )"
  @split __testing__escapes_failed_tests__out "$__testing__escapes_failed_tests__testing_escapes__failed_tests__lines"
  println "$__testing__escapes_failed_tests__out"
}

:<<'PUB_FUN'
The tests a directory of junit reports marks flaky -- failed, then passed on a
retry -- as a struct array of classname::name, deduplicated across reports.
A flaky test passed, so it is never an escape; it is counted so flake shows in
the scorecard rather than as noise in the escape list. An absent directory or
one holding no reports yields the empty array.

Usage: testing__escapes_flaky_tests "engine/target/nextest/tia"
PUB_FUN
testing__escapes_flaky_tests() {
  if [ ! -d "$1" ]; then
    @arr __testing__escapes_flaky_tests__out
    println "$__testing__escapes_flaky_tests__out"
    return 0
  fi

  __testing__escapes_flaky_tests__testing_escapes__flaky_tests__lines="$(
    cat "$1"/*.xml 2>/dev/null \
    | awk -f "$__testing__escapes__DIR/junit_flaky.awk" \
    || true
  )"
  @split __testing__escapes_flaky_tests__out "$__testing__escapes_flaky_tests__testing_escapes__flaky_tests__lines"
  println "$__testing__escapes_flaky_tests__out"
}

:<<'PUB_FUN'
The join keys a directory of junit reports marks failed, read under one
escape-key strategy: the classnames themselves under file-path, their package
half under package.

  testing__escapes_failed_keys reports/engine package  ->  ["cli","errors"]

  $1 reports directory   $2 escape key (file-path or package)
PUB_FUN
testing__escapes_failed_keys() {
  @run_awk __testing__escapes_failed_keys__out \
    "$__testing__escapes__DIR/escape_keys.awk" \
    "$(testing__escapes_failed_tests "$1")" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" \
    --arg key "$2" || return 1
  println "$__testing__escapes_failed_keys__out"
}

:<<'PUB_FUN'
The failed join keys of every suite the record ran, read out of that suite's
own report directory (<reports>/<suite>) under the escape_key its row names,
as an object keyed by suite. A suite without a report directory has no
failures.

  testing__escapes_failed_by_suite .ops/test-reports "$record"
  -> {"unit": ["test/a.bats"], "engine": ["errors"]}

  $1 reports directory   $2 record
PUB_FUN
testing__escapes_failed_by_suite() {
  @arr __testing__escapes_failed_by_suite__arr_1
  @get __testing__escapes_failed_by_suite__testing_escapes__by_suite__rows "$2" '.suites' "$__testing__escapes_failed_by_suite__arr_1"
  @len __testing__escapes_failed_by_suite__testing_escapes__by_suite__count "$__testing__escapes_failed_by_suite__testing_escapes__by_suite__rows"
  __testing__escapes_failed_by_suite__testing_escapes__by_suite__i=0
  @obj __testing__escapes_failed_by_suite__testing_escapes__by_suite__acc

  while [ "$__testing__escapes_failed_by_suite__testing_escapes__by_suite__i" -lt "$__testing__escapes_failed_by_suite__testing_escapes__by_suite__count" ]; do
    @get __testing__escapes_failed_by_suite__testing_escapes__by_suite__row "$__testing__escapes_failed_by_suite__testing_escapes__by_suite__rows" ".[$__testing__escapes_failed_by_suite__testing_escapes__by_suite__i]"
    __testing__escapes_failed_by_suite__testing_escapes__by_suite__i=$((__testing__escapes_failed_by_suite__testing_escapes__by_suite__i + 1))
    __testing__escapes_failed_by_suite__testing_escapes__by_suite__acc="$(__testing__escapes__absorb_suite \
      "$__testing__escapes_failed_by_suite__testing_escapes__by_suite__acc" \
      "$1" \
      "$__testing__escapes_failed_by_suite__testing_escapes__by_suite__row"
    )"
  done

  @compact __testing__escapes_failed_by_suite__out "$__testing__escapes_failed_by_suite__testing_escapes__by_suite__acc"
  println "$__testing__escapes_failed_by_suite__out"
}

:<<'FUN'
Sets one suite's failed keys in the accumulating object, read from its report
directory under the key its row names.

  $1 accumulator   $2 reports directory   $3 suite row
FUN
__testing__escapes__absorb_suite() {
  @let "$3" __testing__escapes__absorb_suite__ suite escape_key
  @defined "$__testing__escapes__absorb_suite__escape_key" \
    || __testing__escapes__absorb_suite__escape_key='file-path'

  __testing__escapes__absorb_suite__failed="$(testing__escapes_failed_keys \
    "$2/$__testing__escapes__absorb_suite__suite" \
    "$__testing__escapes__absorb_suite__escape_key"
  )"
  @set __testing__escapes__absorb_suite__out "$1" ".\"$__testing__escapes__absorb_suite__suite\"" "$__testing__escapes__absorb_suite__failed"
  println "$__testing__escapes__absorb_suite__out"
  __testing__escapes__absorb_suite__status=$?
  @unlet __testing__escapes__absorb_suite__ suite escape_key
  return "$__testing__escapes__absorb_suite__status"
}

:<<'PUB_FUN'
The suites of a record whose report directory (<reports>/<suite>) holds no
junit report, as a struct array in row order, for a run that narrowed or ran
nothing. A suite selection left out and no report speaks for has no verdict:
its failures are invisible to the join, which must not read that as "no
escapes". A record that ran everything needs no report, so the array is
empty.

  testing__escapes_missing_reports .ops/test-reports "$record"  ->  ["engine"]

  $1 reports directory   $2 record
PUB_FUN
testing__escapes_missing_reports() {
  if @get __testing__escapes_missing_reports__get_2 "$2" '.selection.mode' ''; [ "$__testing__escapes_missing_reports__get_2" = full_suite ]; then
    @arr __testing__escapes_missing_reports__out
    println "$__testing__escapes_missing_reports__out"
    return 0
  fi

  @arr __testing__escapes_missing_reports__arr_3
  @get __testing__escapes_missing_reports__testing_escapes__missing__rows "$2" '.suites' "$__testing__escapes_missing_reports__arr_3"
  @len __testing__escapes_missing_reports__testing_escapes__missing__count "$__testing__escapes_missing_reports__testing_escapes__missing__rows"
  __testing__escapes_missing_reports__testing_escapes__missing__i=0
  @arr __testing__escapes_missing_reports__testing_escapes__missing__acc

  while [ "$__testing__escapes_missing_reports__testing_escapes__missing__i" -lt "$__testing__escapes_missing_reports__testing_escapes__missing__count" ]; do
    @get __testing__escapes_missing_reports__testing_escapes__missing__suite "$__testing__escapes_missing_reports__testing_escapes__missing__rows" ".[$__testing__escapes_missing_reports__testing_escapes__missing__i].suite"
    __testing__escapes_missing_reports__testing_escapes__missing__i=$((__testing__escapes_missing_reports__testing_escapes__missing__i + 1))
    if [ "$(__testing__escapes__has_report "$1/$__testing__escapes_missing_reports__testing_escapes__missing__suite")" = false ]; then
      @wrap __testing__escapes_missing_reports__wrap_4 "$__testing__escapes_missing_reports__testing_escapes__missing__suite"
      @push __testing__escapes_missing_reports__testing_escapes__missing__acc "$__testing__escapes_missing_reports__testing_escapes__missing__acc" "$__testing__escapes_missing_reports__wrap_4"
    fi
  done

  @compact __testing__escapes_missing_reports__out "$__testing__escapes_missing_reports__testing_escapes__missing__acc"
  println "$__testing__escapes_missing_reports__out"
}

:<<'FUN'
Prints true when the directory holds at least one junit report, false when it
holds none or does not exist.

  $1 report directory
FUN
__testing__escapes__has_report() {
  __testing__escapes__has_report__first="$(
    find "$1" -maxdepth 1 -name '*.xml' 2>/dev/null \
    | head -n 1
  )"
  @succeeds __testing__escapes__has_report__out @defined "$__testing__escapes__has_report__first"
  println "$__testing__escapes__has_report__out"
}

:<<'PUB_FUN'
The would-be escapes for one run: per suite, the failed keys the row's
selection left out, sorted and deduplicated across suites. A record that did
not narrow has none.

  $1 record   $2 failed keys by suite (object)

Usage: testing__escapes "$record" "$failed"
PUB_FUN
testing__escapes() {
  @run_awk __testing__escapes__out \
    "$__testing__escapes__DIR/escapes.awk" \
    "$1" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" \
    --with "$2" || return 1
  println "$__testing__escapes__out"
}

:<<'PUB_FUN'
The failing tests each selector's own answer would have skipped, per
selector on the record: over the file-keyed suite rows, the failed keys the
selector's tests for that suite leave out. A shadow selector is judged by
this before it may leave a test out, and an escape is laid at a tier's
door by it. A record naming no selectors has none to judge.

  testing__escapes_by_selector "$record" '{"unit": ["test/b.bats"]}'
  -> {"areas": [], "trace": ["test/b.bats"]}

  $1 record   $2 failed keys by suite (object)

Usage: testing__escapes_by_selector "$record" "$failed"
PUB_FUN
testing__escapes_by_selector() {
  @run_awk __testing__escapes_by_selector__out \
    "$__testing__escapes__DIR/selector_escapes.awk" \
    "$1" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" \
    --with "$2" || return 1
  println "$__testing__escapes_by_selector__out"
}

:<<'PUB_FUN'
A pipeline's failed keys with those already failing on the branch the review
targets left out, per suite. A review stacked on another branch runs that
branch's layers in its full-suite jobs, so their failures show up here too;
they belong to that branch's own review, not this one.

  testing__escapes_own_failures '{"unit":["test/a.bats","test/b.bats"]}' '{"unit":["test/a.bats"]}'
  -> {"unit": ["test/b.bats"]}

  $1 failed keys by suite   $2 the target branch's failed keys by suite
PUB_FUN
testing__escapes_own_failures() {
  @run_awk __testing__escapes_own_failures__out "$__testing__escapes__DIR/own_failures.awk" "$1" --with "$2" || return 1
  println "$__testing__escapes_own_failures__out"
}
