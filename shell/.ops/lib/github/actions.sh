#!/bin/sh

:<<'FRAGMENT'
GitHub Actions: dispatching a workflow, listing and reading its runs, and waiting on one.
FRAGMENT

:<<'PUB_FUN'
Dispatches a GitHub Actions workflow on a given ref.

Usage: github__dispatch_workflow "$dispatch_options"
PUB_FUN
github__dispatch_workflow() {
  __github__dispatch_workflow__token="$(__github__validate_token "$1")" || return 1
  __github__dispatch_workflow__http_opts="$(__github__http_opts "$__github__dispatch_workflow__token")"
  @get __github__dispatch_workflow__ref "$1" '.ref'
  __github__dispatch_workflow__endpoint="$(__github__dispatch_endpoint "$1")"
  @obj __github__dispatch_workflow__body '.ref' "$__github__dispatch_workflow__ref"

  http__post "$__github__dispatch_workflow__endpoint" "$__github__dispatch_workflow__body" "$__github__dispatch_workflow__http_opts"
}

:<<'PUB_FUN'
Lists workflow runs, optionally filtered by branch/ref and event type.
Returns the raw JSON response from the GitHub API.

Usage: github__list_workflow_runs "$dispatch_options"
PUB_FUN
github__list_workflow_runs() {
  __github__list_workflow_runs__token="$(__github__validate_token "$1")" || return 1
  __github__list_workflow_runs__http_opts="$(__github__http_opts "$__github__list_workflow_runs__token")"

  __github__list_workflow_runs__endpoint="${__github__BASE}${__github__WORKFLOW_RUNS_ENDPOINT}"
  __github__list_workflow_runs__endpoint="$(__github__fill "$__github__list_workflow_runs__endpoint" owner "$1")"
  __github__list_workflow_runs__endpoint="$(__github__fill "$__github__list_workflow_runs__endpoint" repo "$1")"
  __github__list_workflow_runs__endpoint="$(__github__fill "$__github__list_workflow_runs__endpoint" workflow "$1")"

  @get __github__list_workflow_runs__ref "$1" '.ref'
  if @defined "$__github__list_workflow_runs__ref"; then
    __github__list_workflow_runs__endpoint="${__github__list_workflow_runs__endpoint}?branch=${__github__list_workflow_runs__ref}&per_page=10"
  else
    __github__list_workflow_runs__endpoint="${__github__list_workflow_runs__endpoint}?per_page=10"
  fi

  http__get "$__github__list_workflow_runs__endpoint" "$__github__list_workflow_runs__http_opts"
}

:<<'PUB_FUN'
Waits for a dispatched workflow to be picked up as a run.
Returns the run JSON once it appears, or returns 1 on timeout.

Expects dispatch_options with owner, repo, workflow, ref, token.
Optional second argument: max attempts (default 10).
Optional third argument: interval in seconds (default 5).

Usage: github__wait_for_run_start "$dispatch_options" [attempts] [interval]
PUB_FUN
github__wait_for_run_start() {
  __github__wait_for_run_start__options="$1"
  __github__wait_for_run_start__max_attempts="${2:-10}"
  __github__wait_for_run_start__interval="${3:-5}"

  __github__wait_for_run_start__attempt=1
  while [ "$__github__wait_for_run_start__attempt" -le "$__github__wait_for_run_start__max_attempts" ]; do
    __github__wait_for_run_start__runs_json="$(github__list_workflow_runs "$__github__wait_for_run_start__options")"
    @get __github__wait_for_run_start__run_id "$__github__wait_for_run_start__runs_json" '.workflow_runs[0].id' ""

    if @defined "$__github__wait_for_run_start__run_id"; then
      @get __github__wait_for_run_start__out "$__github__wait_for_run_start__runs_json" '.workflow_runs[0]'
      println "$__github__wait_for_run_start__out"
      return 0
    fi

    sleep "$__github__wait_for_run_start__interval"
    __github__wait_for_run_start__attempt=$((__github__wait_for_run_start__attempt + 1))
  done

  return 1
}

:<<'PUB_FUN'
Gets a single workflow run by ID.

Usage: github__get_run "$run_options"
PUB_FUN
github__get_run() {
  __github__get_run__token="$(__github__validate_token "$1")" || return 1
  __github__get_run__http_opts="$(__github__http_opts "$__github__get_run__token")"
  __github__get_run__endpoint="$(__github__run_endpoint "$1")"

  http__get "$__github__get_run__endpoint" "$__github__get_run__http_opts"
}

:<<'PUB_FUN'
Re-runs a workflow run. Returns 0 on success, 1 on failure.

Usage: github__rerun_workflow "$run_options"
PUB_FUN
github__rerun_workflow() {
  __github__rerun_workflow__token="$(__github__validate_token "$1")" || return 1
  __github__rerun_workflow__http_opts="$(__github__http_opts "$__github__rerun_workflow__token")"
  __github__rerun_workflow__endpoint="$(__github__run_endpoint "$1")"

  http__post "${__github__rerun_workflow__endpoint}/rerun" "" "$__github__rerun_workflow__http_opts" > /dev/null
}

:<<'PUB_FUN'
Cancels a workflow run. Returns 0 on success, 1 on failure.

Usage: github__cancel_run "$run_options"
PUB_FUN
github__cancel_run() {
  __github__cancel_run__token="$(__github__validate_token "$1")" || return 1
  __github__cancel_run__http_opts="$(__github__http_opts "$__github__cancel_run__token")"
  __github__cancel_run__endpoint="$(__github__run_endpoint "$1")"

  http__post "${__github__cancel_run__endpoint}/cancel" "" "$__github__cancel_run__http_opts" > /dev/null
}

:<<'PUB_FUN'
Polls a workflow run until it reaches a terminal state (completed).
Returns the final run JSON.

Optional second argument: max attempts (default 60).
Optional third argument: interval in seconds (default 15).

Usage: github__wait_for_run_result "$run_options" [attempts] [interval]
PUB_FUN
github__wait_for_run_result() {
  __github__wait_for_run_result__options="$1"
  __github__wait_for_run_result__max_attempts="${2:-60}"
  __github__wait_for_run_result__interval="${3:-15}"

  __github__wait_for_run_result__attempt=1
  while [ "$__github__wait_for_run_result__attempt" -le "$__github__wait_for_run_result__max_attempts" ]; do
    __github__wait_for_run_result__run_json="$(github__get_run "$__github__wait_for_run_result__options")"
    @get __github__wait_for_run_result__status "$__github__wait_for_run_result__run_json" '.status'

    if [ "$__github__wait_for_run_result__status" = "completed" ]; then
      echo "$__github__wait_for_run_result__run_json"
      return 0
    fi

    sleep "$__github__wait_for_run_result__interval"
    __github__wait_for_run_result__attempt=$((__github__wait_for_run_result__attempt + 1))
  done

  @get __github__wait_for_run_result__get_1 "$__github__wait_for_run_result__options" '.run_id'
  error "Timed out waiting for run $__github__wait_for_run_result__get_1 to complete"
  return 1
}
