#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Reading the run state of a commit off the Actions runs Forgejo lists for it.
A run's status is one of unknown, waiting, running, blocked, success,
failure, cancelled and skipped.
MODULE

: <<'FUN'
Prints the run state of a commit, from the runs list $1 that Forgejo answers
for it: {carried, state, url}. A skipped run ran nothing and is left out.
The state is "none" when no run is left, "failure" when one failed or was
cancelled, "pending" when one has not finished, and "success" otherwise.
One failed run decides the state whatever the other runs are still doing,
so a gate that reads it does not wait for them. The url is the first failed
run's page, or the first run's when none failed.

  __forgejo__run_state '{"workflow_runs":[{"status":"running","html_url":"u"}]}'
  -> {"carried":true,"state":"pending","url":"u"}
FUN
__forgejo__run_state() {
  @arr __forgejo__run_state__none
  @get __forgejo__run_state__listed "$1" '.workflow_runs' "$__forgejo__run_state__none"
  @filter __forgejo__run_state__runs "$__forgejo__run_state__listed" silt__text_is_not .status skipped
  @filter __forgejo__run_state__failed "$__forgejo__run_state__runs" __forgejo__run_failed

  __forgejo__run_state__state="$(__forgejo__state_of_runs "$__forgejo__run_state__runs" "$__forgejo__run_state__failed")"
  __forgejo__run_state__url="$(__forgejo__url_of_runs "$__forgejo__run_state__runs" "$__forgejo__run_state__failed")"

  @obj __forgejo__run_state__out \
    '.carried' true \
    '.state' "$__forgejo__run_state__state" \
    '.url' "$__forgejo__run_state__url"
  println "$__forgejo__run_state__out"
}

: <<'FUN'
A predicate for @filter: answers true in the variable $1 when the run $3
failed or was cancelled, and false otherwise.
FUN
__forgejo__run_failed() {
  @get __forgejo__run_failed__status "$3" '.status' ''

  case "$__forgejo__run_failed__status" in
    failure | cancelled) @true "$1" ;;
    *) @false "$1" ;;
  esac
}

: <<'FUN'
Prints the state the runs $1 give a commit, of which $2 are the ones that
failed: none, failure, pending or success.

args:
  $1  The runs that ran something
  $2  The runs among them that failed or were cancelled
FUN
__forgejo__state_of_runs() {
  if @empty "$1"; then
    println none
    return 0
  fi
  if ! @empty "$2"; then
    println failure
    return 0
  fi

  @filter __forgejo__state_of_runs__open "$1" silt__text_is_not .status success
  if @empty "$__forgejo__state_of_runs__open"; then
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
  $2  The runs among them that failed or were cancelled
FUN
__forgejo__url_of_runs() {
  if @empty "$2"; then
    @first __forgejo__url_of_runs__run "$1"
  else
    @first __forgejo__url_of_runs__run "$2"
  fi

  @get __forgejo__url_of_runs__out "$__forgejo__url_of_runs__run" '.html_url' ''
  println "$__forgejo__url_of_runs__out"
}
