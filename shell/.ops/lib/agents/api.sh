#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/agents/base.sh" \
  "$SHELLOPS_DIR/lib/fingerprint/api.sh" \
  "$SHELLOPS_DIR/lib/kinds/api.sh"

:<<'MODULE'
Agents facade, the top of the agents sandwich: a registry of provider
adaptors (ADR 000003), a selection (ADR 000004), and one agents_<op> per
contract verb that forwards to <selected>_<op>. Downstream callers never
name a provider.

  options="$(@set "$(agents__new_run_options)" '.repo' "$url")"
  started="$(agents__run "$options" "$prompt_text")"
  status="$(agents__poll "$options" "$(@get "$started" '.agent_id')" "$(@get "$started" '.run_id')")"

An adaptor is authored as an @agent.<id> structural contract in
lib/agents/<id>/<id>.agent.op.sh and found by being there: on import this
facade scans lib/agents for the kind, re-homes each contract's roles to
<id>_<op>, with a dash in the id spelled as an underscore the way every kind
does, and registers it, fingerprinting the key variable it names. Every
registered adaptor is also callable under its own name (ADR 000005): import
this facade and call <id>_<op> directly.

Selection, first source that answers wins: the options' .provider, then the
manifest's sole entry under agents.providers, then SHELLOPS_AGENTS. None of
them answering is a failure naming the declared and the registered ids,
never a guess; a manifest declaring several providers is a caller naming
one per run.
MODULE

@arr __agents__CONTRACT token_env_name run followup get_run list_agents list_runs cancel archive artifacts list_models
@arr __at1
__agents__REGISTRY="${__agents__REGISTRY:-$__at1}"
@arr __agents__TERMINAL FINISHED ERROR CANCELLED EXPIRED
__agents__NL="$(printf '\nx')"
__agents__NL="${__agents__NL%x}"

:<<'FUN'
Prints the name of the plain function that is the contract verb $2 of the
adaptor $1: the adaptor's id with dashes turned to underscores, then the
verb.

  __agents__fn cursor-cli run  ->  cursor_cli_run
FUN
__agents__fn() {
  kinds__fn "$1" "$2"
}

:<<'FUN'
Prints the contract functions the adaptor $1 does not define, comma
separated; nothing when it defines them all.
FUN
__agents__missing_contract() {
  @map __agents__missing_contract__fns __agents__missing_fn "$__agents__CONTRACT" "$1"
  @filter __agents__missing_contract__filter_2 "$__agents__missing_contract__fns" silt__text_is_not . ''
  @join __agents__missing_contract__out "$__agents__missing_contract__filter_2" ", "
  println "$__agents__missing_contract__out"
}

:<<'FUN'
Prints the function <$2>_<$1> when it is not defined, nothing when it is.
FUN
__agents__missing_fn() {
  @unwrap __agents__missing_fn__unwrap_3 "$1"
  __agents__missing_fn__fn="$(__agents__fn "$2" "$__agents__missing_fn__unwrap_3")"
  if command -v "$__agents__missing_fn__fn" >/dev/null 2>&1; then
    printf ''
  else
    printf '%s' "$__agents__missing_fn__fn"
  fi
}

:<<'PUB_FUN'
Registers the adaptor $1 so the facade can select it, and declares the
variable carrying its key as a fingerprinted secret, so a job's report shows
the key's digest and never its value. Fails naming the contract functions
the adaptor lacks.

Usage: agents__register_adaptor cursor
PUB_FUN
agents__register_adaptor() {
  __agents__register_adaptor__missing="$(__agents__missing_contract "$1")"
  if @defined "$__agents__register_adaptor__missing"; then
    error "agents__register_adaptor: adaptor '$1' missing contract function(s): $__agents__register_adaptor__missing"
    return 1
  fi
  fingerprint__secret "$("$(__agents__fn "$1" token_env_name)")"
  @wrap __agents__register_adaptor__wrap_4 "$1"
  @push __agents__REGISTRY "$__agents__REGISTRY" "$__agents__register_adaptor__wrap_4"
}

:<<'PUB_FUN'
Loads the @agent.<id> contract, whose plugin file this facade has imported,
and registers it: the interpreter re-homes its roles to <id>_<role>, once,
and the registry checks the contract. A second call is a no-op.

Usage: agents__load_adaptors
PUB_FUN
agents__load_adaptor() {
  if @is_true "$(agents__adaptor_registered "$1")"; then
    return 0
  fi
  command -v interpreter__load_agent >/dev/null 2>&1 \
    || import "$SHELLOPS_DIR/interpreter/api.sh"
  command -v "$(__agents__fn "$1" run)" >/dev/null 2>&1 \
    || interpreter__load_agent "$1" "@agent.$1" \
    || return 1
  agents__register_adaptor "$1"
}

:<<'PUB_FUN'
Scans the directory $1, lib/agents by default, for the @agent contracts,
one <id>/<id>.agent.op.sh each; imports every one and loads it by its stem,
so an adaptor is found by being there rather than named here.

Usage: agents__load_adaptors [dir]
PUB_FUN
# shellcheck disable=SC2120  # the directory is optional; the tail below passes none
agents__load_adaptors() {
  __agents__load_adaptors__dir="${1:-$SHELLOPS_DIR/lib/agents}"
  for __agents__load_adaptors__file in "$__agents__load_adaptors__dir"/*/*.agent.op.sh; do
    [ -f "$__agents__load_adaptors__file" ] || continue
    import "$__agents__load_adaptors__file" || return 1
    __agents__load_adaptors__id="${__agents__load_adaptors__file##*/}"
    agents__load_adaptor "${__agents__load_adaptors__id%.agent.op.sh}" || return 1
  done
}

:<<'PUB_FUN'
Prints the registered adaptor ids, as an array.
PUB_FUN
agents__adaptor_ids() {
  @unique __agents__adaptor_ids__out "$__agents__REGISTRY"
  println "$__agents__adaptor_ids__out"
}

:<<'PUB_FUN'
Prints true when the adaptor $1 is registered, false otherwise.
PUB_FUN
agents__adaptor_registered() {
  @join __agents__adaptor_registered__out "$(agents__adaptor_ids)" "$__agents__NL"
  println "$__agents__adaptor_registered__out" | { @succeeds __agents__adaptor_registered__out grep -qxF -- "$1"; println "$__agents__adaptor_registered__out"; }
}

:<<'PUB_FUN'
Prints the id the run options $1 select: the options' provider, else the
manifest's sole declared provider, else SHELLOPS_AGENTS. Fails when none
answers or the answer is not a registered adaptor.

Usage: agents__selected "$options"
PUB_FUN
agents__selected() {
  @option __agents__selected__id "$1" 'provider' ''
  if ! @defined "$__agents__selected__id"; then
    __agents__selected__id="$(agents__sole_provider)"
  fi
  if ! @defined "$__agents__selected__id"; then
    __agents__selected__id="${SHELLOPS_AGENTS:-}"
  fi
  if ! @defined "$__agents__selected__id"; then
    @join __agents__selected__join_5 "$(agents__declared_providers)" ', '
    @join __agents__selected__join_6 "$(agents__adaptor_ids)" ', '
    error "agents: no provider selected; pass one in the options, declare exactly one under agents.providers in manifest.json, or set SHELLOPS_AGENTS (declared: $__agents__selected__join_5; registered: $__agents__selected__join_6)"
    return 1
  fi
  if ! @is_true "$(agents__adaptor_registered "$__agents__selected__id")"; then
    @join __agents__selected__join_7 "$(agents__adaptor_ids)" ', '
    error "agents: provider '$__agents__selected__id' is not registered (registered: $__agents__selected__join_7)"
    return 1
  fi
  println "$__agents__selected__id"
}

:<<'PUB_FUN'
Prints the run options $1 with .api_key filled from the selected adaptor's
token variable when the caller left it empty. Fails naming the variable
when neither carries a key.

Usage: options="$(agents__with_key "$options")"
PUB_FUN
agents__with_key() {
  __agents__with_key__id="$(agents__selected "$1")" || return 1
  @option __agents__with_key__key "$1" 'api_key' ''
  if @defined "$__agents__with_key__key"; then
    println "$1"
    return 0
  fi
  __agents__with_key__var="$("$(__agents__fn "$__agents__with_key__id" token_env_name)")"
  eval "__agents__with_key__key=\"\${${__agents__with_key__var}:-}\""
  if ! @defined "$__agents__with_key__key"; then
    error "agents: no key for provider '$__agents__with_key__id'; set $__agents__with_key__var"
    return 1
  fi
  @set __agents__with_key__out "$1" '.api_key' "$__agents__with_key__key"
  println "$__agents__with_key__out"
}

:<<'PUB_FUN'
Prints the run options $1 with the key $2 set to $3 inside the selected
provider's own block, so a caller can set a provider option without naming
the provider. Fails as agents__selected does.

  agents__set_provider_option "$options" '.env.type' pool  ->  {..., "cursor":{"env":{"type":"pool"}}}
PUB_FUN
agents__set_provider_option() {
  __agents__set_provider_option__id="$(agents__selected "$1")" || return 1
  @set __agents__set_provider_option__out "$1" ".\"$__agents__set_provider_option__id\"$2" "$3"
  println "$__agents__set_provider_option__out"
}

:<<'FUN'
Dispatches the contract verb $1 on the adaptor the options $2 select, with
the options and every following argument.
FUN
__agents__dispatch() {
  __agents__dispatch__verb="$1"
  shift
  __agents__dispatch__id="$(agents__selected "$1")" || return 1
  "$(__agents__fn "$__agents__dispatch__id" "$__agents__dispatch__verb")" "$@"
}

agents__token_env_name() { __agents__dispatch token_env_name "$@"; }
agents__run()            { __agents__dispatch run "$@"; }
agents__followup()       { __agents__dispatch followup "$@"; }
agents__get_run()        { __agents__dispatch get_run "$@"; }
agents__list_agents()    { __agents__dispatch list_agents "$@"; }
agents__list_runs()      { __agents__dispatch list_runs "$@"; }
agents__cancel()         { __agents__dispatch cancel "$@"; }
agents__archive()        { __agents__dispatch archive "$@"; }
agents__artifacts()      { __agents__dispatch artifacts "$@"; }
agents__list_models()    { __agents__dispatch list_models "$@"; }

:<<'PUB_FUN'
Prints true when the run status $1 is one a run never leaves, false while
the run is still going.
PUB_FUN
agents__run_is_terminal() {
  @join __agents__run_is_terminal__out "$__agents__TERMINAL" "$__agents__NL"
  println "$__agents__run_is_terminal__out" | { @succeeds __agents__run_is_terminal__out grep -qxF -- "$1"; println "$__agents__run_is_terminal__out"; }
}

:<<'PUB_FUN'
Reads the run $3 on the agent $2 until it reaches a terminal status, sleeping
the options' poll_secs between reads, and prints that status. Gives up after
the options' budget_secs and fails; the run itself is left to the caller,
who may cancel it.

Usage: status="$(agents__poll "$options" "$agent_id" "$run_id")"
PUB_FUN
agents__poll() {
  @option __agents__poll__budget "$1" 'budget_secs' 1800
  @option __agents__poll__interval "$1" 'poll_secs' 10
  __agents__poll__deadline=$(( $(date +%s) + __agents__poll__budget ))
  while :; do
    __agents__poll__run="$(agents__get_run "$1" "$2" "$3")" || return 1
    @get __agents__poll__status "$__agents__poll__run" '.status' ''
    if @is_true "$(agents__run_is_terminal "$__agents__poll__status")"; then
      println "$__agents__poll__status"
      return 0
    fi
    if [ "$(date +%s)" -ge "$__agents__poll__deadline" ]; then
      error "agents: run $3 on $2 still $__agents__poll__status after the budget of ${__agents__poll__budget}s"
      return 1
    fi
    log "agents: run $3 on $2 is $__agents__poll__status"
    sleep "$__agents__poll__interval"
  done
}

:<<'PUB_FUN'
Prints the final reply of the run $3 on the agent $2, nothing while it has
none.
PUB_FUN
agents__result() {
  __agents__result__run="$(agents__get_run "$1" "$2" "$3")" || return 1
  @get __agents__result__out "$__agents__result__run" '.result' ''
  println "$__agents__result__out"
}

:<<'PUB_FUN'
Prints the URLs of the reviews the agent $2 opened on the run $3, as an
array; empty when it opened none.
PUB_FUN
agents__review_urls() {
  __agents__review_urls__run="$(agents__get_run "$1" "$2" "$3")" || return 1
  @arr __agents__review_urls__arr_8
  @get __agents__review_urls__out "$__agents__review_urls__run" '.reviews' "$__agents__review_urls__arr_8"
  println "$__agents__review_urls__out"
}

# shellcheck disable=SC2119
agents__load_adaptors
