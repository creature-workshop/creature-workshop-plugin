#!/bin/sh

import "$SHELLOPS_DIR/lib/manifest/api.sh"

:<<'FRAGMENT'
Common base for the agent adaptors, the bottom of the agents sandwich:

  lib/agents/api.sh        facade  -- agents_* dispatchers, selection, composites
  lib/agents/<id>/<id>.agent.op.sh   adaptor -- an @agent.<id> contract, one provider each
  lib/agents/base.sh       base    -- the option shape and the contract (here)

This layer knows nothing about which provider is selected. It holds the one
option constructor every adaptor reads, and what the manifest declares about
providers. The options are a neutral core the facade owns, plus one block per
provider under its own id, holding only what that provider understands:
the adaptor checks its block against its own schema and refuses a key it does
not know, so a setting is never silently dropped.

Adaptor contract -- every @agent.<id> contract implements these as its roles,
which agents__load_adaptor re-homes to <id>_<op>, a dash in the id spelled as
an underscore, and the facade dispatches to as agents_<op>; the loader and
the registry each refuse an adaptor missing any of them:

  <id>_token_env_name       the environment variable that carries its key
  <id>_run                  create an agent and its first run
  <id>_followup             a further run on an existing agent
  <id>_get_run              one run: status, result, what it opened
  <id>_list_agents          the caller's agents, newest first
  <id>_list_runs            an agent's runs, newest first
  <id>_cancel               cancel a run
  <id>_archive              archive an agent
  <id>_artifacts            the files an agent produced
  <id>_list_models          the model ids the provider accepts

Every call takes the options struct first and prints a struct or an array;
exit status is reserved for failure. The record <id>_get_run prints carries
three fields in the facade's vocabulary, whatever the provider's own: .status,
one of CREATING, RUNNING, FINISHED, ERROR, CANCELLED or EXPIRED; .result, the
final reply once the run has one; and .reviews, the URLs of the reviews it
opened, empty when it opened none. The composites above read nothing else.
FRAGMENT

:<<'PUB_FUN'
Prints the adaptor ids the manifest declares under agents.providers, as an
array; empty when it declares none.
PUB_FUN
agents__declared_providers() {
  @keys __agents__declared_providers__out "$(__agents__base__declared)"
  println "$__agents__declared_providers__out"
}

:<<'PUB_FUN'
Prints the manifest's sole declared provider; nothing when it declares none
or several, since with several the caller names one.
PUB_FUN
agents__sole_provider() {
  __agents__sole_provider__ids="$(agents__declared_providers)"
  if @len __agents__sole_provider__len_1 "$__agents__sole_provider__ids"; [ "$__agents__sole_provider__len_1" -eq 1 ]; then
    @first __agents__sole_provider__first_2 "$__agents__sole_provider__ids"
    @unwrap __agents__sole_provider__out "$__agents__sole_provider__first_2"
    println "$__agents__sole_provider__out"
  fi
}

:<<'FUN'
Prints the manifest's agents.providers object, empty when the manifest
declares none.
FUN
__agents__base__declared() {
  __agents__base__declared__providers="$(manifest__get agents_providers)"
  if @defined "$__agents__base__declared__providers"; then
    println "$__agents__base__declared__providers"
  else
    @obj __agents__base__declared__out
    println "$__agents__base__declared__out"
  fi
}

:<<'FUN'
Prints the manifest's block for the provider $1, empty when it declares
none for it.
FUN
__agents__base__declared_block() {
  if ! @defined "$1"; then
    @obj __agents__base__declared_block__out
    println "$__agents__base__declared_block__out"
    return 0
  fi
  @obj __agents__base__declared_block__obj_3
  @get __agents__base__declared_block__out "$(__agents__base__declared)" ".\"$1\"" "$__agents__base__declared_block__obj_3"
  println "$__agents__base__declared_block__out"
}

:<<'PUB_FUN'
Prints the run options every adaptor reads, for the provider $1 when given,
else the manifest's sole declared provider: the neutral core, and under the
provider's id its manifest block as the defaults (ADR 000004), which a caller
overrides before passing the result to the facade. The model has no default:
it depends on the task, so a caller names one per run or takes the
provider's own.

  provider        the adaptor id; empty selects through the manifest, then
                  SHELLOPS_AGENTS
  api_key         the provider's key; empty reads the adaptor's token variable
  repo            the repository URL the agent works in; empty runs without one
  ref             the branch or commit the agent starts from
  model           an explicit model id; empty takes the provider's default
  name            the agent's display name; empty derives it from the prompt
  open_review     whether the provider opens a review when a run ends
  budget_secs     how long agents__poll waits before giving up
  poll_secs       how long agents__poll sleeps between reads
  <id>            the provider's own options, per lib/agents/<id>/options.schema.json

  agents__new_run_options cursor  ->  {"provider":"cursor", ..., "cursor":{"env":{"type":"pool"}}}

Usage: agents__new_run_options [provider]
PUB_FUN
agents__new_run_options() {
  __agents__new_run_options__id="${1:-$(agents__sole_provider)}"
  @obj __agents__new_run_options__core \
    '.provider'    "$__agents__new_run_options__id" \
    '.api_key'     "" \
    '.repo'        "" \
    '.ref'         "main" \
    '.model'       "" \
    '.name'        "" \
    '.open_review' false \
    '.budget_secs' 1800 \
    '.poll_secs'   10
  if ! @defined "$__agents__new_run_options__id"; then
    println "$__agents__new_run_options__core"
    return 0
  fi
  @set __agents__new_run_options__out "$__agents__new_run_options__core" \
    ".\"$__agents__new_run_options__id\"" \
    "$(__agents__base__declared_block "$__agents__new_run_options__id")"
  println "$__agents__new_run_options__out"
}
