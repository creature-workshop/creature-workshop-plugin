#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/http/api.sh" \
  "$SHELLOPS_DIR/lib/agents/cursor/http.sh" \
  "$SHELLOPS_DIR/lib/agents/cursor/payloads.sh"

:<<'DOC'
The cursor adaptor: Cursor Cloud Agents, v1. An agent is durable and every
prompt is a run on it; a run's status, final reply and pushed branches are
read from the run. A run routes to Cursor's own machines, or to a pool or
machine the caller hosts, through the options' cursor.env block, which
options.schema.json beside this file defines.

Authored as the @agent.cursor structural contract below: agents__load_adaptor
re-homes each inner role to cursor_<role>, which lib/agents/api.sh
dispatches to as agents_<role>. The request side is http.sh beside this
file, the bodies and records payloads.sh. Implements the contract
lib/agents/base.sh names.

API reference: https://cursor.com/docs-static/cloud-agents-openapi.yaml
DOC

:<<'DOC'
The cursor adaptor as a structural contract; inner @-roles re-home to
cursor_<role> on load, in the order lib/agents/base.sh lists them.
DOC
@agent.cursor() {
  :<<'FUN'
Prints the environment variable that carries the Cursor API key.
FUN
  @token_env_name() {
    printf 'CURSOR_AGENT_API_KEY\n'
  }

  :<<'FUN'
Creates an agent from the run options $1 with the prompt $2, which enqueues
its first run, and prints what started.

  cursor_run "$options" "Add a README"
  ->  {"agent_id":"bc-...","run_id":"run-...","url":"https://cursor.com/agents/bc-..."}
FUN
  @run() {
    __agents__cursor__payloads__check_options "$1" || return 1
    __cursor_run__opts="$(__agents__cursor__http__write_opts "$1")" || return 1
    __cursor_run__body="$(__agents__cursor__payloads__create_body "$1" "$2")"
    __cursor_run__result="$(http__post "$(__agents__cursor__http__agents_url)" "$__cursor_run__body" "$__cursor_run__opts")" || return 1
    @get __at1 "$__cursor_run__result" '.agent.id'
    @get __at2 "$__cursor_run__result" '.run.id'
    @get __at3 "$__cursor_run__result" '.agent.url' ''
    @obj __at_out \
      '.agent_id' "$__at1" \
      '.run_id'   "$__at2" \
      '.url'      "$__at3"
    println "$__at_out"
  }

  :<<'FUN'
Starts a further run on the agent $2 with the prompt $3 and prints its id.

  cursor_followup "$options" bc-1 "Also add tests"  ->  {"run_id":"run-..."}
FUN
  @followup() {
    __agents__cursor__payloads__check_options "$1" || return 1
    __cursor_followup__opts="$(__agents__cursor__http__write_opts "$1")" || return 1
    @obj __cursor_followup__body '.prompt.text' "$3"
    __cursor_followup__result="$(http__post "$(__agents__cursor__http__agent_url "$2" runs)" "$__cursor_followup__body" "$__cursor_followup__opts")" || return 1
    @get __at4 "$__cursor_followup__result" '.run.id'
    @obj __at_out '.run_id' "$__at4"
    println "$__at_out"
  }

  :<<'FUN'
Prints the run $3 on the agent $2 as the provider records it, with .reviews
added: the URLs of the reviews the agent opened from the branches it pushed,
so the record carries what the contract names.
FUN
  @get_run() {
    __cursor_get_run__opts="$(__agents__cursor__http__read_opts "$1")" || return 1
    __cursor_get_run__record="$(http__get "$(__agents__cursor__http__run_url "$2" "$3")" "$__cursor_get_run__opts")" || return 1
    @set __at_out "$__cursor_get_run__record" '.reviews' "$(__agents__cursor__payloads__reviews "$__cursor_get_run__record")"
    println "$__at_out"
  }

  :<<'FUN'
Prints the caller's agents, newest first, as an array; archived ones left
out. At most the options' list_limit, one hundred by default.
FUN
  @list_agents() {
    __cursor_list_agents__opts="$(__agents__cursor__http__read_opts "$1")" || return 1
    @option __cursor_list_agents__limit "$1" 'list_limit' 100
    __cursor_list_agents__result="$(http__get "$(__agents__cursor__http__agents_url)?limit=${__cursor_list_agents__limit}&includeArchived=false" "$__cursor_list_agents__opts")" || return 1
    @arr __at5
    @get __at_out "$__cursor_list_agents__result" '.items' "$__at5"
    println "$__at_out"
  }

  :<<'FUN'
Prints the runs of the agent $2, newest first, as an array.
FUN
  @list_runs() {
    __cursor_list_runs__opts="$(__agents__cursor__http__read_opts "$1")" || return 1
    __cursor_list_runs__result="$(http__get "$(__agents__cursor__http__agent_url "$2" runs)" "$__cursor_list_runs__opts")" || return 1
    @arr __at6
    @get __at_out "$__cursor_list_runs__result" '.items' "$__at6"
    println "$__at_out"
  }

  :<<'FUN'
Cancels the run $3 on the agent $2 and prints the id the provider
acknowledges.
FUN
  @cancel() {
    __cursor_cancel__opts="$(__agents__cursor__http__write_opts "$1")" || return 1
    @obj __at7
    http__post "$(__agents__cursor__http__run_url "$2" "$3" cancel)" "$__at7" "$__cursor_cancel__opts"
  }

  :<<'FUN'
Archives the agent $2, ending any work tied to it, and prints the id the
provider acknowledges.
FUN
  @archive() {
    __cursor_archive__opts="$(__agents__cursor__http__write_opts "$1")" || return 1
    @obj __at8
    http__post "$(__agents__cursor__http__agent_url "$2" archive)" "$__at8" "$__cursor_archive__opts"
  }

  :<<'FUN'
Prints the files the agent $2 produced, as an array of path, size and time.
FUN
  @artifacts() {
    __cursor_artifacts__opts="$(__agents__cursor__http__read_opts "$1")" || return 1
    __cursor_artifacts__result="$(http__get "$(__agents__cursor__http__agent_url "$2" artifacts)" "$__cursor_artifacts__opts")" || return 1
    @arr __at9
    @get __at_out "$__cursor_artifacts__result" '.items' "$__at9"
    println "$__at_out"
  }

  :<<'FUN'
Prints the models the provider accepts for a run, as the array the API
returns.
FUN
  @list_models() {
    __cursor_list_models__opts="$(__agents__cursor__http__read_opts "$1")" || return 1
    __cursor_list_models__result="$(http__get "$(__agents__cursor__http__models_url)" "$__cursor_list_models__opts")" || return 1
    @arr __at10
    @get __at_out "$__cursor_list_models__result" '.items' "$__at10"
    println "$__at_out"
  }
}
