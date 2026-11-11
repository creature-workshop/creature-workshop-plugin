#!/bin/sh
# shellcheck disable=SC2119  # bare @arr/@obj are the structs empty constructors

import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/fingerprint/probe.sh"

:<<'FRAGMENT'
Composing one report line: the state half taken from the environment as it
stands, and the fields joined into the line a report carries.
FRAGMENT

:<<'FUN'
Prints the state half of a line for the <kind> input <name>, whose reader
falls back to <default>: unset, empty, or set, taken from the environment as
it stands now.
FUN
__fingerprint__state() {
  if @is_false "$(fingerprint__var_is_set "$2")"; then
    __fingerprint__unset_state "$1" "$3"
    return 0
  fi

  __fingerprint__state__value="$(fingerprint__var_value "$2")"
  if ! @defined "$__fingerprint__state__value"; then
    printf 'empty'
    return 0
  fi

  __fingerprint__set_state "$1" "$__fingerprint__state__value"
}

:<<'FUN'
The state of each name in <names> for a <kind> declaration whose reader falls
back to <default>, as an object keyed by name. Taken now so a later bind of
that default cannot rewrite the line.
FUN
__fingerprint__snapshot() {
  @obj __fingerprint__snapshot__obj_1
  @reduce __fingerprint__snapshot__out __fingerprint__fold_snapshot "$2" "$__fingerprint__snapshot__obj_1" "$1" "$3"
  println "$__fingerprint__snapshot__out"
}

:<<'FUN'
@reduce callback: adds the state of <name> to <seen>.

  $1 the states so far
  $2 the variable name (wrapped)
  $3 the kind its declaration gave it
  $4 the value its reader falls back to
FUN
__fingerprint__fold_snapshot() {
  @unwrap __fingerprint__fold_snapshot__name "$2"

  @set __fingerprint__fold_snapshot__out "$1" \
    ".\"$__fingerprint__fold_snapshot__name\"" \
    "$(__fingerprint__state "$3" "$__fingerprint__fold_snapshot__name" "$4")"
  println "$__fingerprint__fold_snapshot__out"
}

:<<'FUN'
Prints the "unset" half of a line for a <kind> input whose reader falls back to
<default>. A default names the value the run went on to use, so an unset input
holding one is answered rather than merely absent.
FUN
__fingerprint__unset_state() {
  if [ "$1" != input ] || ! @defined "$2"; then
    printf 'unset'
    return 0
  fi

  printf 'unset default=%s' "$(fingerprint__value_shown "$2")"
}

:<<'FUN'
Prints the "set" half of a line for the non-empty <value> of a <kind> input.

Every kind carries the length, which is what says the shown value is only part
of a longer one. A secret adds what can be compared without disclosing it; an
input adds the value, there being nothing to protect.
FUN
__fingerprint__set_state() {
  if [ "$1" = input ]; then
    printf 'set len=%s value=%s' "${#2}" "$(fingerprint__value_shown "$2")"
    return 0
  fi

  __fingerprint__set_state__digest="$(fingerprint__digest "$2")"
  __fingerprint__set_state__scheme="$(fingerprint__scheme "$2")"

  printf 'set len=%s sha256=%s scheme=%s' \
    "${#2}" \
    "$__fingerprint__set_state__digest" \
    "$__fingerprint__set_state__scheme"
}

:<<'FUN'
Prints the line naming <name> in state <state>, suffixed with <marker> when one
is given. A line is its fields joined by a space, and an absent marker is not a
field.
FUN
__fingerprint__compose() {
  __fingerprint__compose__line=""
  for __fingerprint__compose__field in "$1" "$2" "$3"; do
    if [ -n "$__fingerprint__compose__field" ]; then
      __fingerprint__compose__line="${__fingerprint__compose__line:+$__fingerprint__compose__line }$__fingerprint__compose__field"
    fi
  done
  println "$__fingerprint__compose__line"
}
