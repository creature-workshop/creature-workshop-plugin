# shellcheck shell=bash

interpreter__dispatch() {
  local op="$1"
  local contract="$2"
  local fn
  local i=1
  local input_defs
  local pair
  local input_name

  shift 2

  fn="${__dispatch["${op}.${contract}"]}"
  if [[ -z "$fn" ]]; then
    printf 'no dispatch for %s.%s\n' "$op" "$contract" >&2
    return 1
  fi

  __phase="dispatch"
  __current_result='{}'
  __result_owner_subshell="$BASH_SUBSHELL"
  __in_values=()
  input_defs="${__reg_inputs[$op]:-}"

  for pair in $input_defs; do
    input_name="${pair%%=*}"
    __in_values["$input_name"]="${!i:-}"
    (( i++ ))
  done

  "$fn" "$@"
  local exit_code=$?
  __phase=""
  return $exit_code
}
