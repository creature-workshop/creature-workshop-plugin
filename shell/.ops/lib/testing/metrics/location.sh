#!/bin/sh

:<<'FRAGMENT'
Where a run's record lives: the directory it is written to and read from, and
the filename that puts a directory of them in run order.
FRAGMENT

:<<'CONST'
The name of the directory records live in, by which a record is recognised
wherever a job's tree put that directory.
CONST
__testing__metrics__DIR_NAME="testing-metrics"

:<<'PUB_FUN'
The directory records are written to and read from. Defaults under .ops, the
project-root home for what shellops generates rather than what a human edits.
TESTING_METRICS_DIR points it somewhere else -- a CI artifact path, or a scratch
dir a maintainer drops downloaded records into for a longer-range rollup.

Usage: testing__metrics__dir
PUB_FUN
testing__metrics__dir() {
  println "${TESTING_METRICS_DIR:-$PROJ/.ops/$__testing__metrics__DIR_NAME}"
}

:<<'FUN'
The record file's name: when the run started, then its id, so a directory sorts
chronologically and two runs in the same second cannot collide. The punctuation
a filename should not carry is stripped from the timestamp.

  $1 started_at
FUN
__testing__metrics__filename() {
  __testing__metrics__filename__stamp="$(printf '%s' "$1" | tr -d ':-')"
  printf '%s-%s.json\n' \
    "$__testing__metrics__filename__stamp" \
    "$(__testing__metrics__run_id)"
}

:<<'FUN'
The run's identifier: the CI job id where there is one, else the process id.

Unique among runs that could write into the same directory at the same second,
which is all the filename needs of it.
FUN
__testing__metrics__run_id() {
  println "${CI_JOB_ID:-$$}"
}
