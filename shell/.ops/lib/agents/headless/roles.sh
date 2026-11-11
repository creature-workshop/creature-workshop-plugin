#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/agents/headless/state.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/process.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/record.sh"

:<<'FRAGMENT'
The contract roles that are the same for every headless adaptor: reading a
run, listing agents and runs, ending a run, forgetting an agent, and the
files it produced. An adaptor's own @get_run, @list_agents, @list_runs,
@cancel, @archive and @artifacts each hand their arguments straight to the
call here, so two adaptors never answer the same question two ways.
FRAGMENT

:<<'PUB_FUN'
Prints the record of the run $4 on the agent $3: its status, what the CLI
wrote as the result, the reviews that output names, the exit code once
recorded and where the output is. Fails when no such run was started.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
  $4  The run id
PUB_FUN
agents__headless__get_run() {
  __agents__headless__get_run__dir="$(__agents__headless__require_run_dir "$1" "$2" "$3" "$4")" || return 1
  __agents__headless__record "$__agents__headless__get_run__dir"
}

:<<'PUB_FUN'
Prints the agents the state holds, newest first, as an array of id, status,
latest run id and name; at most the run options' list_limit, one hundred by
default.

args:
  $1  The adaptor's context
  $2  The run options
PUB_FUN
agents__headless__list_agents() {
  @option __agents__headless__list_agents__limit "$2" 'list_limit' 100
  @arr __agents__headless__list_agents__agents
  for __agents__headless__list_agents__id in $(__agents__headless__agent_ids "$1" "$2" | sed "${__agents__headless__list_agents__limit}q"); do
    @push __agents__headless__list_agents__agents "$__agents__headless__list_agents__agents" "$(__agents__headless__agent_record "$1" "$2" "$__agents__headless__list_agents__id")"
  done
  println "$__agents__headless__list_agents__agents"
}

:<<'PUB_FUN'
Prints the runs of the agent $3, newest first, as an array of records.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
PUB_FUN
agents__headless__list_runs() {
  __agents__headless__list_runs__dir="$(agents__headless__agent_dir "$1" "$2" "$3")"
  @arr __agents__headless__list_runs__runs
  for __agents__headless__list_runs__id in $(__agents__headless__run_ids "$__agents__headless__list_runs__dir"); do
    @push __agents__headless__list_runs__runs "$__agents__headless__list_runs__runs" "$(__agents__headless__record "$__agents__headless__list_runs__dir/$__agents__headless__list_runs__id")"
  done
  println "$__agents__headless__list_runs__runs"
}

:<<'PUB_FUN'
Ends the run $4 on the agent $3 and marks it cancelled, and prints its id.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
  $4  The run id
PUB_FUN
agents__headless__cancel() {
  __agents__headless__kill "$(agents__headless__run_dir "$1" "$2" "$3" "$4")"
  @obj __agents__headless__cancel__out '.id' "$4"
  println "$__agents__headless__cancel__out"
}

:<<'PUB_FUN'
Forgets the agent $3, its runs' state with it, and prints its id. A run still
going is ended first.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
PUB_FUN
agents__headless__archive() {
  __agents__headless__archive__dir="$(agents__headless__agent_dir "$1" "$2" "$3")"
  for __agents__headless__archive__run in $(__agents__headless__run_ids "$__agents__headless__archive__dir"); do
    __agents__headless__kill "$__agents__headless__archive__dir/$__agents__headless__archive__run"
  done
  rm -rf "$__agents__headless__archive__dir"
  @obj __agents__headless__archive__out '.id' "$3"
  println "$__agents__headless__archive__out"
}

:<<'PUB_FUN'
Prints the files the agent $3's runs produced, as an array of path and size:
each run's output and errors.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
PUB_FUN
agents__headless__artifacts() {
  __agents__headless__artifacts__dir="$(agents__headless__agent_dir "$1" "$2" "$3")"
  @arr __agents__headless__artifacts__files
  for __agents__headless__artifacts__run in $(__agents__headless__run_ids "$__agents__headless__artifacts__dir"); do
    __agents__headless__artifacts__files="$(__agents__headless__artifacts_onto "$__agents__headless__artifacts__files" "$__agents__headless__artifacts__dir/$__agents__headless__artifacts__run")"
  done
  println "$__agents__headless__artifacts__files"
}
