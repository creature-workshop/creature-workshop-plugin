#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/shard.sh"

:<<'FRAGMENT'
Assembling a run's record out of its context, its decision, and its suite rows,
and writing it to the metrics directory.

An unwritable directory is logged and the run continues -- measuring a run must
never be able to fail it.
FRAGMENT

:<<'PUB_FUN'
Writes the run's record and echoes the file it wrote.

  $1 run context   $2 decision   $3 suite rows

Returns 0 even when the record could not be written: the run's own result is
the only thing its exit status is allowed to mean.

Usage: testing__metrics__emit "$run" "$decision" "$rows"
PUB_FUN
testing__metrics__emit() {
  __testing__metrics__emit__run="$1"
  __testing__metrics__emit__decision="$2"
  __testing__metrics__emit__rows="$3"
  __testing__metrics__emit__record="$(__testing__metrics__record \
    "$__testing__metrics__emit__run" \
    "$__testing__metrics__emit__decision" \
    "$__testing__metrics__emit__rows")"

  if ! @is_true "$(__testing__metrics__valid "$__testing__metrics__emit__record")"; then
    error "testing/metrics: refusing to write a record the schema rejects (errors above)."
    return 0
  fi

  __testing__metrics__emit__dir="$(testing__metrics__dir)"
  if ! mkdir -p "$__testing__metrics__emit__dir" 2>/dev/null; then
    warn "testing/metrics: cannot create $__testing__metrics__emit__dir; no record written."
    return 0
  fi

  @get __testing__metrics__emit__get_1 "$__testing__metrics__emit__run" '.started_at'
  __testing__metrics__emit__name="$(__testing__metrics__filename \
    "$__testing__metrics__emit__get_1")"
  __testing__metrics__emit__file="$__testing__metrics__emit__dir/$__testing__metrics__emit__name"
  if ! __testing__metrics__write "$__testing__metrics__emit__record" "$__testing__metrics__emit__file"; then
    warn "testing/metrics: cannot write $__testing__metrics__emit__file; no record written."
    return 0
  fi

  log "testing/metrics: wrote $__testing__metrics__emit__file"
  println "$__testing__metrics__emit__file"
}

:<<'FUN'
The full record for the run.

  $1 run context   $2 decision   $3 suite rows
FUN
__testing__metrics__record() {
  __testing__metrics__record__run="$(__testing__metrics__run_block "$1" "$2")"
  __testing__metrics__record__selection="$(__testing__metrics__selection_block "$2" "$3")"

  @obj __testing__metrics__record__out \
    '.run' "$__testing__metrics__record__run" \
    '.selection' "$__testing__metrics__record__selection" \
    '.suites' "$3"
  println "$__testing__metrics__record__out"
}

:<<'FUN'
The run block: identity, timing, and the forge context that joins this record to
the pipeline whose full-suite result an escape check reads.

  $1 run context   $2 decision
FUN
__testing__metrics__run_block() {
  __testing__metrics__run_block__id="$(__testing__metrics__run_id)"
  __testing__metrics__run_block__review="${FORGE_REVIEW_IID:-${CI_MERGE_REQUEST_IID:-}}"
  @let "$1" __testing__metrics__run_block__ started started_at
  @let "$2" __testing__metrics__run_block__ status dispatch

  @wrap __testing__metrics__run_block__wrap_2 "$__testing__metrics__run_block__id"
  @obj __testing__metrics__run_block__out \
    '.id' "$__testing__metrics__run_block__wrap_2" \
    '.started_at' "$__testing__metrics__run_block__started_at" \
    '.duration_seconds' "$(__testing__metrics__elapsed "$__testing__metrics__run_block__started")" \
    '.status' "$__testing__metrics__run_block__status" \
    '.dispatch' "$__testing__metrics__run_block__dispatch" \
    '.review' "$(__testing__metrics__context_value "$__testing__metrics__run_block__review")" \
    '.commit' "$(__testing__metrics__context_value "${CI_COMMIT_SHA:-}")" \
    '.pipeline' "$(__testing__metrics__context_value "${CI_PIPELINE_ID:-}")" \
    '.shard' "$(__testing__metrics__shard_value)"
  println "$__testing__metrics__run_block__out"
  __testing__metrics__run_block__code=$?
  @unlet __testing__metrics__run_block__ started started_at
  @unlet __testing__metrics__run_block__ status dispatch
  return "$__testing__metrics__run_block__code"
}

:<<'FUN'
A forge context value as a struct string, or null when the run is not in that
context. Absent is recorded as null rather than "" so a reader cannot mistake
"outside CI" for "an empty pipeline id".

  $1 value or ""
FUN
__testing__metrics__context_value() {
  if ! @defined "$1"; then
    @null __testing__metrics__context_value__out
    println "$__testing__metrics__context_value__out"
    return 0
  fi
  @wrap __testing__metrics__context_value__out "$1"
  println "$__testing__metrics__context_value__out"
}

:<<'FUN'
The shard this run is, as the record carries it: {index, total} when the
job ran as one of several, null when it was the one job. Null rather than
{1, 1}, so a reader folding shards into runs can tell a run that was never
sharded from one shard of many.
FUN
__testing__metrics__shard_value() {
  if @is_false "$(testing__shard__is_partial)"; then
    @null __testing__metrics__shard_value__out
    println "$__testing__metrics__shard_value__out"
    return 0
  fi
  testing__shard
}

:<<'FUN'
The selection block: the decision, the run's totals summed from its suites,
and, when the decision names them, the full_suite areas that widened the run
with the files that reached each, the config edit the run classified with
the remappings it found, and what each selector claimed and contributed.

  $1 decision   $2 suite rows
FUN
__testing__metrics__selection_block() {
  @let "$1" __testing__metrics__selection_block__ mode reason areas widened_by config_edit remapped selectors

  @obj __testing__metrics__selection_block__block \
    '.mode' "$__testing__metrics__selection_block__mode" \
    '.reason' "$__testing__metrics__selection_block__reason" \
    '.areas' "$__testing__metrics__selection_block__areas" \
    '.selected' "$(__testing__metrics__sum_counts "$2" '.selected')" \
    '.total' "$(__testing__metrics__sum_counts "$2" '.total')"
  __testing__metrics__selection_block__status=$?
  if @defined "$__testing__metrics__selection_block__widened_by"; then
    @set __testing__metrics__selection_block__block \
      "$__testing__metrics__selection_block__block" \
      '.widened_by' \
      "$__testing__metrics__selection_block__widened_by"
    __testing__metrics__selection_block__status=$?
  fi
  if @defined "$__testing__metrics__selection_block__config_edit"; then
    @set __testing__metrics__selection_block__block \
      "$__testing__metrics__selection_block__block" \
      '.config_edit' \
      "$__testing__metrics__selection_block__config_edit"
    __testing__metrics__selection_block__status=$?
  fi
  if @defined "$__testing__metrics__selection_block__remapped"; then
    @set __testing__metrics__selection_block__block \
      "$__testing__metrics__selection_block__block" \
      '.remapped' \
      "$__testing__metrics__selection_block__remapped"
    __testing__metrics__selection_block__status=$?
  fi
  if @defined "$__testing__metrics__selection_block__selectors"; then
    @set __testing__metrics__selection_block__block \
      "$__testing__metrics__selection_block__block" \
      '.selectors' \
      "$__testing__metrics__selection_block__selectors"
    __testing__metrics__selection_block__status=$?
  fi
  @unlet __testing__metrics__selection_block__ mode reason areas widened_by config_edit remapped selectors
  println "$__testing__metrics__selection_block__block"
  return "$__testing__metrics__selection_block__status"
}

:<<'FUN'
The sum of one count field across the suite rows, or null when no row counted
it -- a run made entirely of runners without file-level layouts has no file
count, and reporting 0 would read as "ran nothing".

  $1 suite rows   $2 field path
FUN
__testing__metrics__sum_counts() {
  @pluck __testing__metrics__sum_counts__pluck_3 "$1" "$2"
  @filter __testing__metrics__sum_counts__counted "$__testing__metrics__sum_counts__pluck_3" silt__text_is_not . null
  if @len __testing__metrics__sum_counts__len_4 "$__testing__metrics__sum_counts__counted"; [ "$__testing__metrics__sum_counts__len_4" -eq 0 ]; then
    @null __testing__metrics__sum_counts__out
    println "$__testing__metrics__sum_counts__out"
    return 0
  fi
  @sum __testing__metrics__sum_counts__out "$__testing__metrics__sum_counts__counted"
  println "$__testing__metrics__sum_counts__out"
}
