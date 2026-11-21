#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/agents/headless/state.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/process.sh"

:<<'FRAGMENT'
What a caller is told about a headless run: the record of one run in the
contract's shape, the summary of an agent that a listing shows, and the files
a run leaves behind.
FRAGMENT

__agents__headless__REVIEW_URL="https?://[^[:space:]<>\"')]*/(-/merge_requests|pull)/[0-9]+"

:<<'FUN'
Prints what the CLI wrote for the run directory $1, nothing before it wrote
anything.
FUN
__agents__headless__result() {
  if [ -f "$1/out" ]; then
    cat "$1/out"
  fi
}

:<<'FUN'
Prints the review URLs the run directory $1's output mentions, as an array
without repeats: the merge requests and pull requests the agent opened or
named. Empty when it mentions none.
FUN
__agents__headless__reviews() {
  @arr __agents__headless__reviews__urls
  if [ ! -f "$1/out" ]; then
    println "$__agents__headless__reviews__urls"
    return 0
  fi
  while read -r __agents__headless__reviews__url; do
    @wrap __agents__headless__reviews__wrap_1 "$__agents__headless__reviews__url"
    @push __agents__headless__reviews__urls "$__agents__headless__reviews__urls" "$__agents__headless__reviews__wrap_1"
  done <<EOF
$(grep -oE "$__agents__headless__REVIEW_URL" "$1/out" | sort -u)
EOF
  @filter __agents__headless__reviews__urls "$__agents__headless__reviews__urls" silt__text_is_not . ''
  println "$__agents__headless__reviews__urls"
}

:<<'FUN'
Prints the record of the run directory $1 in the contract's shape: its id,
status, result and reviews, with the exit code once recorded and where the
output is.
FUN
__agents__headless__record() {
  @obj __agents__headless__record__out \
    '.id'        "${1##*/}" \
    '.status'    "$(__agents__headless__status "$1")" \
    '.result'    "$(__agents__headless__result "$1")" \
    '.reviews'   "$(__agents__headless__reviews "$1")" \
    '.exit_code' "$(__agents__headless__exit_code "$1")" \
    '.log'       "$1/out"
  println "$__agents__headless__record__out"
}

:<<'FUN'
Prints the record of the agent $3 in the shape the listing actions read: its
id, the status of its latest run, that run's id, and its name. An agent with
no run yet is CREATING.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
FUN
__agents__headless__agent_record() {
  __agents__headless__agent_record__dir="$(agents__headless__agent_dir "$1" "$2" "$3")"
  __agents__headless__agent_record__latest="$(__agents__headless__run_ids "$__agents__headless__agent_record__dir" | head -n 1)"
  __agents__headless__agent_record__status=CREATING
  if @defined "$__agents__headless__agent_record__latest"; then
    __agents__headless__agent_record__status="$(__agents__headless__status "$__agents__headless__agent_record__dir/$__agents__headless__agent_record__latest")"
  fi
  @obj __agents__headless__agent_record__out \
    '.id'          "$3" \
    '.status'      "$__agents__headless__agent_record__status" \
    '.latestRunId' "$__agents__headless__agent_record__latest" \
    '.name'        "$(__agents__headless__agent_name "$__agents__headless__agent_record__dir")"
  println "$__agents__headless__agent_record__out"
}

:<<'FUN'
Prints the array $1 with the files the run directory $2 holds as artifacts
pushed onto it, each a path and a size: the output and the errors, once each
exists.

args:
  $1  The artifacts so far
  $2  The run directory
FUN
__agents__headless__artifacts_onto() {
  __agents__headless__artifacts_onto__files="$1"
  for __agents__headless__artifacts_onto__name in out err; do
    __agents__headless__artifacts_onto__path="$2/$__agents__headless__artifacts_onto__name"
    if [ -f "$__agents__headless__artifacts_onto__path" ]; then
      __agents__headless__artifacts_onto__size="$(wc -c < "$__agents__headless__artifacts_onto__path" | tr -d ' ')"
      @obj __agents__headless__artifacts_onto__file \
        '.path' "$__agents__headless__artifacts_onto__path" \
        '.size' "$__agents__headless__artifacts_onto__size"
      @push __agents__headless__artifacts_onto__files "$__agents__headless__artifacts_onto__files" "$__agents__headless__artifacts_onto__file"
    fi
  done
  println "$__agents__headless__artifacts_onto__files"
}
