#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Reading the run state of a commit off the Actions runs GitHub lists for it.
A run's status is queued, in_progress or completed, and its conclusion is
set once it is completed.
MODULE

: <<'FUN'
Prints the run state of a commit, from the runs list $1 that GitHub answers
for it: {carried, state, url}. A skipped run ran nothing and is left out.
The state is "none" when no run is left, "failure" when one failed,
"pending" when one has not completed, and "success" otherwise. A neutral
conclusion counts as passed, as GitHub itself treats it. One failed run
decides the state whatever the other runs are still doing, so a gate that
reads it does not wait for them. The url is the first failed run's page, or
the first run's when none failed.

  __github__run_state '{"workflow_runs":[{"status":"queued","html_url":"u"}]}'
  -> {"carried":true,"state":"pending","url":"u"}
FUN
__github__run_state() {
  @arr __github__run_state__none
  @get __github__run_state__listed "$1" '.workflow_runs' "$__github__run_state__none"
  @filter __github__run_state__runs "$__github__run_state__listed" silt__text_is_not .conclusion skipped
  @filter __github__run_state__failed "$__github__run_state__runs" __github__run_failed

  __github__run_state__state="$(__github__state_of_runs "$__github__run_state__runs" "$__github__run_state__failed")"
  __github__run_state__url="$(__github__url_of_runs "$__github__run_state__runs" "$__github__run_state__failed")"

  @obj __github__run_state__out \
    '.carried' true \
    '.state' "$__github__run_state__state" \
    '.url' "$__github__run_state__url"
  println "$__github__run_state__out"
}

: <<'FUN'
A predicate for @filter: answers true in the variable $1 when the run $3
completed with a conclusion that is a failure, and false otherwise.
FUN
__github__run_failed() {
  @get __github__run_failed__status "$3" '.status' ''
  @get __github__run_failed__conclusion "$3" '.conclusion' ''

  if [ "$__github__run_failed__status" != completed ]; then
    @false "$1"
    return 0
  fi

  case "$__github__run_failed__conclusion" in
    failure | cancelled | timed_out | action_required | stale | startup_failure) @true "$1" ;;
    *) @false "$1" ;;
  esac
}

: <<'FUN'
Prints the state the runs $1 give a commit, of which $2 are the ones that
failed: none, failure, pending or success.

args:
  $1  The runs that ran something
  $2  The runs among them that failed
FUN
__github__state_of_runs() {
  if @empty "$1"; then
    println none
    return 0
  fi
  if ! @empty "$2"; then
    println failure
    return 0
  fi

  @filter __github__state_of_runs__open "$1" silt__text_is_not .status completed
  if @empty "$__github__state_of_runs__open"; then
    println success
  else
    println pending
  fi
}

: <<'FUN'
Prints the page of the first run in $2, the runs that failed, or of the
first run in $1 when none failed, and the empty string when there is no run
or the run names no page.

args:
  $1  The runs that ran something
  $2  The runs among them that failed
FUN
__github__url_of_runs() {
  if @empty "$2"; then
    @first __github__url_of_runs__run "$1"
  else
    @first __github__url_of_runs__run "$2"
  fi

  @get __github__url_of_runs__out "$__github__url_of_runs__run" '.html_url' ''
  println "$__github__url_of_runs__out"
}
