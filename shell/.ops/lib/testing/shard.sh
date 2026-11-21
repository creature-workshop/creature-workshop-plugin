#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Dividing a suite's test files among the parallel jobs of one CI job.

GitLab runs a job marked `parallel: N` as N jobs, and tells each one its
place through CI_NODE_INDEX (1 to N) and CI_NODE_TOTAL (N). A runner that
sorts its files and keeps every Nth from its own index runs a disjoint part
of the suite, and the N jobs together run all of it, with no coordination
between them. Outside such a job every file belongs to the one shard.
MODULE

# CONST: The awk program that deals sorted lines to the shards.
__testing__shard__AWK="$SHELLOPS_DIR/lib/testing/shard.awk"

: <<'PUB_FUN'
Prints the shard this job runs as {index, total}: GitLab's CI_NODE_INDEX
and CI_NODE_TOTAL when the job is one of several, and {1, 1} otherwise.

  CI_NODE_INDEX=2 CI_NODE_TOTAL=4 testing__shard  ->  {"index": 2, "total": 4}
PUB_FUN
testing__shard() {
  @obj __testing__shard__out \
    '.index' "${CI_NODE_INDEX:-1}" \
    '.total' "${CI_NODE_TOTAL:-1}"
  println "$__testing__shard__out"
}

: <<'PUB_FUN'
Prints true when this job is one of several shards, false when it is the
only one.
PUB_FUN
testing__shard__is_partial() {
  __testing__shard__is_partial__shard="$(testing__shard)"
  @get __testing__shard__is_partial__total "$__testing__shard__is_partial__shard" '.total'
  @succeeds __testing__shard__is_partial__out [ "$__testing__shard__is_partial__total" -gt 1 ]
  println "$__testing__shard__is_partial__out"
}

: <<'PUB_FUN'
Prints this job's shard as a log reads it: the index, a slash, the total.

  CI_NODE_INDEX=2 CI_NODE_TOTAL=4 testing__shard__label  ->  2/4
PUB_FUN
testing__shard__label() {
  __testing__shard__label__shard="$(testing__shard)"
  @get __testing__shard__label__index "$__testing__shard__label__shard" '.index'
  @get __testing__shard__label__total "$__testing__shard__label__shard" '.total'
  println "$__testing__shard__label__index/$__testing__shard__label__total"
}

: <<'PUB_FUN'
Prints the files of <files> that this job's shard runs, one per line. The
files are sorted by name and dealt round-robin: the shard with index i takes
the i-th file, the (i+N)-th, and so on, so every file lands in exactly one
shard. The one shard of a job that is not parallel takes every file. Empty
lines belong to no shard.

  testing__shard__files "$(printf 'b\na\nc\n')"   ->  a c   (index 1 of 2)

args:
  $1  The files, one per line
PUB_FUN
testing__shard__files() {
  __testing__shard__files__shard="$(testing__shard)"
  @get __testing__shard__files__index "$__testing__shard__files__shard" '.index'
  @get __testing__shard__files__total "$__testing__shard__files__shard" '.total'
  println "$1" \
    | sort \
    | awk \
      -v shard="$__testing__shard__files__index" \
      -v shards="$__testing__shard__files__total" \
      -f "$__testing__shard__AWK"
}
