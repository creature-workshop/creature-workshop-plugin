#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
Reading a directory of records and aggregating them into the rollout numbers.

A run that ran as several parallel jobs left one record per shard. Every
reader here folds the shards of one pipeline into one record, as
fold_shards.awk describes, so a caller sees runs and never parts of one.
FRAGMENT

# CONST: The awk program that counts the records into the rollout numbers.
__testing__metrics__ROLLUP="$SHELLOPS_DIR/lib/testing/metrics/rollup.awk"

# CONST: The awk program that folds a sharded run's records into one.
__testing__metrics__FOLD="$SHELLOPS_DIR/lib/testing/metrics/fold_shards.awk"

:<<'PUB_FUN'
The records in the metrics directory, as a struct array, oldest first, the
shards of each sharded run folded into one record. A file that does not
parse or that the schema rejects is skipped with a warning rather than
poisoning the aggregate. Yields an empty array when the directory is absent.

Usage: testing__metrics__records
PUB_FUN
testing__metrics__records() {
  __testing__metrics__records__dir="$(testing__metrics__dir)"
  if [ ! -d "$__testing__metrics__records__dir" ]; then
    @arr __testing__metrics__records__out
    println "$__testing__metrics__records__out"
    return 0
  fi

  __testing__metrics__records__files="$(__testing__metrics__record_files \
    "$__testing__metrics__records__dir")"
  __testing__metrics__fold_files "$__testing__metrics__records__files"
}

:<<'PUB_FUN'
The one record of the run that the given record files hold, the shards
folded into one when there are several. The files are those of one run, as
testing__metrics__run_files prints them. A file that does not parse or that
the schema rejects is skipped with a warning.

  testing__metrics__fold_files "$(testing__metrics__latest_record_files)"

args:
  $1  The record files of one run, one per line
PUB_FUN
testing__metrics__fold_files() {
  __testing__metrics__fold_files__records="$(__testing__metrics__fold_files "$1")"
  @first __testing__metrics__fold_files__out "$__testing__metrics__fold_files__records"
  println "$__testing__metrics__fold_files__out"
}

:<<'FUN'
The records the files hold, as a struct array in file order, the shards of
each sharded run folded into one record.

  $1 record files, one per line
FUN
__testing__metrics__fold_files() {
  @split __testing__metrics__fold_files__split_1 "$1"
  @arr __testing__metrics__fold_files__arr_2
  @reduce __testing__metrics__fold_files__records __testing__metrics__absorb_record \
    "$__testing__metrics__fold_files__split_1" \
    "$__testing__metrics__fold_files__arr_2"
  @run_awk __testing__metrics__fold_files__out "$__testing__metrics__FOLD" \
    "$__testing__metrics__fold_files__records" \
    --load "$SHELLOPS_DIR/lib/structs/silt/tree_edit.awk" \
    --load "$SHELLOPS_DIR/lib/structs/silt/numbers.awk" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__metrics__fold_files__out"
}

:<<'PUB_FUN'
The record files of the run that the record at <file> belongs to, one per
line: the file alone for a run that was one job, and every file in the
metrics directory whose record is a shard of the same pipeline for a run
that was sharded. Nothing when <file> is empty.

  testing__metrics__run_files .ops/testing-metrics/20260923T161328Z-46219.json
    ->  .ops/testing-metrics/20260923T161328Z-46219.json
        .ops/testing-metrics/20260923T161330Z-46220.json

args:
  $1  A record file
PUB_FUN
testing__metrics__run_files() {
  if ! @defined "$1"; then
    return 0
  fi
  __testing__metrics__run_files__record="$(__testing__metrics__read "$1" 2>/dev/null)" || {
    println "$1"
    return 0
  }
  @get __testing__metrics__run_files__shard "$__testing__metrics__run_files__record" '.run.shard' ''
  if ! @defined "$__testing__metrics__run_files__shard"; then
    println "$1"
    return 0
  fi
  @get __testing__metrics__run_files__pipeline "$__testing__metrics__run_files__record" '.run.pipeline' ''
  __testing__metrics__record_files "$(testing__metrics__dir)" \
    | while IFS= read -r __testing__metrics__run_files__file; do
        if @is_true "$(__testing__metrics__is_shard_of "$__testing__metrics__run_files__file" "$__testing__metrics__run_files__pipeline")"; then
          println "$__testing__metrics__run_files__file"
        fi
      done
}

:<<'FUN'
Prints true when the record at <file> reads and is a shard of <pipeline>,
false otherwise.

  $1 file   $2 pipeline
FUN
__testing__metrics__is_shard_of() {
  __testing__metrics__is_shard_of__record="$(__testing__metrics__read "$1" 2>/dev/null)" || {
    @false __testing__metrics__is_shard_of__out
    println "$__testing__metrics__is_shard_of__out"
    return 0
  }
  @get __testing__metrics__is_shard_of__shard "$__testing__metrics__is_shard_of__record" '.run.shard' ''
  @get __testing__metrics__is_shard_of__pipeline "$__testing__metrics__is_shard_of__record" '.run.pipeline' ''
  if @defined "$__testing__metrics__is_shard_of__shard" && [ "$__testing__metrics__is_shard_of__pipeline" = "$2" ]; then
    @true __testing__metrics__is_shard_of__out
  else
    @false __testing__metrics__is_shard_of__out
  fi
  println "$__testing__metrics__is_shard_of__out"
}

:<<'PUB_FUN'
The record files of the newest run in the metrics directory, one per line:
the newest record's file, and the files of the other shards of its pipeline
when the run was sharded. Nothing when there is no record.

Usage: testing__metrics__latest_record_files
PUB_FUN
testing__metrics__latest_record_files() {
  testing__metrics__run_files "$(testing__metrics__latest_record_file)"
}

:<<'PUB_FUN'
The record files of the newest run of <review>, one per line: the newest
record naming the review, and the files of the other shards of its pipeline
when the run was sharded. Nothing when the directory holds no record of the
review.

Usage: testing__metrics__record_files_for_review <review>
PUB_FUN
testing__metrics__record_files_for_review() {
  testing__metrics__run_files "$(testing__metrics__record_file_for_review "$1")"
}

:<<'PUB_FUN'
The newest record's file in the metrics directory, or nothing when there is
none. Names sort chronologically, so the newest is the last.

Usage: testing__metrics__latest_record_file
PUB_FUN
testing__metrics__latest_record_file() {
  __testing__metrics__latest_record_file__dir="$(testing__metrics__dir)"
  if [ ! -d "$__testing__metrics__latest_record_file__dir" ]; then
    return 0
  fi
  __testing__metrics__record_files "$__testing__metrics__latest_record_file__dir" \
    | tail -n 1
}

:<<'PUB_FUN'
The newest record file in the metrics directory whose run belongs to
<review>, or nothing when the directory holds no record of that review. A
file that does not parse or that the schema rejects names no review.

  testing__metrics__record_file_for_review 537
    ->  .ops/testing-metrics/20260923T161328Z-46219.json

Usage: testing__metrics__record_file_for_review <review>
PUB_FUN
testing__metrics__record_file_for_review() {
  __testing__metrics__record_file_for_review__dir="$(testing__metrics__dir)"
  if [ ! -d "$__testing__metrics__record_file_for_review__dir" ]; then
    return 0
  fi
  __testing__metrics__record_files "$__testing__metrics__record_file_for_review__dir" \
    | sort -r \
    | while IFS= read -r __testing__metrics__record_file_for_review__file; do
        if @is_true "$(__testing__metrics__names_review "$__testing__metrics__record_file_for_review__file" "$1")"; then
          println "$__testing__metrics__record_file_for_review__file"
          break
        fi
      done
}

:<<'FUN'
Prints true when the record at <file> reads and belongs to <review>, false
otherwise.

  $1 file   $2 review
FUN
__testing__metrics__names_review() {
  __testing__metrics__names_review__record="$(__testing__metrics__read "$1" 2>/dev/null)" || {
    @false __testing__metrics__names_review__out
    println "$__testing__metrics__names_review__out"
    return 0
  }
  @get __testing__metrics__names_review__get_3 "$__testing__metrics__names_review__record" '.run.review' ''
  @succeeds __testing__metrics__names_review__out [ "$__testing__metrics__names_review__get_3" = "$2" ]
  println "$__testing__metrics__names_review__out"
}

:<<'FUN'
The record files in <dir>, one path per line, sorted by name (which sorts them
by run start). No records is no output.

  $1 dir
FUN
__testing__metrics__record_files() {
  (
    cd "$1" 2>/dev/null || exit 0
    set +f
    for __testing__metrics__record_files__f in *.json; do
      [ -f "$__testing__metrics__record_files__f" ] && printf '%s/%s\n' "$1" "$__testing__metrics__record_files__f"
    done
  ) | sort
  # A directory holding no *.json is a clean empty result, not a failure: the
  # unmatched glob's [ -f ] test would otherwise leak rc=1 to a `set -e` caller.
  return 0
}

:<<'FUN'
@reduce callback: appends one record file's contents, skipping what it cannot
trust.

  $1 accumulator (records)   $2 file path (wrapped)
FUN
__testing__metrics__absorb_record() {
  @unwrap __testing__metrics__absorb_record__file "$2"
  __testing__metrics__absorb_record__json="$(__testing__metrics__read \
    "$__testing__metrics__absorb_record__file")" || {
    warn "testing/metrics: skipping unreadable record $__testing__metrics__absorb_record__file"
    echo "$1"
    return 0
  }

  @push __testing__metrics__absorb_record__out "$1" "$__testing__metrics__absorb_record__json"
  println "$__testing__metrics__absorb_record__out"
}

:<<'PUB_FUN'
Aggregates records into the rollout numbers: how many runs, how narrow the
narrowed ones were, and how much wall clock that bought against the full-suite
runs recorded beside them.

  records  [<record>, ...]

selection_ratio is null until a narrowed run exists, and seconds_saved until a
full-suite run exists to compare against -- an unmeasured quantity reads as
unmeasured, never as zero.

Usage: testing__metrics__rollup "$(testing__metrics__records)"
PUB_FUN
testing__metrics__rollup() {
  @run_awk __testing__metrics__rollup__out "$__testing__metrics__ROLLUP" "$1" \
    --load "$SHELLOPS_DIR/lib/structs/silt/numbers.awk" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__metrics__rollup__out"
}
