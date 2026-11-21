#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/linear/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
The linear tracker's work, a plugin of the tracker kind (lib/tracker/api.sh
says what the roles mean) kept with the Linear library it is built on: a
scope's key is a Linear team's key, one of its projects the scope's
project, and the plan is read and written through Linear's API with the
plan-*.graphql documents beside this file. The key comes from
LINEAR_API_KEY, the variable lib/linear declares.

The team's workflow states are the tracker's states, by position, each
named as the team names it, with Linear's type as its type: backlog,
unstarted, started, completed and canceled as backlog, todo, in_progress,
done and cancelled, and a started state whose name says review as
in_review. An update names a state as the team names it. Edges are
Linear's blocks relations, and a related issue outside the scope is a stub.
The awk programs beside this file do the reading of Linear's answers.
FRAGMENT

# CONST: The directory of this module's awk programs, the tracker_*.awk files beside it.
__linear__tracker__DIR="$SHELLOPS_DIR/lib/linear"

: <<'FUN'
Prints the Linear options every call takes: the key from LINEAR_API_KEY.
FUN
__linear__tracker__options() {
  @wrap __linear__tracker__options__wrap_1 "${LINEAR_API_KEY:-}"
  @set __linear__tracker__options__out "$(linear__new_linear_options)" '.token' "$__linear__tracker__options__wrap_1"
  println "$__linear__tracker__options__out"
}

: <<'FUN'
Prints the team record of <scope>, with its states, failing when Linear has
no team with that key.
FUN
__linear__tracker__team() {
  @get __linear__tracker__team__get_2 "$1" '.key'
  @wrap __linear__tracker__team__wrap_3 "$__linear__tracker__team__get_2"
  @obj __linear__tracker__team__obj_4 '.key' "$__linear__tracker__team__wrap_3"
  __linear__tracker__team__answer="$(linear__request plan-team "$__linear__tracker__team__obj_4" "$(__linear__tracker__options)")" || return 1
  @get __linear__tracker__team__teams "$__linear__tracker__team__answer" '.teams.nodes'
  if @empty "$__linear__tracker__team__teams"; then
    @get __linear__tracker__team__get_5 "$1" '.key'
    error "no Linear team with the key $__linear__tracker__team__get_5"
    return 1
  fi

  @first __linear__tracker__team__out "$__linear__tracker__team__teams"
  println "$__linear__tracker__team__out"
}

: <<'FUN'
Prints the project record of <scope>, with its milestones, and nothing when
the scope names no project. Fails when Linear has no project with that name.
FUN
__linear__tracker__project() {
  @get __linear__tracker__project__name "$1" '.project' ''
  if ! @defined "$__linear__tracker__project__name"; then
    return 0
  fi

  @wrap __linear__tracker__project__wrap_6 "$__linear__tracker__project__name"
  @obj __linear__tracker__project__obj_7 '.name' "$__linear__tracker__project__wrap_6"
  __linear__tracker__project__answer="$(linear__request plan-project "$__linear__tracker__project__obj_7" "$(__linear__tracker__options)")" || return 1
  @get __linear__tracker__project__projects "$__linear__tracker__project__answer" '.projects.nodes'
  if @empty "$__linear__tracker__project__projects"; then
    error "no Linear project named $__linear__tracker__project__name"
    return 1
  fi

  @first __linear__tracker__project__out "$__linear__tracker__project__projects"
  println "$__linear__tracker__project__out"
}

: <<'FUN'
Prints the issue filter of <scope>: the team by key, and the project by name
when the scope names one.
FUN
__linear__tracker__filter() {
  @get __linear__tracker__filter__get_8 "$1" '.key'
  @wrap __linear__tracker__filter__wrap_9 "$__linear__tracker__filter__get_8"
  @obj __linear__tracker__filter__obj_10 '.eq' "$__linear__tracker__filter__wrap_9"
  @obj __linear__tracker__filter__obj_11 '.key' "$__linear__tracker__filter__obj_10"
  @obj __linear__tracker__filter__filter '.team' "$__linear__tracker__filter__obj_11"
  @get __linear__tracker__filter__project "$1" '.project' ''
  if @defined "$__linear__tracker__filter__project"; then
    @wrap __linear__tracker__filter__wrap_12 "$__linear__tracker__filter__project"
    @obj __linear__tracker__filter__obj_13 '.eq' "$__linear__tracker__filter__wrap_12"
    @obj __linear__tracker__filter__obj_14 '.name' "$__linear__tracker__filter__obj_13"
    @set __linear__tracker__filter__filter "$__linear__tracker__filter__filter" '.project' "$__linear__tracker__filter__obj_14"
  fi

  println "$__linear__tracker__filter__filter"
}

: <<'FUN'
Prints the issue filter of <scope> narrowed by the parts of the filter
<filter> Linear takes: the state by name, the milestone by id and the
assignee by name. The state's type is not Linear's to filter by, since
in_review is a started state told apart by its name, so the tracker applies
it after the read.
FUN
__linear__tracker__tickets_filter() {
  __linear__tracker__tickets_filter__filter="$(__linear__tracker__filter "$1")"
  @get __linear__tracker__tickets_filter__state "$2" '.state' ''
  @get __linear__tracker__tickets_filter__milestone "$2" '.milestone' ''
  @get __linear__tracker__tickets_filter__assignee "$2" '.assignee' ''
  if @defined "$__linear__tracker__tickets_filter__state"; then
    @wrap __linear__tracker__tickets_filter__wrap_15 "$__linear__tracker__tickets_filter__state"
    @obj __linear__tracker__tickets_filter__obj_16 '.eq' "$__linear__tracker__tickets_filter__wrap_15"
    @obj __linear__tracker__tickets_filter__obj_17 '.name' "$__linear__tracker__tickets_filter__obj_16"
    @set __linear__tracker__tickets_filter__filter "$__linear__tracker__tickets_filter__filter" '.state' "$__linear__tracker__tickets_filter__obj_17"
  fi

  if @defined "$__linear__tracker__tickets_filter__milestone"; then
    @wrap __linear__tracker__tickets_filter__wrap_18 "$__linear__tracker__tickets_filter__milestone"
    @obj __linear__tracker__tickets_filter__obj_19 '.eq' "$__linear__tracker__tickets_filter__wrap_18"
    @obj __linear__tracker__tickets_filter__obj_20 '.id' "$__linear__tracker__tickets_filter__obj_19"
    @set __linear__tracker__tickets_filter__filter "$__linear__tracker__tickets_filter__filter" '.projectMilestone' "$__linear__tracker__tickets_filter__obj_20"
  fi

  if @defined "$__linear__tracker__tickets_filter__assignee"; then
    @wrap __linear__tracker__tickets_filter__wrap_21 "$__linear__tracker__tickets_filter__assignee"
    @obj __linear__tracker__tickets_filter__obj_22 '.eq' "$__linear__tracker__tickets_filter__wrap_21"
    @obj __linear__tracker__tickets_filter__obj_23 '.name' "$__linear__tracker__tickets_filter__obj_22"
    @set __linear__tracker__tickets_filter__filter "$__linear__tracker__tickets_filter__filter" '.assignee' "$__linear__tracker__tickets_filter__obj_23"
  fi

  println "$__linear__tracker__tickets_filter__filter"
}

: <<'PUB_FUN'
Implements @tickets: prints the tickets of <scope> that <filter> keeps,
read from Linear with the filter's state, milestone and assignee in the
query and its type applied after.
PUB_FUN
linear__tracker__tickets() {
  __linear__tracker__tickets__filter="$(__linear__tracker__tickets_filter "$1" "$2")"
  @obj __linear__tracker__tickets__obj_24 '.filter' "$__linear__tracker__tickets__filter"
  __linear__tracker__tickets__issues="$(linear__paginate plan-tickets "$__linear__tracker__tickets__obj_24" '.issues' "$(__linear__tracker__options)")" || return 1
  @run_awk __linear__tracker__tickets__tickets \
    "$__linear__tracker__DIR/tracker_tickets.awk" \
    "$__linear__tracker__tickets__issues" \
    --load "$__linear__tracker__DIR/tracker_issue.awk" || return 1
  tracker__filter_tickets "$__linear__tracker__tickets__tickets" "$2"
}

: <<'FUN'
Prints every issue of <scope> as a struct array, across Linear's pages.
FUN
__linear__tracker__issues() {
  @obj __linear__tracker__issues__obj_25 '.filter' "$(__linear__tracker__filter "$1")"
  linear__paginate plan-issues "$__linear__tracker__issues__obj_25" '.issues' "$(__linear__tracker__options)"
}

: <<'FUN'
Prints Linear's id for the ticket <key>, failing, naming the key, when
Linear has no such issue.
FUN
__linear__tracker__issue_id() {
  __linear__tracker__issue_id__issue="$(linear__get_issue "$1" "$(__linear__tracker__options)" 2>/dev/null)" || true
  @get __linear__tracker__issue_id__id "$__linear__tracker__issue_id__issue" '.id' ''
  if ! @defined "$__linear__tracker__issue_id__id"; then
    error "no ticket $1 in the plan"
    return 1
  fi

  println "$__linear__tracker__issue_id__id"
}

: <<'FUN'
Prints the states of the team record <team>, by position, each with its
type.
FUN
__linear__tracker__states_of_team() {
  @run_awk __linear__tracker__states_of_team__out \
    "$__linear__tracker__DIR/tracker_states.awk" \
    "$1" \
    --load "$__linear__tracker__DIR/tracker_issue.awk" || return 1
  println "$__linear__tracker__states_of_team__out"
}

: <<'FUN'
Prints the id of the state of the team record <team> named <name>, failing,
naming the team's states, when it has none of that name.
FUN
__linear__tracker__state_id() {
  @run_awk __linear__tracker__state_id__found "$__linear__tracker__DIR/tracker_state_id.awk" "$1" --arg name "$2" || return 1
  @unwrap __linear__tracker__state_id__id "$__linear__tracker__state_id__found"
  if ! @defined "$__linear__tracker__state_id__id"; then
    @pluck __linear__tracker__state_id__pluck_27 "$(__linear__tracker__states_of_team "$1")" '.name'
    @join __linear__tracker__state_id__join_28 "$__linear__tracker__state_id__pluck_27" ', '
    error "no state named $2; the team's states: $__linear__tracker__state_id__join_28"
    return 1
  fi

  println "$__linear__tracker__state_id__id"
}

: <<'FUN'
Prints the issue record <issue>, as Linear answered a mutation with it, as a
ticket of the plan.
FUN
__linear__tracker__ticket() {
  @run_awk __linear__tracker__ticket__out \
    "$__linear__tracker__DIR/tracker_ticket.awk" \
    "$1" \
    --load "$__linear__tracker__DIR/tracker_issue.awk" || return 1
  println "$__linear__tracker__ticket__out"
}

: <<'PUB_FUN'
Implements @plan: prints the plan of <scope>, read from Linear.
PUB_FUN
linear__tracker__plan() {
  __linear__tracker__plan__team="$(__linear__tracker__team "$1")" || return 1
  __linear__tracker__plan__project="$(__linear__tracker__project "$1")" || return 1
  __linear__tracker__plan__issues="$(__linear__tracker__issues "$1")" || return 1
  if ! @defined "$__linear__tracker__plan__project"; then
    @null __linear__tracker__plan__project
  fi

  @obj __linear__tracker__plan__read \
    '.scope' "$1" \
    '.team' "$__linear__tracker__plan__team" \
    '.project' "$__linear__tracker__plan__project" \
    '.issues' "$__linear__tracker__plan__issues"
  @run_awk __linear__tracker__plan__out \
    "$__linear__tracker__DIR/tracker_plan.awk" \
    "$__linear__tracker__plan__read" \
    --load "$__linear__tracker__DIR/tracker_issue.awk" || return 1
  println "$__linear__tracker__plan__out"
}

: <<'PUB_FUN'
Implements @states: prints the states of the team of <scope>.
PUB_FUN
linear__tracker__states() {
  __linear__tracker__states__team="$(__linear__tracker__team "$1")" || return 1
  __linear__tracker__states_of_team "$__linear__tracker__states__team"
}

: <<'PUB_FUN'
Implements @ticket: prints the ticket <key>, read from Linear, failing,
naming the key, when Linear has no such issue.
PUB_FUN
linear__tracker__ticket() {
  @wrap __linear__tracker__ticket__wrap_29 "$2"
  @obj __linear__tracker__ticket__obj_30 '.id' "$__linear__tracker__ticket__wrap_29"
  __linear__tracker__ticket__answer="$(linear__request plan-issue "$__linear__tracker__ticket__obj_30" "$(__linear__tracker__options)" 2>/dev/null)" || true
  @get __linear__tracker__ticket__issue "$__linear__tracker__ticket__answer" '.issue' ''
  if @get __linear__tracker__ticket__get_31 "$__linear__tracker__ticket__issue" '.id' ''; ! @defined "$__linear__tracker__ticket__get_31"; then
    error "no ticket $2 in the plan"
    return 1
  fi

  __linear__tracker__ticket "$__linear__tracker__ticket__issue"
}

: <<'PUB_FUN'
Implements @delete: deletes the issue <key> in Linear, which drops its
relations with it.
PUB_FUN
linear__tracker__delete() {
  __linear__tracker__delete__id="$(__linear__tracker__issue_id "$2")" || return 1
  @wrap __linear__tracker__delete__wrap_32 "$__linear__tracker__delete__id"
  @obj __linear__tracker__delete__obj_33 '.id' "$__linear__tracker__delete__wrap_32"
  linear__request plan-delete "$__linear__tracker__delete__obj_33" "$(__linear__tracker__options)" > /dev/null
}

: <<'PUB_FUN'
Implements @update: changes the ticket <key> of <scope> by <changes> through an
issue update, and prints the ticket as Linear answers with it.
PUB_FUN
linear__tracker__update() {
  __linear__tracker__update__id="$(__linear__tracker__issue_id "$2")" || return 1
  @obj __linear__tracker__update__input
  @get __linear__tracker__update__state "$3" '.state' ''
  @get __linear__tracker__update__milestone "$3" '.milestone' ''
  if @defined "$__linear__tracker__update__state"; then
    __linear__tracker__update__team="$(__linear__tracker__team "$1")" || return 1
    __linear__tracker__update__state_id="$(__linear__tracker__state_id "$__linear__tracker__update__team" "$__linear__tracker__update__state")" || return 1
    @wrap __linear__tracker__update__wrap_34 "$__linear__tracker__update__state_id"
    @set __linear__tracker__update__input "$__linear__tracker__update__input" '.stateId' "$__linear__tracker__update__wrap_34"
  fi

  if @defined "$__linear__tracker__update__milestone"; then
    @wrap __linear__tracker__update__wrap_35 "$__linear__tracker__update__milestone"
    @set __linear__tracker__update__input "$__linear__tracker__update__input" '.projectMilestoneId' "$__linear__tracker__update__wrap_35"
  fi

  @wrap __linear__tracker__update__wrap_36 "$__linear__tracker__update__id"
  @obj __linear__tracker__update__obj_37 '.id' "$__linear__tracker__update__wrap_36" '.input' "$__linear__tracker__update__input"
  __linear__tracker__update__answer="$(linear__request plan-update "$__linear__tracker__update__obj_37" "$(__linear__tracker__options)")" || return 1
  @get __linear__tracker__update__get_38 "$__linear__tracker__update__answer" '.issueUpdate.issue'
  __linear__tracker__ticket "$__linear__tracker__update__get_38"
}

: <<'PUB_FUN'
Implements @link: records in Linear that <blocker> blocks <blocked>, and
prints the edge.
PUB_FUN
linear__tracker__link() {
  __linear__tracker__link__blocker="$(__linear__tracker__issue_id "$2")" || return 1
  __linear__tracker__link__blocked="$(__linear__tracker__issue_id "$3")" || return 1
  @wrap __linear__tracker__link__wrap_39 "$__linear__tracker__link__blocker"
  @wrap __linear__tracker__link__wrap_40 "$__linear__tracker__link__blocked"
  @wrap __linear__tracker__link__wrap_41 blocks
  @obj __linear__tracker__link__input \
    '.issueId' "$__linear__tracker__link__wrap_39" \
    '.relatedIssueId' "$__linear__tracker__link__wrap_40" \
    '.type' "$__linear__tracker__link__wrap_41"
  @obj __linear__tracker__link__obj_42 '.input' "$__linear__tracker__link__input"
  linear__request plan-link "$__linear__tracker__link__obj_42" "$(__linear__tracker__options)" > /dev/null || return 1
  @wrap __linear__tracker__link__wrap_43 "$2"
  @wrap __linear__tracker__link__wrap_44 "$3"
  @obj __linear__tracker__link__out '.blocker' "$__linear__tracker__link__wrap_43" '.blocked' "$__linear__tracker__link__wrap_44"
  println "$__linear__tracker__link__out"
}

: <<'PUB_FUN'
Implements @unlink: drops the blocks relation <blocker> holds over
<blocked> in Linear, when there is one.
PUB_FUN
linear__tracker__unlink() {
  @wrap __linear__tracker__unlink__wrap_45 "$3"
  @obj __linear__tracker__unlink__obj_46 '.id' "$__linear__tracker__unlink__wrap_45"
  __linear__tracker__unlink__answer="$(linear__request plan-relations "$__linear__tracker__unlink__obj_46" "$(__linear__tracker__options)")" || return 1
  @get __linear__tracker__unlink__get_47 "$__linear__tracker__unlink__answer" '.issue'
  @run_awk __linear__tracker__unlink__found \
    "$__linear__tracker__DIR/tracker_relation_id.awk" \
    "$__linear__tracker__unlink__get_47" \
    --arg blocker "$2" || return 1
  @unwrap __linear__tracker__unlink__relation "$__linear__tracker__unlink__found"
  if ! @defined "$__linear__tracker__unlink__relation"; then
    return 0
  fi

  @wrap __linear__tracker__unlink__wrap_49 "$__linear__tracker__unlink__relation"
  @obj __linear__tracker__unlink__obj_50 '.id' "$__linear__tracker__unlink__wrap_49"
  linear__request plan-unlink "$__linear__tracker__unlink__obj_50" "$(__linear__tracker__options)" > /dev/null
}

: <<'PUB_FUN'
Implements @create: creates <ticket> in the team of <scope>, under its
project when it names one, in the team's default state when the ticket
names none, and prints the ticket with its key.
PUB_FUN
linear__tracker__create() {
  __linear__tracker__create__team="$(__linear__tracker__team "$1")" || return 1
  __linear__tracker__create__project="$(__linear__tracker__project "$1")" || return 1
  @get __linear__tracker__create__get_51 "$__linear__tracker__create__team" '.id'
  @wrap __linear__tracker__create__wrap_52 "$__linear__tracker__create__get_51"
  @get __linear__tracker__create__get_53 "$2" '.title' ''
  @wrap __linear__tracker__create__wrap_54 "$__linear__tracker__create__get_53"
  @get __linear__tracker__create__get_55 "$2" '.description' ''
  @wrap __linear__tracker__create__wrap_56 "$__linear__tracker__create__get_55"
  @obj __linear__tracker__create__input \
    '.teamId' "$__linear__tracker__create__wrap_52" \
    '.title' "$__linear__tracker__create__wrap_54" \
    '.description' "$__linear__tracker__create__wrap_56"
  __linear__tracker__create__input="$(__linear__tracker__create_state "$__linear__tracker__create__input" "$2" "$__linear__tracker__create__team")" || return 1
  __linear__tracker__create__input="$(__linear__tracker__create_extras "$__linear__tracker__create__input" "$2" "$__linear__tracker__create__project")"
  @obj __linear__tracker__create__obj_57 '.input' "$__linear__tracker__create__input"
  __linear__tracker__create__answer="$(linear__request plan-create "$__linear__tracker__create__obj_57" "$(__linear__tracker__options)")" || return 1
  @get __linear__tracker__create__get_58 "$__linear__tracker__create__answer" '.issueCreate.issue'
  __linear__tracker__ticket "$__linear__tracker__create__get_58"
}

: <<'FUN'
Prints the create <input> with the state id of the team record <team> that
stands for the state <ticket> names, and unchanged when it names none, so
that Linear puts the issue in the team's default state.
FUN
__linear__tracker__create_state() {
  @get __linear__tracker__create_state__state "$2" '.state' ''
  if ! @defined "$__linear__tracker__create_state__state"; then
    println "$1"
    return 0
  fi

  __linear__tracker__create_state__id="$(__linear__tracker__state_id "$3" "$__linear__tracker__create_state__state")" || return 1
  @wrap __linear__tracker__create_state__wrap_59 "$__linear__tracker__create_state__id"
  @set __linear__tracker__create_state__out "$1" '.stateId' "$__linear__tracker__create_state__wrap_59"
  println "$__linear__tracker__create_state__out"
}

: <<'FUN'
Prints the create <input> with the project id, the milestone id and the
estimate added, each when the ticket <ticket> or the project record
<project> gives one.
FUN
__linear__tracker__create_extras() {
  __linear__tracker__create_extras__input="$1"
  @get __linear__tracker__create_extras__milestone "$2" '.milestone' ''
  @get __linear__tracker__create_extras__estimate "$2" '.estimate' ''
  if @defined "$3"; then
    @get __linear__tracker__create_extras__get_60 "$3" '.id'
    @wrap __linear__tracker__create_extras__wrap_61 "$__linear__tracker__create_extras__get_60"
    @set __linear__tracker__create_extras__input "$__linear__tracker__create_extras__input" '.projectId' "$__linear__tracker__create_extras__wrap_61"
  fi

  if @defined "$__linear__tracker__create_extras__milestone"; then
    @wrap __linear__tracker__create_extras__wrap_62 "$__linear__tracker__create_extras__milestone"
    @set __linear__tracker__create_extras__input "$__linear__tracker__create_extras__input" '.projectMilestoneId' "$__linear__tracker__create_extras__wrap_62"
  fi

  if @defined "$__linear__tracker__create_extras__estimate"; then
    @set __linear__tracker__create_extras__input "$__linear__tracker__create_extras__input" '.estimate' "$__linear__tracker__create_extras__estimate"
  fi

  println "$__linear__tracker__create_extras__input"
}
