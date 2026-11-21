# shellcheck shell=bash

@result() {
  __shellops_interpreter__ensure_output_scope
  println "$__current_result"
}

@result.get() {
  local path="$1"
  local value kind text

  __shellops_interpreter__ensure_output_scope
  @member value "$__current_result" ".$path"
  @typeof kind "$value"
  case "$kind" in
    object | array) @to_json text "$value" ;;
    *) @get text "$__current_result" ".$path" ;;
  esac
  println "$text"
}

@in() {
  println "${__in_values[$1]}"
}

@return() {
  println "$@"
}

@return.out() {
  __shellops_interpreter__ensure_output_scope
  @return "$__current_result"
}

@throw() {
  __current_result='{}'
  printf 'ERROR: %s\n' "$*" >&2
  return 1
}

@note() {
  __reg_notes["$__cur_op"]+="$1 "
}

:<<'PUB_FUN'
Declares that the op being registered reads as an infix operator, at the
precedence $1 when the declaration names one. The registry carries the
declaration to the engine, which needs it to parse a call written in operator
position.

args:
  $1  The operator's precedence (optional)
PUB_FUN
@infix() {
  __reg_infix["$__cur_op"]=true
  if (( $# >= 1 )); then
    __reg_precedence["$__cur_op"]="$1"
  fi
}
@symbol() { __reg_symbol["$__cur_op"]="$1"; }
@remote() { :; }
@dangerous() { :; }
@imperative() { :; }
