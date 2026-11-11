# shellcheck shell=bash

# --- Type registration ---

__shellops_interpreter__type_register() {
  local name="$1"
  local is_fn="$2"
  local default_fn="${3:-}"

  __type_validators["$name"]="$is_fn"
  __type_defaults["$name"]="$default_fn"

  eval "@${name}() {
    if (( \$# == 0 )); then
      if [[ -n \"$default_fn\" ]]; then
        $default_fn
        return \$?
      fi

      @throw \"type ${name} has no default\"
      return 1
    fi

    $is_fn \"\$@\"
  }"

  eval "@${name}.is() {
    $is_fn \"\$1\" >/dev/null
  }"

  __shellops_interpreter__register_typed_helpers "$name"
}

__shellops_interpreter__ensure_output_scope() {
  if [[ "$__result_owner_subshell" != "$BASH_SUBSHELL" ]]; then
    __current_result='{}'
    __result_owner_subshell="$BASH_SUBSHELL"
  fi
}

__shellops_interpreter__parse_type_call() {
  local full_name="$1"

  __typed_verb=""
  __typed_spec=""
  __typed_base=""
  __typed_is_array=false
  __typed_is_optional=false

  case "$full_name" in
    @in.*)
      __typed_verb="@in"
      __typed_spec="${full_name#@in.}"
      ;;
    @out.*)
      __typed_verb="@out"
      __typed_spec="${full_name#@out.}"
      ;;
    *)
      return 1
      ;;
  esac

  __typed_base="$__typed_spec"
  if [[ "$__typed_base" == *'[]?' ]]; then
    __typed_base="${__typed_base%'[]?'}"
    __typed_is_array=true
    __typed_is_optional=true
  elif [[ "$__typed_base" == *'[]' ]]; then
    __typed_base="${__typed_base%'[]'}"
    __typed_is_array=true
  elif [[ "$__typed_base" == *'?' ]]; then
    __typed_base="${__typed_base%?}"
    __typed_is_optional=true
  fi
}

__shellops_interpreter__register_input() {
  local field_name="$1"

  __reg_inputs["$__cur_op"]+="${field_name}=${__typed_spec} "
}

__shellops_interpreter__register_output() {
  local field_name="$1"

  __reg_outputs["$__cur_op"]+="${field_name}=${__typed_spec} "
}

__shellops_interpreter__call_type() {
  local type_name="$1"
  local fn_name="@${type_name}"

  if ! declare -F "$fn_name" >/dev/null; then
    @throw "unknown type ${type_name}"
    return 1
  fi

  "$fn_name" "${@:2}"
}

__shellops_interpreter__json_array() {
  local first=true
  local item
  local json="["

  for item in "$@"; do
    $first && first=false || json+=","
    json+="$item"
  done
  json+="]"

  println "$json"
}

:<<'FUN'
Prints the JSON for one value of the type the @in/@out declaration in flight
names, built by that type's own constructor. The object type is the exception
and goes through @object.

args:
  $1  The value to construct
FUN
__shellops_interpreter__typed_value_one() {
  if [[ "$__typed_base" == "object" ]]; then
    @object "$1"
    return $?
  fi

  __shellops_interpreter__call_type "$__typed_base" "$1"
}

:<<'FUN'
Prints the JSON array an @out.<type>[] declaration answers with, every argument
constructed as that type. An op that returned nothing for the field gets [], or
null where the declaration marked the field optional.

args:
  $@  The values the op returned for the field
FUN
__shellops_interpreter__json_array_for_out() {
  if (( $# == 0 )); then
    [[ "$__typed_is_optional" == true ]] && { println 'null'; return 0; }
    println '[]'
    return 0
  fi

  local values=()
  local arg value
  for arg in "$@"; do
    value=$(__shellops_interpreter__typed_value_one "$arg") || return 1
    values+=("$value")
  done

  __shellops_interpreter__json_array "${values[@]}"
}

:<<'FUN'
Prints the JSON a scalar @out.<type> declaration answers with, constructed as
that type. An op that returned nothing for the field gets the type's own
default, or null where the declaration marked the field optional.

args:
  $1  The value the op returned for the field, if it returned one
FUN
__shellops_interpreter__json_scalar_for_out() {
  if (( $# == 0 )); then
    [[ "$__typed_is_optional" == true ]] && { println 'null'; return 0; }
    __shellops_interpreter__call_type "$__typed_base"
    return $?
  fi

  __shellops_interpreter__typed_value_one "$1"
}

:<<'FUN'
Prints the JSON the @out.<type> declaration in flight answers with, whether its
spec asked for an array or for a scalar.

args:
  $@  The values the op returned for the field
FUN
__shellops_interpreter__json_value_for_out() {
  if [[ "$__typed_is_array" == true ]]; then
    __shellops_interpreter__json_array_for_out "$@"
    return $?
  fi

  __shellops_interpreter__json_scalar_for_out "$@"
}

:<<'FUN'
Puts the JSON value $2 in the result under the field $1, a name whose dots
part the keys of a nested field.

  __shellops_interpreter__set_output_field repo.name '"shellops"'
    ->  the result holds {"repo":{"name":"shellops"}}
FUN
__shellops_interpreter__set_output_field() {
  local field_name="$1"
  local field_value="$2"
  local path=".\"${field_name//./\".\"}\""
  local updated

  __shellops_interpreter__ensure_output_scope
  @set updated "$__current_result" "$path" "$field_value" || return 1
  @to_json __current_result "$updated" || return 1
}

__shellops_interpreter__handle_typed_call() {
  local full_name="$1"
  shift

  __shellops_interpreter__parse_type_call "$full_name" || return 1

  if [[ "$__typed_verb" == "@in" ]]; then
    [[ "$__phase" == "register" ]] || {
      @throw "${full_name} is only valid during load-time input declaration"
      return 1
    }

    __shellops_interpreter__register_input "$1"
    return 0
  fi

  if [[ "$__phase" == "register" ]]; then
    __shellops_interpreter__register_output "$1"
    return 0
  fi

  local field_name="$1"
  local field_value
  shift

  field_value=$(__shellops_interpreter__json_value_for_out "$@") || return 1
  __shellops_interpreter__set_output_field "$field_name" "$field_value"
}

__shellops_interpreter__register_typed_helpers() {
  local type_name="$1"
  local spec

  for spec in "$type_name" "${type_name}?" "${type_name}[]" "${type_name}[]?"; do
    eval "@in.${spec}() { __shellops_interpreter__handle_typed_call '@in.${spec}' \"\$@\"; }"
    eval "@out.${spec}() { __shellops_interpreter__handle_typed_call '@out.${spec}' \"\$@\"; }"
  done
}

interpreter__command_not_found_handle() {
  local full_name="$1"
  shift

  __shellops_interpreter__parse_type_call "$full_name" || {
    printf '%s: command not found\n' "$full_name" >&2
    return 127
  }

  __shellops_interpreter__handle_typed_call "$full_name" "$@"
}
