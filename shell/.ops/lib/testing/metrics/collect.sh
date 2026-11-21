#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/string/api.sh" \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/location.sh"

:<<'FRAGMENT'
Collecting the records other pipelines wrote into this one's metrics directory,
so a rollup read here spans the reviews merged before it rather than this run
alone.

A record outlives its run only as the artifacts archive of a job that kept
it. Each review merged into a branch left one on its latest pipeline: the
job that ran the impacted selection wrote it, and the escape check put its
verdict on it and kept that copy. This reads the archives back, the judged
copy first, and puts the records beside whatever the directory already holds.

A review whose record the directory already holds is not read again: a
review merges only once its pipeline has finished, so the archive its record
came from never changes. A directory carried from one pipeline to the next
therefore costs each pipeline only the reviews merged since.

One review's records are read the same way on their own, which is how the
escape check on the trunk reaches the record of the review that landed.
FRAGMENT

: <<'CONST'
The job whose archived copy of the metrics record carries the verdict, the
escape check, under whatever prefix the pipeline gives its jobs.
CONST
__testing__metrics__collect__VERDICT_JOB="testing/escapes"

# CONST: The job whose copy is read when the check kept none: the selection run.
__testing__metrics__collect__RUN_JOB="testing/impacted"

:<<'PUB_FUN'
Copies into the metrics directory the records the reviews merged into <branch>
at or after <since> left in their pipelines' archives, and prints the tally
as {reviews, records, held, skipped}: how many merged reviews it looked at,
how many records it collected, how many reviews the directory already held a
record of, and how many reviews it read no record from.

A review it reads no record from -- a pipeline the forge no longer answers
for, an impacted job that kept no archive, an archive with no record in it --
is a gap in the evidence rather than a failure of the collection: it is named
in a warning, counted as skipped, and left out. The list of merged reviews
failing to load is a failure.

  testing__metrics__collect "$options" "2026-08-15T00:00:00Z" main
  ->  {"reviews": 41, "records": 5, "held": 34, "skipped": 2}

args:
  $1  Forge options (.token; owner/repo optional)
  $2  ISO-8601 timestamp; only reviews merged at or after it are read
  $3  The branch the reviews were merged into
PUB_FUN
testing__metrics__collect() {
  __testing__metrics__collect__reviews="$(forge__merged_reviews_since "$2" "$3")" || return 1
  mkdir -p "$(testing__metrics__dir)"
  __testing__metrics__collect__held="$(__testing__metrics__collect__held_reviews)" || return 1

  @obj __testing__metrics__collect__obj_1 '.reviews' 0 '.records' 0 '.held' 0 '.skipped' 0
  @reduce __testing__metrics__collect__out __testing__metrics__collect__absorb_review \
    "$__testing__metrics__collect__reviews" \
    "$__testing__metrics__collect__obj_1" \
    "$1" \
    "$__testing__metrics__collect__held"
  println "$__testing__metrics__collect__out"
}

:<<'FUN'
The reviews the metrics directory already holds a record of, as a struct
array of review numbers; a record written outside a review names none and
holds nothing.

  __testing__metrics__collect__held_reviews  ->  ["388", "390", "392"]
FUN
__testing__metrics__collect__held_reviews() {
  __testing__metrics__collect__held_reviews__records="$(testing__metrics__records)" || return 1
  @arr __testing__metrics__collect__held_reviews__arr_2
  @reduce __testing__metrics__collect__held_reviews__out __testing__metrics__collect__note_review \
    "$__testing__metrics__collect__held_reviews__records" \
    "$__testing__metrics__collect__held_reviews__arr_2"
  println "$__testing__metrics__collect__held_reviews__out"
}

:<<'FUN'
@reduce callback: appends the review a record belongs to, when it names one.

  $1 reviews   $2 record
FUN
__testing__metrics__collect__note_review() {
  @get __testing__metrics__collect__note_review__review "$2" '.run.review' ''
  if ! @defined "$__testing__metrics__collect__note_review__review"; then
    println "$1"
    return 0
  fi
  @wrap __testing__metrics__collect__note_review__wrap_3 "$__testing__metrics__collect__note_review__review"
  @push __testing__metrics__collect__note_review__out "$1" "$__testing__metrics__collect__note_review__wrap_3"
  println "$__testing__metrics__collect__note_review__out"
}

:<<'FUN'
@reduce callback: adds one merged review's records to the tally, counts the
review as held when the directory already has its record, or as skipped when
none can be read from it.

  $1 tally   $2 review ({iid, merged_at, labels})   $3 forge options
  $4 the reviews already held (struct array of review numbers)
FUN
__testing__metrics__collect__absorb_review() {
  @get __testing__metrics__collect__absorb_review__iid "$2" '.iid'
  __testing__metrics__collect__absorb_review__tally="$(__testing__metrics__collect__add "$1" '.reviews' 1)"
  if @any __testing__metrics__collect__absorb_review__any_4 __testing__metrics__collect__is_review "$4" "$__testing__metrics__collect__absorb_review__iid"; @is_true "$__testing__metrics__collect__absorb_review__any_4"; then
    __testing__metrics__collect__add "$__testing__metrics__collect__absorb_review__tally" '.held' 1
    return 0
  fi

  @set __testing__metrics__collect__absorb_review__options \
    "$3" \
    '.review_number' \
    "$__testing__metrics__collect__absorb_review__iid"

  __testing__metrics__collect__absorb_review__copied="$(testing__metrics__collect_review \
    "$__testing__metrics__collect__absorb_review__options" \
    "$__testing__metrics__collect__absorb_review__iid"
  )" || {
    __testing__metrics__collect__add "$__testing__metrics__collect__absorb_review__tally" '.skipped' 1
    return 0
  }

  __testing__metrics__collect__add \
    "$__testing__metrics__collect__absorb_review__tally" \
    '.records' \
    "$__testing__metrics__collect__absorb_review__copied"
}

:<<'FUN'
@any callback: whether a held review number is the review's.

  $1 review number (wrapped)   $2 the review's number
FUN
__testing__metrics__collect__is_review() {
  @unwrap __testing__metrics__collect__is_review__unwrap_5 "$1"
  [ "$__testing__metrics__collect__is_review__unwrap_5" = "$2" ]
}

:<<'FUN'
The tally with one of its counts raised.

  $1 tally   $2 the count's path   $3 how much to add
FUN
__testing__metrics__collect__add() {
  @get __testing__metrics__collect__add__current "$1" "$2"
  @set __testing__metrics__collect__add__out "$1" "$2" "$((__testing__metrics__collect__add__current + $3))"
  println "$__testing__metrics__collect__add__out"
}

:<<'PUB_FUN'
Copies one review's records from the archives its head pipeline kept them in
into the metrics directory and prints how many: the escape check's copy,
verdict on it, when that job kept one, else the selection run's, one archive
per shard when the run was sharded. Fails, naming why in a warning, when the
review's pipeline cannot be read, when no job on it kept an archive of the
records, when an archive cannot be read, or when the archives hold no
record.

  testing__metrics__collect_review "$(@set "$options" '.review_number' 537)" 537  ->  1

args:
  $1  Forge options (.token and .review_number; owner/repo optional)
  $2  The review's number, as the warning names it
PUB_FUN
testing__metrics__collect_review() {
  mkdir -p "$(testing__metrics__dir)"
  __testing__metrics__collect_review__pipeline="$(forge__review_pipeline "$1")" || {
    warn "testing/metrics: no record read from review $2: its pipeline cannot be read."
    return 1
  }

  __testing__metrics__collect_review__jobs="$(__testing__metrics__collect__record_jobs \
    "$__testing__metrics__collect_review__pipeline"
  )"
  if @empty "$__testing__metrics__collect_review__jobs"; then
    warn "testing/metrics: no record read from review $2: no $__testing__metrics__collect__VERDICT_JOB or $__testing__metrics__collect__RUN_JOB job on its pipeline kept an archive."
    return 1
  fi

  __testing__metrics__collect_review__dir="$(mktemp -d)"
  if ! @all __testing__metrics__collect_review__unpacked __testing__metrics__collect__unpack "$__testing__metrics__collect_review__jobs" "$1" "$__testing__metrics__collect_review__dir" "$2"; @is_false "$__testing__metrics__collect_review__unpacked"; then
    rm -rf "$__testing__metrics__collect_review__dir"
    return 1
  fi

  __testing__metrics__collect_review__copied="$(__testing__metrics__collect__copy_records \
    "$__testing__metrics__collect_review__dir"
  )"
  rm -rf "$__testing__metrics__collect_review__dir"

  if [ "$__testing__metrics__collect_review__copied" -eq 0 ]; then
    warn "testing/metrics: no record read from review $2: $(__testing__metrics__collect__archives_of "$__testing__metrics__collect_review__jobs") no record."
    return 1
  fi
  println "$__testing__metrics__collect_review__copied"
}

:<<'FUN'
@all callback: unpacks one job's archive into the directory every archive
of the review is read from, and warns, naming the job, when the archive
cannot be read. A job's id is wrapped, as @all hands a member.

  $1 job id (wrapped)   $2 forge options   $3 the directory   $4 review number
FUN
__testing__metrics__collect__unpack() {
  @unwrap __testing__metrics__collect__unpack__id "$1"
  if ! forge__unpack_job_artifacts "$2" "$__testing__metrics__collect__unpack__id" "$3"; then
    warn "testing/metrics: no record read from review $4: the archive of job $__testing__metrics__collect__unpack__id cannot be read."
    return 1
  fi
}

:<<'FUN'
Prints the jobs' archives as the subject of a warning: "the archive of job
201 holds" for one job, "the archives of jobs 201, 202 hold" for several.

  $1 job ids (struct array)
FUN
__testing__metrics__collect__archives_of() {
  @len __testing__metrics__collect__archives_of__count "$1"
  @join __testing__metrics__collect__archives_of__ids "$1" ", "
  if [ "$__testing__metrics__collect__archives_of__count" -eq 1 ]; then
    println "the archive of job $__testing__metrics__collect__archives_of__ids holds"
    return 0
  fi
  println "the archives of jobs $__testing__metrics__collect__archives_of__ids hold"
}

:<<'FUN'
The ids of the jobs on a review's pipeline whose archives hold the records,
as a struct array: the escape check's when it kept one, else every job of
the selection run, which is one job, or one per shard when the run was
sharded. Empty when none kept an archive.

  $1 the review's pipeline ({iid, base, pipeline, jobs})
FUN
__testing__metrics__collect__record_jobs() {
  @arr __testing__metrics__collect__record_jobs__arr_6
  @get __testing__metrics__collect__record_jobs__get_7 "$1" '.jobs' "$__testing__metrics__collect__record_jobs__arr_6"
  @filter __testing__metrics__collect__record_jobs__archived \
    "$__testing__metrics__collect__record_jobs__get_7" \
    silt__text_is .archive true
  __testing__metrics__collect__record_jobs__verdict="$(__testing__metrics__collect__archived_jobs \
    "$__testing__metrics__collect__record_jobs__archived" \
    "$__testing__metrics__collect__VERDICT_JOB"
  )"
  if ! @empty "$__testing__metrics__collect__record_jobs__verdict"; then
    println "$__testing__metrics__collect__record_jobs__verdict"
    return 0
  fi
  __testing__metrics__collect__archived_jobs \
    "$__testing__metrics__collect__record_jobs__archived" \
    "$__testing__metrics__collect__RUN_JOB"
}

:<<'FUN'
The ids of the jobs among those that kept an archive that run under <name>,
as a struct array; empty when none does.

  $1 the jobs that kept an archive   $2 the job's name, without the pipeline's prefix
FUN
__testing__metrics__collect__archived_jobs() {
  @arr __testing__metrics__collect__archived_jobs__none
  @reduce __testing__metrics__collect__archived_jobs__out __testing__metrics__collect__note_job \
    "$1" \
    "$__testing__metrics__collect__archived_jobs__none" \
    "$2"
  println "$__testing__metrics__collect__archived_jobs__out"
}

:<<'FUN'
@reduce callback: appends a job's id to the ids when the job runs under
<name>.

  $1 ids   $2 job ({id, name, status, archive})   $3 the job's name
FUN
__testing__metrics__collect__note_job() {
  if ! __testing__metrics__collect__is_job "$2" "$3"; then
    println "$1"
    return 0
  fi
  @get __testing__metrics__collect__note_job__id "$2" '.id'
  @push __testing__metrics__collect__note_job__out "$1" "$__testing__metrics__collect__note_job__id"
  println "$__testing__metrics__collect__note_job__out"
}

:<<'FUN'
Whether a job runs under <name>, whatever prefix the pipeline gave it and
whichever shard of a parallel job it is. GitLab names the shards of a job
"<name> <index>/<total>", so a trailing shard mark is taken off the job's
name before the comparison.

  $1 job ({id, name, status, archive})   $2 the job's name
FUN
__testing__metrics__collect__is_job() {
  @get __testing__metrics__collect__is_job__name "$1" '.name' ''
  __testing__metrics__collect__is_job__unsharded="$(__testing__metrics__collect__without_shard_mark \
    "$__testing__metrics__collect__is_job__name"
  )"
  string__ends_with "$__testing__metrics__collect__is_job__unsharded" "$2"
}

:<<'FUN'
Prints a job's name without the " <index>/<total>" mark GitLab puts on each
shard of a parallel job; a name without the mark prints as it is.

  __testing__metrics__collect__without_shard_mark "shellops/testing/impacted 2/4"
    ->  shellops/testing/impacted
FUN
__testing__metrics__collect__without_shard_mark() {
  println "$1" | sed 's|  *[0-9][0-9]*/[0-9][0-9]*$||'
}

:<<'FUN'
Copies every record found under an unpacked archive into the metrics
directory and prints how many there were. The archive lays the records out as
the job that wrote them did, under a directory of the metrics directory's
name, wherever that sat in the job's tree.

  $1 the unpacked archive
FUN
__testing__metrics__collect__copy_records() {
  __testing__metrics__collect__copy_records__files="$(find \
    "$1" \
    -path "*/$__testing__metrics__DIR_NAME/*.json" \
    -type f \
    | sort
  )"
  if ! @defined "$__testing__metrics__collect__copy_records__files"; then
    printf '0\n'
    return 0
  fi

  @split __testing__metrics__collect__copy_records__split_9 "$__testing__metrics__collect__copy_records__files"
  @reduce __testing__metrics__collect__copy_records__out __testing__metrics__collect__copy_record \
    "$__testing__metrics__collect__copy_records__split_9" \
    0
  println "$__testing__metrics__collect__copy_records__out"
}

:<<'FUN'
@reduce callback: copies one record file into the metrics directory and
counts it.

  $1 count   $2 file path (wrapped)
FUN
__testing__metrics__collect__copy_record() {
  @unwrap __testing__metrics__collect__copy_record__unwrap_10 "$2"
  cp "$__testing__metrics__collect__copy_record__unwrap_10" "$(testing__metrics__dir)/"
  println "$(($1 + 1))"
}
