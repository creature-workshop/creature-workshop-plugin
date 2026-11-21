#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/agents/claude-cli/process.sh" \
  "$SHELLOPS_DIR/lib/agents/claude-cli/models.sh"

:<<'DOC'
The claude-cli adaptor: the Claude Code CLI run headless, here, in the process
that asked for it. The CLI starts in the checkout the job is standing in, so
the job's own variables are the agent's environment, the MCP servers the
options name are what it reaches, and the job log is the run log.

An agent is a session, named by the id the first run opens it with; a run is
one headless invocation over that session, and a followup resumes it by the
same id. Nothing is created before the first run: the id is the session. The
block that options.schema.json beside this file defines names the executable,
the workspace, where state is kept, and what the CLI is allowed to do;
options.sh beside it names what each of those does when the caller names
nothing.

Authored as the @agent.claude-cli structural contract below:
agents__load_adaptor re-homes each inner role to claude_cli_<role>, which
lib/agents/api.sh dispatches to as agents_<role>. Everything a headless run
shares with any other CLI is lib/agents/headless/api.sh; what is Claude's own
sits beside this file -- options.sh for the block, process.sh for starting a
run, models.sh for asking Anthropic what the account may use. Implements the
contract lib/agents/base.sh names.
DOC

:<<'DOC'
The claude-cli adaptor as a structural contract; inner @-roles re-home to
claude_cli_<role> on load, in the order lib/agents/base.sh lists them.
DOC
@agent.claude-cli() {
  :<<'FUN'
Prints the environment variable that carries the Claude Code CLI's key.
FUN
  @token_env_name() {
    printf 'ANTHROPIC_API_KEY\n'
  }

  :<<'FUN'
Opens a session for the run options $1, starts its first run over the prompt
$2, and prints what started: the session as the agent, the run, and the
output file as the url.

  claude_cli_run "$options" "Land the queue"
  ->  {"agent_id":"4c47...","run_id":"run-1","url":"/state/4c47.../run-1/out"}
FUN
  @run() {
    agents__headless__check_options "$__agents__claude_cli__CONTEXT" "$1" || return 1
    __claude_cli_run__key="$(agents__headless__require_key "$__agents__claude_cli__CONTEXT" "$1")" || return 1
    @get __claude_cli_run__name "$1" '.name' ''
    __claude_cli_run__agent="$(__agents__claude_cli__open_session "$1" "$__claude_cli_run__name")" || return 1
    __claude_cli_run__run="$(agents__headless__next_run "$__agents__claude_cli__CONTEXT" "$1" "$__claude_cli_run__agent")"
    __claude_cli_run__start="$(__agents__claude_cli__new_start \
      "$__claude_cli_run__agent" \
      "$__claude_cli_run__run" \
      "$2" \
      "$__claude_cli_run__key" \
      --session-id
    )"
    __agents__claude_cli__start "$1" "$__claude_cli_run__start"
    __agents__claude_cli__started "$1" "$__claude_cli_run__agent" "$__claude_cli_run__run"
  }

  :<<'FUN'
Starts a further run on the agent $2's session with the prompt $3 and prints
its id.

  claude_cli_followup "$options" 4c47... "Also close the ticket"  ->  {"run_id":"run-2"}
FUN
  @followup() {
    agents__headless__check_options "$__agents__claude_cli__CONTEXT" "$1" || return 1
    __claude_cli_followup__key="$(agents__headless__require_key "$__agents__claude_cli__CONTEXT" "$1")" || return 1
    __claude_cli_followup__run="$(agents__headless__next_run "$__agents__claude_cli__CONTEXT" "$1" "$2")"
    __claude_cli_followup__start="$(__agents__claude_cli__new_start \
      "$2" \
      "$__claude_cli_followup__run" \
      "$3" \
      "$__claude_cli_followup__key" \
      --resume
    )"
    __agents__claude_cli__start "$1" "$__claude_cli_followup__start"
    @obj __at_out '.run_id' "$__claude_cli_followup__run"
    println "$__at_out"
  }

  :<<'FUN'
Prints the record of the run $3 on the agent $2: its status, what the CLI
wrote as the result, the reviews that output names, the exit code once
recorded and where the output is. Fails when no such run was started.
FUN
  @get_run() {
    agents__headless__get_run "$__agents__claude_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Prints the agents the state holds, newest first, as an array of id, status,
latest run id and name; at most the options' list_limit, one hundred by
default.
FUN
  @list_agents() {
    agents__headless__list_agents "$__agents__claude_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Prints the runs of the agent $2, newest first, as an array of records.
FUN
  @list_runs() {
    agents__headless__list_runs "$__agents__claude_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Ends the run $3 on the agent $2 and marks it cancelled, and prints its id.
FUN
  @cancel() {
    agents__headless__cancel "$__agents__claude_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Forgets the agent $2, its runs' state with it, and prints its id. A run
still going is ended first.
FUN
  @archive() {
    agents__headless__archive "$__agents__claude_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Prints the files the agent $2's runs produced, as an array of path and
size: each run's output and errors.
FUN
  @artifacts() {
    agents__headless__artifacts "$__agents__claude_cli__CONTEXT" "$@"
  }

  :<<'FUN'
Prints the models the run options $1's account may use, as an array of id,
newest first. Anthropic is asked, since the CLI has no command that answers
this, so the options carry a key here as they do for a run.
FUN
  @list_models() {
    __agents__claude_cli__models__list "$1"
  }
}
