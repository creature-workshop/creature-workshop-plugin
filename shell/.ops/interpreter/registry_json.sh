# shellcheck shell=bash

interpreter__dump_registry() {
  local op
  local type_name

  printf '=== Operations ===\n'
  for op in $(println "${!__reg_contracts[@]}" | sort); do
    [[ "$op" == type:* ]] && continue
    printf '  %s\n' "$op"
    [[ -n "${__reg_inputs[$op]:-}" ]] && printf '    inputs:    %s\n' "${__reg_inputs[$op]}"
    [[ -n "${__reg_outputs[$op]:-}" ]] && printf '    outputs:   %s\n' "${__reg_outputs[$op]}"
    [[ -n "${__reg_notes[$op]:-}" ]] && printf '    notes:     %s\n' "${__reg_notes[$op]}"
    printf '    contracts: [%s]\n' "${__reg_contracts[$op]}"
  done

  printf '\n=== Global primitives (bare name) ===\n'
  for type_name in $(println "${!__reg_builtin_types[@]}" | sort); do
    printf '  %s\n' "$type_name"
  done

  printf '\n=== Module types (path-derived FQN) ===\n'
  for type_name in $(println "${!__type_validators[@]}" | sort); do
    [[ -n "${__reg_builtin_types[$type_name]:-}" ]] && continue
    printf '  %s\n' "$type_name"
    [[ -n "${__type_defaults[$type_name]:-}" ]] && printf '    has default\n'
  done
}

:<<'FUN'
Prints the JSON descriptor a registry entry carries for one field, given the
type spec an @in or @out declaration wrote.

  string        ->  {"type":"string"}
  string[]      ->  {"type":"string","array":true}
  cloud.dc[]?   ->  {"type":"cloud.dc","array":true,"optional":true}
FUN
__shellops_interpreter__field_descriptor_json() {
  local spec="$1"
  local base="$spec"
  local array=false
  local optional=false

  case "$spec" in
    *'[]?') base="${spec%'[]?'}"; array=true; optional=true ;;
    *'[]')  base="${spec%'[]'}";  array=true ;;
    *'?')   base="${spec%'?'}";   optional=true ;;
  esac

  local type descriptor
  @encode_string type "$base"
  @obj descriptor '.type' "$type"
  if [[ "$array" == true ]]; then
    @set descriptor "$descriptor" '.array' true
  fi
  if [[ "$optional" == true ]]; then
    @set descriptor "$descriptor" '.optional' true
  fi

  @to_json descriptor "$descriptor"
  println "$descriptor"
}

:<<'FUN'
Prints the JSON object a registry entry carries for an op's params or returns,
given the "name=spec name=spec " string the registry stored for them. An op
that declared none gets {}.

  "path=string depth=int?"
    ->  {"path":{"type":"string"},"depth":{"type":"int","optional":true}}
FUN
__shellops_interpreter__fields_object_json() {
  local defs="$1"
  local acc='{}'
  local pairs=()
  local pair name spec desc

  [[ -n "$defs" ]] && read -ra pairs <<< "$defs"
  for pair in ${pairs[@]+"${pairs[@]}"}; do
    name="${pair%%=*}"
    spec="${pair#*=}"
    desc=$(__shellops_interpreter__field_descriptor_json "$spec")
    @set acc "$acc" ".\"$name\"" "$desc"
  done

  @to_json acc "$acc"
  printf '%s' "$acc"
}

:<<'FUN'
Prints the JSON object a registry entry carries for the contract roles an op
bound, given the space-separated role names the registry stored. A role's
hyphens become underscores so the key is a plain identifier.

  "do is-done "  ->  {"do":true,"is_done":true}
FUN
__shellops_interpreter__contract_object_json() {
  local defs="$1"
  local acc='{}'
  local names=()
  local name key

  [[ -n "$defs" ]] && read -ra names <<< "$defs"
  for name in ${names[@]+"${names[@]}"}; do
    key="${name//-/_}"
    @set acc "$acc" ".\"$key\"" true
  done

  @to_json acc "$acc"
  printf '%s' "$acc"
}

:<<'FUN'
Prints the registry entry $2 carrying whatever the op $1 declared about its use
as an operator: its infix flag, the precedence that flag may name, and its
symbol. An op that declared none of them comes back unchanged.

args:
  $1  The op's registry FQN (e.g. git.current-branch)
  $2  The op's registry entry so far ({params, returns, contract})
FUN
__shellops_interpreter__op_entry_with_operator_meta() {
  local op="$1"
  local entry="$2"

  local symbol

  if [[ "${__reg_infix[$op]:-}" == true ]]; then
    @set entry "$entry" '.infix' true
    if [[ -n "${__reg_precedence[$op]:-}" ]]; then
      @set entry "$entry" '.precedence' "${__reg_precedence[$op]}"
    fi
  fi

  if [[ -n "${__reg_symbol[$op]:-}" ]]; then
    @encode_string symbol "${__reg_symbol[$op]}"
    @set entry "$entry" '.symbol' "$symbol"
  fi

  @to_json entry "$entry"
  printf '%s' "$entry"
}

:<<'PUB_FUN'
Emit the full registry as JSON: {ops, primitives, types}. Derived entirely
from the in-memory registry that load_ops/interpreter__load_type populate;
the same registry interpreter__dump_registry prints, but as the
machine-readable JSON the engine reads via --registry. It is the source of
the committed basic fixture (test/fixtures/engine/); see
planning/docs/registry.md for the contract. No hand-editing: regenerate
fixtures from this output.
PUB_FUN
interpreter__dump_registry_json() {
  local op type_name
  local ops='{}'
  local entry

  for op in $(println "${!__reg_contracts[@]}" | sort); do
    [[ "$op" == type:* ]] && continue

    @obj entry \
      '.params' "$(__shellops_interpreter__fields_object_json "${__reg_inputs[$op]:-}")" \
      '.returns' "$(__shellops_interpreter__fields_object_json "${__reg_outputs[$op]:-}")" \
      '.contract' "$(__shellops_interpreter__contract_object_json "${__reg_contracts[$op]:-}")"
    entry=$(__shellops_interpreter__op_entry_with_operator_meta "$op" "$entry")

    @set ops "$ops" ".\"$op\"" "$entry"
  done

  local primitives
  @split primitives "$(println "${!__reg_builtin_types[@]}" | sort)"

  local types='{}'
  local with_default without_default
  @obj with_default '.default' true
  @obj without_default
  for type_name in $(println "${!__type_validators[@]}" | sort); do
    [[ -n "${__reg_builtin_types[$type_name]:-}" ]] && continue
    if [[ -n "${__type_defaults[$type_name]:-}" ]]; then
      @set types "$types" ".\"$type_name\"" "$with_default"
    else
      @set types "$types" ".\"$type_name\"" "$without_default"
    fi
  done

  local registry text
  @obj registry '.ops' "$ops" '.primitives' "$primitives" '.types' "$types"
  @dump text "$registry"
  println "$text"
}
