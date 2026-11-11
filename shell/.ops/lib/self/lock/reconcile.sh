#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
Settling a declared list against what remote systems hold, and printing
the result as a section of the lock. A caller hands over a context: the
list, the section as the lock records it, the field of an item that keys
the section, whether to apply or only announce, the system to call with
and the field of an item that may name another, and the functions that
speak to a system. Each item is found by the id its declaration names or
the section records for it on the same system; one that is not found is
created, one that drifted is updated, and the rest are left as they are.
An item moved to another system is created there, and what the old system
holds is left as it is and said so. The settled section is printed, and
the caller writes it. Without apply every step is announced and the
systems are only read.

The functions, named under callbacks, are each called with the item's
system first:

  input   <with> <declared>          what the system takes for the item
  read    <with> <id>                the item as the system holds it
  drift   <with> <existing> <input>  true when the two differ
  create  <with> <input>             makes the item and prints its entry
  update  <with> <id> <input>        changes the item and prints its entry
  entry   <with> <existing>          the entry the section keeps for it

An entry holds at least id, by which the item is found again, and the
system the item is on, under the field the context names. A function that
fails stops the walk, and the walk fails.

  self__lock__reconcile__section "$context"
    ->  {"docs@example.com":{"id":"3a1c...","address":"2371...@intake.linear.app","system":"linear"}}
FRAGMENT

# VAR: The context of the walk in progress, read by every step.
__self__lock__reconcile__CONTEXT=""

# VAR: The section as settled so far, which each step adds its entry to.
__self__lock__reconcile__RECORDED=""

# VAR: The system the item being settled is on, which every call goes to.
__self__lock__reconcile__WITH=""

: <<'PUB_FUN'
Settles every item of the context's declared list and prints the section
with an entry for each, keyed by the item's key field. Fails when a
function the context names fails.

args:
  $1  The context: {section, key, declared, recorded, apply, with, with_field, callbacks}
      section     The section's name, which prefixes every announcement
      key         The field of a declared item that keys the section
      declared    The declared items, as a struct array
      recorded    The section as the lock records it
      apply       true to make the changes, false to announce them
      with        The system an item is on when it names none
      with_field  The field of an item that names its system, and the
                  field of its entry that records it
      callbacks   {input, read, drift, create, update, entry}: function names
PUB_FUN
self__lock__reconcile__section() {
  __self__lock__reconcile__CONTEXT="$1"
  @obj __self__lock__reconcile__section__obj_1
  @get __self__lock__reconcile__RECORDED "$1" '.recorded' "$__self__lock__reconcile__section__obj_1"
  @arr __self__lock__reconcile__section__arr_2
  @get __self__lock__reconcile__section__get_3 "$1" '.declared' "$__self__lock__reconcile__section__arr_2"
  @foreach __self__lock__reconcile__item "$__self__lock__reconcile__section__get_3" || return 1
  println "$__self__lock__reconcile__RECORDED"
}

: <<'FUN'
@foreach callback: settles one declared item and sets its entry in the
section being built.

args:
  $1  The declared item
FUN
__self__lock__reconcile__item() {
  @get __self__lock__reconcile__item__key "$__self__lock__reconcile__CONTEXT" '.key'
  @get __self__lock__reconcile__item__name "$1" ".$__self__lock__reconcile__item__key"
  __self__lock__reconcile__WITH="$(__self__lock__reconcile__system_of "$1")"
  __self__lock__reconcile__item__input="$(__self__lock__reconcile__call input "$1")" || return 1
  __self__lock__reconcile__item__id="$(__self__lock__reconcile__known_id "$1" "$__self__lock__reconcile__item__name")"
  if @defined "$__self__lock__reconcile__item__id"; then
    __self__lock__reconcile__item__entry="$(__self__lock__reconcile__settle_known "$__self__lock__reconcile__item__id" "$__self__lock__reconcile__item__input" "$__self__lock__reconcile__item__name")" || return 1
  else
    __self__lock__reconcile__item__entry="$(__self__lock__reconcile__settle_unknown "$__self__lock__reconcile__item__input" "$__self__lock__reconcile__item__name")" || return 1
  fi
  __self__lock__reconcile__item__entry="$(__self__lock__reconcile__on_system "$__self__lock__reconcile__item__entry")"
  @set __self__lock__reconcile__RECORDED "$__self__lock__reconcile__RECORDED" ".\"$__self__lock__reconcile__item__name\"" "$__self__lock__reconcile__item__entry"
}

: <<'FUN'
Prints the system the declared item is on: the one it names under the
context's with_field, else the context's with.

args:
  $1  The declared item
FUN
__self__lock__reconcile__system_of() {
  @get __self__lock__reconcile__system_of__field "$__self__lock__reconcile__CONTEXT" '.with_field' ''
  @get __self__lock__reconcile__system_of__default "$__self__lock__reconcile__CONTEXT" '.with' ''
  if ! @defined "$__self__lock__reconcile__system_of__field"; then
    println "$__self__lock__reconcile__system_of__default"
    return 0
  fi
  @get __self__lock__reconcile__system_of__out "$1" ".$__self__lock__reconcile__system_of__field" "$__self__lock__reconcile__system_of__default"
  println "$__self__lock__reconcile__system_of__out"
}

: <<'FUN'
Prints the entry with the system the item is on set under the context's
with_field, or the entry as it is when the context names no such field.

args:
  $1  The entry
FUN
__self__lock__reconcile__on_system() {
  @get __self__lock__reconcile__on_system__field "$__self__lock__reconcile__CONTEXT" '.with_field' ''
  if ! @defined "$__self__lock__reconcile__on_system__field"; then
    println "$1"
    return 0
  fi
  @set __self__lock__reconcile__on_system__out "$1" ".$__self__lock__reconcile__on_system__field" "$__self__lock__reconcile__WITH"
  println "$__self__lock__reconcile__on_system__out"
}

: <<'FUN'
Calls the function the context names for <role> with the context's with
value and the arguments after the role.

args:
  $1  The role: input, read, drift, create, update or entry
  $@  The arguments after it
FUN
__self__lock__reconcile__call() {
  @get __self__lock__reconcile__call__fn "$__self__lock__reconcile__CONTEXT" ".callbacks.$1"
  shift
  "$__self__lock__reconcile__call__fn" "$__self__lock__reconcile__WITH" "$@"
}

: <<'FUN'
Prints the id by which the declared item is found: the one its declaration
names, else the one the section records under its name when that entry is
on the same system, else nothing. An entry on another system is said to be
left there.

args:
  $1  The declared item
  $2  The item's name, its value of the key field
FUN
__self__lock__reconcile__known_id() {
  @get __self__lock__reconcile__known_id__declared "$1" '.id' ''
  if @defined "$__self__lock__reconcile__known_id__declared"; then
    println "$__self__lock__reconcile__known_id__declared"
    return 0
  fi
  @get __self__lock__reconcile__known_id__recorded "$__self__lock__reconcile__RECORDED" ".\"$2\"" ''
  if ! @defined "$__self__lock__reconcile__known_id__recorded"; then
    return 0
  fi
  __self__lock__reconcile__known_id__was_on="$(__self__lock__reconcile__recorded_system "$__self__lock__reconcile__known_id__recorded")"
  if [ "$__self__lock__reconcile__known_id__was_on" != "$__self__lock__reconcile__WITH" ]; then
    __self__lock__reconcile__announce "$2" "left on $__self__lock__reconcile__known_id__was_on"
    return 0
  fi
  @get __self__lock__reconcile__known_id__out "$__self__lock__reconcile__known_id__recorded" '.id' ''
  println "$__self__lock__reconcile__known_id__out"
}

: <<'FUN'
Prints the system a recorded entry is on: its value under the context's
with_field, or the system of the walk when the context names no such
field, so that an entry recorded before systems were kept counts as the
current one.

args:
  $1  The recorded entry
FUN
__self__lock__reconcile__recorded_system() {
  @get __self__lock__reconcile__recorded_system__field "$__self__lock__reconcile__CONTEXT" '.with_field' ''
  if ! @defined "$__self__lock__reconcile__recorded_system__field"; then
    println "$__self__lock__reconcile__WITH"
    return 0
  fi
  @get __self__lock__reconcile__recorded_system__out "$1" ".$__self__lock__reconcile__recorded_system__field" "$__self__lock__reconcile__WITH"
  println "$__self__lock__reconcile__recorded_system__out"
}

: <<'FUN'
Reads the item with <id> and prints its entry, updating it first when it
drifted from <input> and the context applies.

args:
  $1  The item's id
  $2  The input, as the input function printed it
  $3  The item's name, for the announcement
FUN
__self__lock__reconcile__settle_known() {
  __self__lock__reconcile__settle_known__existing="$(__self__lock__reconcile__call read "$1")" || return 1
  __self__lock__reconcile__settle_known__drift="$(__self__lock__reconcile__call drift "$__self__lock__reconcile__settle_known__existing" "$2")" || return 1
  if ! @is_true "$__self__lock__reconcile__settle_known__drift"; then
    __self__lock__reconcile__announce "$3" "unchanged"
    __self__lock__reconcile__call entry "$__self__lock__reconcile__settle_known__existing"
    return 0
  fi
  if @is_true "$(__self__lock__reconcile__applying)"; then
    __self__lock__reconcile__announce "$3" "updated"
    __self__lock__reconcile__call update "$1" "$2"
  else
    __self__lock__reconcile__announce "$3" "would be updated"
    __self__lock__reconcile__call entry "$__self__lock__reconcile__settle_known__existing"
  fi
}

: <<'FUN'
Creates the item from <input> when the context applies and prints its
entry; otherwise announces the create and prints an entry with no id.

args:
  $1  The input, as the input function printed it
  $2  The item's name, for the announcement
FUN
__self__lock__reconcile__settle_unknown() {
  if @is_true "$(__self__lock__reconcile__applying)"; then
    __self__lock__reconcile__announce "$2" "created"
    __self__lock__reconcile__call create "$1"
  else
    __self__lock__reconcile__announce "$2" "would be created"
    @obj __self__lock__reconcile__settle_unknown__out '.id' ""
    println "$__self__lock__reconcile__settle_unknown__out"
  fi
}

: <<'FUN'
Prints true when the context applies its changes, false when it only
announces them.
FUN
__self__lock__reconcile__applying() {
  @get __self__lock__reconcile__applying__out "$__self__lock__reconcile__CONTEXT" '.apply' false
  println "$__self__lock__reconcile__applying__out"
}

: <<'FUN'
Logs one step: the section, the item's name and what happened to it.

args:
  $1  The item's name
  $2  What happened: created, updated, unchanged, or the would-be forms
FUN
__self__lock__reconcile__announce() {
  @get __self__lock__reconcile__announce__get_4 "$__self__lock__reconcile__CONTEXT" '.section'
  log "$__self__lock__reconcile__announce__get_4: $1: $2 on $__self__lock__reconcile__WITH."
}
