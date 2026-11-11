#!/bin/sh

:<<'FRAGMENT'
The HTTP side of the cursor adaptor: the key the run options carry, the
request options for a read and for a write that must not be retried into a
duplicate, and the URLs of the v1 Cloud Agents API.

The cursor adaptor: Cursor Cloud Agents, v1. An agent is durable and every
prompt is a run on it; a run's status, final reply and pushed branches are
read from the run. A run routes to Cursor's own machines, or to a pool or
machine the caller hosts, through the options' cursor.env block, which
options.schema.json beside this file defines.

Authored as the @agent.cursor structural contract at the bottom of this
file: the interpreter re-homes each inner role to cursor_<role>, which
lib/agents/api.sh dispatches to as agents_<role>, and which any caller may
import and call by name (ADR 000005). Implements the contract
lib/agents/base.sh names. Built on lib/http.

API reference: https://cursor.com/docs-static/cloud-agents-openapi.yaml
FRAGMENT

# CONST: The API's origin; CURSOR_API_BASE points a run at another host.
__agents__cursor__http__BASE="${CURSOR_API_BASE:-https://api.cursor.com}"

# CONST: The path of the agents collection under the origin.
__agents__cursor__http__AGENTS="/v1/agents"

# CONST: The path of the models listing under the origin.
__agents__cursor__http__MODELS="/v1/models"

:<<'FUN'
Prints the URL of the agents collection: where an agent is created and the
caller's agents are listed.
FUN
__agents__cursor__http__agents_url() {
  printf '%s%s\n' "$__agents__cursor__http__BASE" "$__agents__cursor__http__AGENTS"
}

:<<'FUN'
Prints the URL of the models the provider accepts.
FUN
__agents__cursor__http__models_url() {
  printf '%s%s\n' "$__agents__cursor__http__BASE" "$__agents__cursor__http__MODELS"
}


:<<'FUN'
Prints the key the options $1 carry, failing when they carry none.
FUN
__agents__cursor__http__key() {
  @option __agents__cursor__http__key__key "$1" 'api_key' ''
  if ! @defined "$__agents__cursor__http__key__key"; then
    error "cursor: no API key in the options; set $(cursor_token_env_name) or .api_key"
    return 1
  fi
  println "$__agents__cursor__http__key__key"
}

:<<'FUN'
Prints the request options for a read: the bearer key from the run options $1.
FUN
__agents__cursor__http__read_opts() {
  __agents__cursor__http__read_opts__key="$(__agents__cursor__http__key "$1")" || return 1
  @obj __agents__cursor__http__read_opts__out '.auth' "Bearer $__agents__cursor__http__read_opts__key"
  println "$__agents__cursor__http__read_opts__out"
}

:<<'FUN'
Prints the request options for a write that must not be retried into a
duplicate: the bearer key, a short deadline, one attempt.
FUN
__agents__cursor__http__write_opts() {
  __agents__cursor__http__write_opts__key="$(__agents__cursor__http__key "$1")" || return 1
  @obj __agents__cursor__http__write_opts__out '.auth' "Bearer $__agents__cursor__http__write_opts__key" '.max_time' 30 '.retries' 1
  println "$__agents__cursor__http__write_opts__out"
}

:<<'FUN'
Prints the URL of the agent $1, or of its sub-resource $2 when given.

  __agents__cursor__http__agent_url bc-1 runs  ->  https://api.cursor.com/v1/agents/bc-1/runs
FUN
__agents__cursor__http__agent_url() {
  if @defined "${2:-}"; then
    printf '%s%s/%s/%s\n' "$__agents__cursor__http__BASE" "$__agents__cursor__http__AGENTS" "$1" "$2"
  else
    printf '%s%s/%s\n' "$__agents__cursor__http__BASE" "$__agents__cursor__http__AGENTS" "$1"
  fi
}

:<<'FUN'
Prints the URL of the run $2 on the agent $1, or of its sub-resource $3.
FUN
__agents__cursor__http__run_url() {
  if @defined "${3:-}"; then
    printf '%s/%s/%s\n' "$(__agents__cursor__http__agent_url "$1" runs)" "$2" "$3"
  else
    printf '%s/%s\n' "$(__agents__cursor__http__agent_url "$1" runs)" "$2"
  fi
}
