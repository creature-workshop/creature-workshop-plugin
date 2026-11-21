#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
The file tracker's work: a plan kept in a YAML file under the repository,
for a project with no tracker, and the plan every reader of the kind can be
tried against. The scope's key is the file's path relative to $PROJ.

The file keeps a prefix, the key new tickets take, its states, each named
and of one of the kind's types, its milestones in order, and its
tickets, each with its key, title, state, estimate, priority, assignee,
milestone id, lane and the keys that block it:

  prefix: PLAN
  states:
    - {name: Open, type: todo}
    - {name: Shipped, type: done}
  milestones:
    - {id: ship, name: Ship, target: 2026-11-06}
  tickets:
    - {key: PLAN-1, title: Build it, state: Open, estimate: 2, milestone: ship}
    - {key: PLAN-2, title: Demo it, state: Open, milestone: ship, blocked_by: [PLAN-1]}

A file that declares no states has the kind's default states, the six
types named for themselves. A ticket with no state is in the file's first
state of type todo, or its first state when none is of that type.

Every write rewrites the whole file. The awk programs beside this file do
the reading and the rewriting; the shell checks a key and a state before it
runs one, so a failure names what was wrong.
FRAGMENT

# CONST: The directory of this module's awk programs.
__tracker__file__DIR="$SHELLOPS_DIR/lib/tracker"

: <<'FUN'
Prints the path of the plan file the scope <scope> names, under $PROJ.
FUN
__tracker__file__path() {
  @get __tracker__file__path__get_1 "$1" '.key'
  println "$PROJ/$__tracker__file__path__get_1"
}

: <<'FUN'
Prints the plan file of <scope> as a struct, and an empty mapping when the
file does not exist yet.
FUN
__tracker__file__document() {
  __tracker__file__document__path="$(__tracker__file__path "$1")"
  if [ -f "$__tracker__file__document__path" ]; then
    @from_yaml __tracker__file__document__out "$(cat "$__tracker__file__document__path")"
    println "$__tracker__file__document__out"
  else
    @obj __tracker__file__document__out
    println "$__tracker__file__document__out"
  fi
}

: <<'FUN'
Rewrites the plan file of <scope> from the struct <document>, creating its
directory when it is new.
FUN
__tracker__file__write() {
  __tracker__file__write__path="$(__tracker__file__path "$1")"
  mkdir -p "$(dirname "$__tracker__file__write__path")"
  @to_yaml __tracker__file__write__out "$2"
  println "$__tracker__file__write__out" > "$__tracker__file__write__path"
}

: <<'PUB_FUN'
Implements @states: prints the states the file of <scope> declares, or the
kind's default states when it declares none.
PUB_FUN
tracker__file__states() {
  @arr __tracker__file__states__arr_2
  @get __tracker__file__states__declared "$(__tracker__file__document "$1")" '.states' "$__tracker__file__states__arr_2"
  if @empty "$__tracker__file__states__declared"; then
    tracker__default_states
    return 0
  fi

  @map __tracker__file__states__out __tracker__file__state "$__tracker__file__states__declared"
  println "$__tracker__file__states__out"
}

: <<'FUN'
Prints the state the declared entry <entry> names, its name and type as
strings; the callback @map runs over the file's states.
FUN
__tracker__file__state() {
  @get __tracker__file__state__get_3 "$1" '.name'
  @get __tracker__file__state__get_4 "$1" '.type'
  tracker__new_state "$__tracker__file__state__get_3" "$__tracker__file__state__get_4"
}

: <<'FUN'
Prints the state a ticket of <scope> is in when it names none: the file's
first state of type todo, or its first state when none is of that type.
FUN
__tracker__file__default_state() {
  __tracker__file__default_state__states="$(tracker__file__states "$1")"
  @filter __tracker__file__default_state__todo "$__tracker__file__default_state__states" silt__text_is .type todo
  if @empty "$__tracker__file__default_state__todo"; then
    @first __tracker__file__default_state__out "$__tracker__file__default_state__states"
    println "$__tracker__file__default_state__out"
    return 0
  fi

  @first __tracker__file__default_state__out "$__tracker__file__default_state__todo"
  println "$__tracker__file__default_state__out"
}

: <<'FUN'
Fails, naming the states the file of <scope> has, when <name> is none of
them; the name is otherwise accepted silently.
FUN
__tracker__file__require_state() {
  tracker__state_named "$(tracker__file__states "$1")" "$2" > /dev/null
}

: <<'FUN'
Prints the ticket <key> of the plan <plan>, failing, naming the key, when
the plan has none.
FUN
__tracker__file__ticket() {
  @get __tracker__file__ticket__get_5 "$1" '.tickets'
  @filter __tracker__file__ticket__found "$__tracker__file__ticket__get_5" silt__text_is .key "$2"
  if @empty "$__tracker__file__ticket__found"; then
    error "no ticket $2 in the plan"
    return 1
  fi

  @first __tracker__file__ticket__out "$__tracker__file__ticket__found"
  println "$__tracker__file__ticket__out"
}

: <<'PUB_FUN'
Implements @plan: prints the plan the file of <scope> keeps.
PUB_FUN
tracker__file__plan() {
  @run_awk __tracker__file__plan__out \
    "$__tracker__file__DIR/file_plan.awk" \
    "$(__tracker__file__document "$1")" \
    --with "$1" \
    --with "$(tracker__file__states "$1")" \
    --with "$(__tracker__file__default_state "$1")" \
    || return 1
  println "$__tracker__file__plan__out"
}

: <<'PUB_FUN'
Implements @tickets: prints the tickets of the file of <scope> that
<filter> keeps.
PUB_FUN
tracker__file__tickets() {
  __tracker__file__tickets__plan="$(tracker__file__plan "$1")" || return 1
  @get __tracker__file__tickets__get_6 "$__tracker__file__tickets__plan" '.tickets'
  tracker__filter_tickets "$__tracker__file__tickets__get_6" "$2"
}

: <<'PUB_FUN'
Implements @ticket: prints the ticket <key> of the plan the file of <scope>
keeps.
PUB_FUN
tracker__file__ticket() {
  __tracker__file__ticket "$(tracker__file__plan "$1")" "$2"
}

: <<'PUB_FUN'
Implements @delete: removes the ticket <key> from the file of <scope>, and
removes it from the blockers of every other ticket.
PUB_FUN
tracker__file__delete() {
  __tracker__file__ticket "$(tracker__file__plan "$1")" "$2" > /dev/null || return 1
  @run_awk __tracker__file__delete__document \
    "$__tracker__file__DIR/file_delete.awk" \
    "$(__tracker__file__document "$1")" \
    --load "$__tracker__file__DIR/plan_file.awk" \
    --load "$__tracker__file__DIR/plan_blockers.awk" \
    --arg key "$2" \
    || return 1
  __tracker__file__write "$1" "$__tracker__file__delete__document"
}

: <<'PUB_FUN'
Implements @update: changes the ticket <key> of <scope> by <changes>, rewrites
the file, and prints the ticket as it is then.
PUB_FUN
tracker__file__update() {
  @get __tracker__file__update__state "$3" '.state' ''
  @get __tracker__file__update__milestone "$3" '.milestone' ''
  if @defined "$__tracker__file__update__state"; then
    __tracker__file__require_state "$1" "$__tracker__file__update__state" || return 1
  fi

  __tracker__file__ticket "$(tracker__file__plan "$1")" "$2" > /dev/null || return 1
  @run_awk __tracker__file__update__document \
    "$__tracker__file__DIR/file_update.awk" \
    "$(__tracker__file__document "$1")" \
    --load "$__tracker__file__DIR/plan_file.awk" \
    --arg key "$2" \
    --arg state "$__tracker__file__update__state" \
    --arg milestone "$__tracker__file__update__milestone" \
    || return 1
  __tracker__file__write "$1" "$__tracker__file__update__document"
  __tracker__file__ticket "$(tracker__file__plan "$1")" "$2"
}

: <<'PUB_FUN'
Implements @link: records in the file of <scope> that <blocker> blocks
<blocked>, and prints the edge.
PUB_FUN
tracker__file__link() {
  __tracker__file__link__plan="$(tracker__file__plan "$1")"
  __tracker__file__ticket "$__tracker__file__link__plan" "$2" > /dev/null || return 1
  __tracker__file__ticket "$__tracker__file__link__plan" "$3" > /dev/null || return 1
  @run_awk __tracker__file__link__document \
    "$__tracker__file__DIR/file_link.awk" \
    "$(__tracker__file__document "$1")" \
    --load "$__tracker__file__DIR/plan_file.awk" \
    --load "$__tracker__file__DIR/plan_blockers.awk" \
    --arg blocker "$2" \
    --arg blocked "$3" \
    || return 1
  __tracker__file__write "$1" "$__tracker__file__link__document"
  @wrap __tracker__file__link__wrap_7 "$2"
  @wrap __tracker__file__link__wrap_8 "$3"
  @obj __tracker__file__link__out '.blocker' "$__tracker__file__link__wrap_7" '.blocked' "$__tracker__file__link__wrap_8"
  println "$__tracker__file__link__out"
}

: <<'PUB_FUN'
Implements @unlink: drops the edge from <blocker> to <blocked> in the file
of <scope>, when there is one.
PUB_FUN
tracker__file__unlink() {
  __tracker__file__ticket "$(tracker__file__plan "$1")" "$3" > /dev/null || return 1
  @run_awk __tracker__file__unlink__document \
    "$__tracker__file__DIR/file_unlink.awk" \
    "$(__tracker__file__document "$1")" \
    --load "$__tracker__file__DIR/plan_file.awk" \
    --load "$__tracker__file__DIR/plan_blockers.awk" \
    --arg blocker "$2" \
    --arg blocked "$3" \
    || return 1
  __tracker__file__write "$1" "$__tracker__file__unlink__document"
}

: <<'PUB_FUN'
Implements @create: adds <ticket> to the file of <scope> under the next key
of the file's prefix, in the file's default state when it names none, and
prints it.
PUB_FUN
tracker__file__create() {
  __tracker__file__create__ticket="$(__tracker__file__with_default_state "$1" "$2")"
  @get __tracker__file__create__get_9 "$__tracker__file__create__ticket" '.state'
  __tracker__file__require_state "$1" "$__tracker__file__create__get_9" || return 1
  __tracker__file__create__document="$(__tracker__file__document "$1")"
  __tracker__file__create__key="$(__tracker__file__next_key "$__tracker__file__create__document")"
  @wrap __tracker__file__create__wrap_10 "$__tracker__file__create__key"
  @set __tracker__file__create__entry "$__tracker__file__create__ticket" '.key' "$__tracker__file__create__wrap_10"
  @run_awk __tracker__file__create__document \
    "$__tracker__file__DIR/file_create.awk" \
    "$__tracker__file__create__document" \
    --load "$__tracker__file__DIR/plan_file.awk" \
    --with "$__tracker__file__create__entry" \
    || return 1
  __tracker__file__write "$1" "$__tracker__file__create__document"
  __tracker__file__ticket "$(tracker__file__plan "$1")" "$__tracker__file__create__key"
}

: <<'FUN'
Prints <ticket> in the default state of the file of <scope> when it names
no state, and unchanged otherwise.
FUN
__tracker__file__with_default_state() {
  if @get __tracker__file__with_default_state__get_11 "$2" '.state' ''; @defined "$__tracker__file__with_default_state__get_11"; then
    println "$2"
    return 0
  fi

  @get __tracker__file__with_default_state__get_12 "$(__tracker__file__default_state "$1")" '.name'
  @wrap __tracker__file__with_default_state__wrap_13 "$__tracker__file__with_default_state__get_12"
  @set __tracker__file__with_default_state__out "$2" '.state' "$__tracker__file__with_default_state__wrap_13"
  println "$__tracker__file__with_default_state__out"
}

: <<'FUN'
Prints the key the next ticket of <document> takes: the file's prefix, PLAN
when it names none, and one past the highest number a key of that prefix
carries.

  __tracker__file__next_key '{"prefix":"T","tickets":[{"key":"T-1"},{"key":"T-2"}]}'  ->  T-3
FUN
__tracker__file__next_key() {
  @get __tracker__file__next_key__get_14 "$1" '.prefix' PLAN
  @run_awk __tracker__file__next_key__key \
    "$__tracker__file__DIR/file_next_key.awk" \
    "$1" \
    --arg prefix "$__tracker__file__next_key__get_14" || return 1
  @unwrap __tracker__file__next_key__out "$__tracker__file__next_key__key"
  println "$__tracker__file__next_key__out"
}
