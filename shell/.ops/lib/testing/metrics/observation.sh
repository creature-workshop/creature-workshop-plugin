#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/resolver.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/time/api.sh"

:<<'FRAGMENT'
What a run observes about itself: when it began, and one row per suite it
dispatched. The caller holds those values and hands them to
testing__metrics__emit; nothing here is remembered between calls.
FRAGMENT

:<<'PUB_FUN'
The run context a record is stamped with: when the run began, both as the epoch
seconds durations are measured against and as the timestamp the record carries.

Usage: run="$(testing__metrics__begin)"
PUB_FUN
testing__metrics__begin() {
  @obj __testing__metrics__begin__out \
    '.started' "$(time__epoch_seconds)" \
    '.started_at' "$(time__utc_timestamp)"
  println "$__testing__metrics__begin__out"
}

:<<'FUN'
Seconds elapsed since <epoch_start>, floored at 0 so a clock that stepped
backwards yields a duration rather than a negative one.

  $1 epoch start
FUN
__testing__metrics__elapsed() {
  __testing__metrics__elapsed__now="$(time__epoch_seconds)"
  __testing__metrics__elapsed__seconds=$((__testing__metrics__elapsed__now - $1))
  if [ "$__testing__metrics__elapsed__seconds" -lt 0 ]; then
    __testing__metrics__elapsed__seconds=0
  fi
  println "$__testing__metrics__elapsed__seconds"
}

:<<'PUB_FUN'
One suite's share of the run, as the row the record carries. Built once the
suite has finished, so its duration and status are known.

  suite         the suite name
  runner        the runner that executed it
  selected      test files run, or "" when the runner has no file-level layout
  total         test files the suite has in full, or "" as above
  epoch_start   when this suite started (from time__epoch_seconds)
  status        "passed" or "failed"
  tests         the selected files (struct array), or "" for a full-suite run

Usage: testing__metrics__suite_row unit bats 3 41 "$started" passed "$files"
PUB_FUN
testing__metrics__suite_row() {
  @obj __testing__metrics__suite_row__obj_1 \
      '.suite' "$1" \
      '.runner' "$2" \
      '.selected' "$(__testing__metrics__count "$3")" \
      '.total' "$(__testing__metrics__count "$4")" \
      '.duration_seconds' "$(__testing__metrics__elapsed "$5")" \
      '.status' "$6"
  @patch __testing__metrics__suite_row__out \
    "$__testing__metrics__suite_row__obj_1" \
    '.tests' "$7"
  println "$__testing__metrics__suite_row__out"
}

:<<'FUN'
A count as a struct number, or null when the caller had nothing to count.

  $1 count or ""
FUN
__testing__metrics__count() {
  @null __testing__metrics__count__null_2
  println "${1:-$__testing__metrics__count__null_2}"
}

:<<'PUB_FUN'
The test files a suite runs in full, as a struct array of $PROJ-relative
paths, sorted: the tracked files under the suite's root that match its
globs and none of its excludes. Empty for a suite with no root, whose runner
runs something other than files.

  testing__metrics__suite_files '{"runner":"bats","root":"test","glob":"*.bats"}'
    ->  ["test/a.bats", "test/b.bats"]

args:
  $1  The suite config (effective)
PUB_FUN
testing__metrics__suite_files() {
  @get __testing__metrics__suite_files__root "$1" '.root' ''
  if ! @defined "$__testing__metrics__suite_files__root"; then
    @arr __testing__metrics__suite_files__out
    println "$__testing__metrics__suite_files__out"
    return 0
  fi

  @arr __testing__metrics__suite_files__roots "$__testing__metrics__suite_files__root"
  __testing__metrics__suite_files__globs="$(testing__suite_patterns "$1" '.glob')"
  __testing__metrics__suite_files__excludes="$(testing__suite_patterns "$1" '.exclude')"
  testing__glob_files \
    "$__testing__metrics__suite_files__roots" \
    "$__testing__metrics__suite_files__globs" \
    "$__testing__metrics__suite_files__excludes"
}

:<<'PUB_FUN'
The test files a suite runs in full, as a count -- the denominator the selected
count is a fraction of. Empty for a suite with no root, whose runner counts
something other than files.

  $1 suite config (effective)

Usage: testing__metrics__suite_total "$suite_cfg"
PUB_FUN
testing__metrics__suite_total() {
  @get __testing__metrics__suite_total__root "$1" '.root' ''
  if ! @defined "$__testing__metrics__suite_total__root"; then
    return 0
  fi

  __testing__metrics__suite_total__files="$(testing__metrics__suite_files "$1")"
  @len __testing__metrics__suite_total__out "$__testing__metrics__suite_total__files"
  println "$__testing__metrics__suite_total__out"
}
