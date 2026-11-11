#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/agents/cursor-cli/process.sh"

:<<'DOC'
The cursor-cli adaptor: the Cursor CLI run headless, here, in the process
that asked for it. Where the cursor adaptor sends a prompt to Cursor's cloud
and reads the run back over HTTP, this one starts the CLI over the checkout
it is standing in, so a pipeline job's own variables are the agent's
environment, the MCP config the checkout carries is what it reaches, and
the job log is the run log. An agent is a chat the CLI created, a run is one
headless invocation over it, and a followup resumes the chat. The block that
options.schema.json beside this file defines names the executable, the
workspace and where state is kept.

Authored as the @agent.cursor-cli structural contract below:
agents__load_adaptor re-homes each inner role to cursor_cli_<role>, which
lib/agents/api.sh dispatches to as agents_<role>. Everything a headless run
shares with any other CLI is lib/agents/headless/api.sh; what is Cursor's own
is process.sh beside this file. Implements the contract lib/agents/base.sh
names.
DOC

:<<'DOC'
The cursor-cli adaptor as a structural contract; inner @-roles re-home to
cursor_cli_<role> on load, in the order lib/agents/base.sh lists them.
DOC
@agent.cursor-cli() {
  :<<'FUN'
Prints the environment variable that carries the Cursor CLI's key.
FUN
  @token_env_name() {
    printf 'CURSOR_API_KEY\n'
  }

  :<<'FUN'
Creates a chat for the run options $1, starts its first run over the prompt
$2, and prints what started: the chat as the agent, the run, and the output
file as the url.

  cursor_cli_run "$options" "Land the queue"
  ->  {"agent_id":"4c47...","run_id":"run-1","url":"/state/4c47.../run-1/out"}
FUN
  @run() {
    agents__headless__check_options "$__agents__cursor_cli__CONTEXT" "$1" || return 1
    __cursor_cli_run__key="$(agents__headless__require_key "$__agents__cursor_cli__CONTEXT" "$1")" || return 1
    @get __at1 "$1" '.name' ''
    __cursor_cli_run__agent="$(__agents__cursor_cli__create_chat "$1" "$__cursor_cli_run__key" "$__at1")" || return 1
    __cursor_cli_run__run="$(agents__headless__next_run "$__agents__cursor_cli__CONTEXT" "$1" "$__cursor_cli_run__agent")"
    __agents__cursor_cli__start "$1" "$__cursor_cli_run__agent" "$__cursor_cli_run__run" "$2" "$__cursor_cli_run__key"
    @obj __at_out \
      '.agent_id' "$__cursor_cli_run__agent" \
      '.run_id'   "$__cursor_cli_run__run" \
      '.url'      "$(agents__headless__run_dir "$__agents__cursor_cli__CONTEXT" "$1" "$__cursor_cli_run__agent" "$__cursor_cli_run__run")/out"
    println "$__at_out"
  }

  :<<'FUN'
Starts a further run on the agent $2's chat with the prompt $3 and prints
its id.

  cursor_cli_followup "$options" 4c47... "Also close the ticket"  ->  {"run_id":"run-2"}
FUN
  @followup() {
    agents__headless__check_options "$__agents__cursor_cli__CONTEXT" "$1" || return 1
    __cursor_cli_followup__key="$(agents__headless__require_key "$__agents__cursor_cli__CONTEXT" "$1")" || return 1
    __cursor_cli_followup__run="$(agents__headless__next_run "$__agents__cursor_cli__CONTEXT" "$1" "$2")"
    __agents__cursor_cli__start "$1" "$2" "$__cursor_cli_followup__run" "$3" "$__cursor_cli_followup__key"
    @obj __at_out '.run_id' "$__cursor_cli_followup__run"
    println "$__at_out"
  }

  :<<'FUN'
Prints the record of the run $3 on the agent $2: its status, what the CLI
wrote as the result, the reviews that output names, the exit code once
recorded and where the output is. Fails when no such run was started.
FUN
  @get_run() {
    agents__headless__get_run "$__agents__cursor_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Prints the agents the state holds, newest first, as an array of id, status,
latest run id and name; at most the options' list_limit, one hundred by
default.
FUN
  @list_agents() {
    agents__headless__list_agents "$__agents__cursor_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Prints the runs of the agent $2, newest first, as an array of records.
FUN
  @list_runs() {
    agents__headless__list_runs "$__agents__cursor_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Ends the run $3 on the agent $2 and marks it cancelled, and prints its id.
FUN
  @cancel() {
    agents__headless__cancel "$__agents__cursor_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Forgets the agent $2, its runs' state with it, and prints its id. A run
still going is ended first.
FUN
  @archive() {
    agents__headless__archive "$__agents__cursor_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Prints the files the agent $2's runs produced, as an array of path and
size: each run's output and errors.
FUN
  @artifacts() {
    agents__headless__artifacts "$__agents__cursor_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Prints the models the CLI lists for the run options $1's key, as an array
of id; empty when the account has none.
FUN
  @list_models() {
    __cursor_cli_list_models__key="$(agents__headless__require_key "$__agents__cursor_cli__CONTEXT" "$1")" || return 1
    __agents__cursor_cli__models "$1" "$__cursor_cli_list_models__key"
  }
}
