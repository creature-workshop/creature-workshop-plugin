#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/queue/api.sh"

: <<'FRAGMENT'
The landing queue's tick logic: which open merge requests are in the queue,
which is its head, and what one tick does about each, from a snapshot and
the queue's transitions alone. lib/scheduler/api.sh says what a snapshot
and an action carry.

A merge request is in one of three states, the labels the tick renders
(ADR.2@scheduler), and each tick judges one event for it, the first that
holds in this order:

  stacked      its target is not the trunk
  unapproved   the approval rules do not hold on its head
  conflicts    it does not rebase cleanly onto the trunk
  red          its landing run on this head failed
  behind       it is in the queue, behind the head
  off-base     it is the head, and its base is not the trunk's
  unrun        it is the head on the base, with no run of this head there
  running      it is the head, and its run on the base is running
  green        it is the head, and its run on the base succeeded
  canceled     it is the head, and its run on the base was cancelled

The head is the first of the queue in the order of the discipline the table
names (ADR.19@global). The transitions table, landing.transitions.yaml
beside this file, is the queue's topology as data: one row per event, with
the state the merge request goes to and the actions the adaptor performs. A
tick walks it. The label is set when the state changes, leaving the queue
is reported once when a state in the queue goes to reviewing, and the row's
actions follow, each carrying the event as its rule: a stale run of the
head is cancelled, a run a merge request off the head still has is
cancelled, the head is rebased, its run started, or it is merged. A table
with a row missing, or a row naming an action the tick cannot build, fails
the tick rather than guessing.

A label is set only when the snapshot's differs, and a run is cancelled only
while it runs, so a snapshot that already matches the decision yields no
actions.
FRAGMENT

@enum scheduler__landing__STATE \
  REVIEWING=scheduler/reviewing \
  WAITING=scheduler/awaiting-merge \
  HEAD=scheduler/next-merge

@enum scheduler__landing__EVENT \
  STACKED UNAPPROVED CONFLICTS RED BEHIND \
  OFF_BASE=off-base UNRUN RUNNING GREEN CANCELED

@enum scheduler__landing__ACTION \
  CANCEL_STALE_RUN=cancel_stale_run CANCEL_RUN=cancel_run REBASE START_RUN=start_run MERGE

: <<'PUB_CONST'
What an action asks the adaptor to perform, the .action a tick emits
(lib/scheduler/api.sh). A row's own vocabulary, scheduler__landing__ACTION,
is rendered into this one: a stale run and a run off the head are both a
cancel_run to the adaptor.
PUB_CONST
@enum scheduler__landing__PERFORMS \
  LABEL LEAVE CANCEL_RUN=cancel_run REBASE START_RUN=start_run MERGE

@enum scheduler__landing__STATUS RUNNING SUCCESS FAILED CANCELED

# CONST: The transitions the landing queue ships with.
__scheduler__landing__TRANSITIONS="$SHELLOPS_DIR/lib/scheduler/landing.transitions.yaml"

# CONST: What a transitions table must carry.
__scheduler__landing__SCHEMA="$SHELLOPS_DIR/lib/scheduler/transitions.schema.json"

: <<'PUB_FUN'
Prints the landing queue's transitions, checked: the table validates against
its schema, names a discipline the queue kind knows, and holds exactly one
row per event, each going to a state. Fails naming every problem found.

  scheduler__landing__transitions
  -> {"queue":"landing","discipline":"priority","transitions":[...]}
PUB_FUN
scheduler__landing__transitions() {
  __scheduler__landing__transitions__table="$(__scheduler__landing__load "$__scheduler__landing__TRANSITIONS")" || return 1
  __scheduler__landing__transitions__problems="$(__scheduler__landing__problems "$__scheduler__landing__transitions__table")"
  if @len __scheduler__landing__transitions__len_1 "$__scheduler__landing__transitions__problems"; ! @is_zero "$__scheduler__landing__transitions__len_1"; then
    @foreach __scheduler__landing__report "$__scheduler__landing__transitions__problems"
    return 1
  fi

  println "$__scheduler__landing__transitions__table"
}

: <<'PUB_FUN'
Prints the actions one tick takes on the landing queue, as a struct array in
the order the adaptor performs them, from <snapshot>. Empty when the forge
already matches the decision. Fails when the transitions table is not fit
to walk.

  scheduler__landing__decide "$snapshot"
  -> [{"action":"label","iid":12,"rule":"unrun","facts":{"from":""},
       "label":"scheduler/next-merge"},
      {"action":"start_run","iid":12,"rule":"unrun","facts":{...},"head":"h1"}]

args:
  $1  The snapshot (lib/scheduler/api.sh)
PUB_FUN
scheduler__landing__decide() {
  __scheduler__landing__decide__table="$(scheduler__landing__transitions)" || return 1
  @arr __scheduler__landing__decide__arr_2
  @get __scheduler__landing__decide__requests "$1" '.merge_requests' "$__scheduler__landing__decide__arr_2"
  @arr __scheduler__landing__decide__arr_3
  @reduce __scheduler__landing__decide__problems __scheduler__landing__status_problem "$__scheduler__landing__decide__requests" "$__scheduler__landing__decide__arr_3"
  if @len __scheduler__landing__decide__len_4 "$__scheduler__landing__decide__problems"; ! @is_zero "$__scheduler__landing__decide__len_4"; then
    @foreach __scheduler__landing__report "$__scheduler__landing__decide__problems"
    return 1
  fi

  @map __scheduler__landing__decide__judged __scheduler__landing__judge "$__scheduler__landing__decide__requests" "$1"
  @filter __scheduler__landing__decide__in "$__scheduler__landing__decide__judged" silt__text_is .event ''
  @filter __scheduler__landing__decide__out "$__scheduler__landing__decide__judged" silt__text_is_not .event ''
  @get __scheduler__landing__decide__discipline "$__scheduler__landing__decide__table" '.discipline'
  __scheduler__landing__decide__queue="$(queue__order "$__scheduler__landing__decide__discipline" "$__scheduler__landing__decide__in")"
  @mapi __scheduler__landing__decide__placed __scheduler__landing__place "$__scheduler__landing__decide__queue" "$1" || return 1
  @concat __scheduler__landing__decide__walk "$__scheduler__landing__decide__placed" "$__scheduler__landing__decide__out"

  @arr __scheduler__landing__decide__arr_5
  @reduce __scheduler__landing__decide__out __scheduler__landing__step "$__scheduler__landing__decide__walk" "$__scheduler__landing__decide__arr_5" "$__scheduler__landing__decide__table" "$1"
  println "$__scheduler__landing__decide__out"
}

: <<'FUN'
@map callback: prints the merge request <mr> judged against <snapshot>, with
.event the membership event that puts it out of the queue, or empty when it
is in, and .ready_at, when it became ready, for the discipline to order by.
FUN
__scheduler__landing__judge() {
  __scheduler__landing__judge__event="$(__scheduler__landing__membership "$1" "$2")"
  @get __scheduler__landing__judge__get_6 "$1" '.approved_at' 0
  @set __scheduler__landing__judge__out "$1" \
    '.event' "$__scheduler__landing__judge__event" \
    '.ready_at' "$__scheduler__landing__judge__get_6"
  println "$__scheduler__landing__judge__out"
}

: <<'FUN'
@mapi callback: prints the queued merge request <mr> at <index> with its
event: the head's run event for the first, against <snapshot>, and behind
for the rest.
FUN
__scheduler__landing__place() {
  if @is_zero "$2"; then
    __scheduler__landing__place__event="$(__scheduler__landing__head_event "$1" "$3")" || return 1
    @set __scheduler__landing__place__out "$1" '.event' "$__scheduler__landing__place__event"
    println "$__scheduler__landing__place__out"
    return 0
  fi

  @set __scheduler__landing__place__out "$1" '.event' "$scheduler__landing__EVENT_BEHIND"
  println "$__scheduler__landing__place__out"
}

: <<'FUN'
Prints the membership event of the merge request <mr> against <snapshot>,
the first that holds of stacked, unapproved, conflicts and red, or nothing
when it is in the queue.
FUN
__scheduler__landing__membership() {
  if @get __scheduler__landing__membership__get_7 "$1" '.target' ''; @get __scheduler__landing__membership__get_8 "$2" '.trunk.branch' ''; [ "$__scheduler__landing__membership__get_7" != "$__scheduler__landing__membership__get_8" ]; then
    println "$scheduler__landing__EVENT_STACKED"
    return 0
  fi
  if @get __scheduler__landing__membership__get_9 "$1" '.approved' false; ! @is_true "$__scheduler__landing__membership__get_9"; then
    println "$scheduler__landing__EVENT_UNAPPROVED"
    return 0
  fi
  if @get __scheduler__landing__membership__get_10 "$1" '.rebases_cleanly' false; ! @is_true "$__scheduler__landing__membership__get_10"; then
    println "$scheduler__landing__EVENT_CONFLICTS"
    return 0
  fi
  if @is_true "$(__scheduler__landing__red_on_head "$1")"; then
    println "$scheduler__landing__EVENT_RED"
    return 0
  fi

  printf '\n'
}

: <<'FUN'
Prints the head <mr>'s run event against <snapshot>: off-base when its base
is not the trunk's, unrun when no run of this head is on the base, and
otherwise what that run's status says. Fails on a status the tick does not
know.
FUN
__scheduler__landing__head_event() {
  if @get __scheduler__landing__head_event__get_11 "$1" '.base' ''; @get __scheduler__landing__head_event__get_12 "$2" '.trunk.base' ''; [ "$__scheduler__landing__head_event__get_11" != "$__scheduler__landing__head_event__get_12" ]; then
    println "$scheduler__landing__EVENT_OFF_BASE"
    return 0
  fi
  if ! @is_true "$(__scheduler__landing__run_on_head "$1" "$2")"; then
    println "$scheduler__landing__EVENT_UNRUN"
    return 0
  fi

  @get __scheduler__landing__head_event__get_13 "$1" '.run.status' ''
  case "$__scheduler__landing__head_event__get_13" in
    running) __scheduler__landing__event_running ;;
    success) __scheduler__landing__event_green ;;
    canceled) __scheduler__landing__event_canceled ;;
    *) @get __scheduler__landing__head_event__get_14 "$1" '.run.status' ''; __scheduler__landing__unknown_status "$__scheduler__landing__head_event__get_14" ;;
  esac
}

: <<'FUN'
Prints the running event: the head's run on the base is running.
FUN
__scheduler__landing__event_running() {
  println "$scheduler__landing__EVENT_RUNNING"
}

: <<'FUN'
Prints the green event: the head's run on the base succeeded.
FUN
__scheduler__landing__event_green() {
  println "$scheduler__landing__EVENT_GREEN"
}

: <<'FUN'
Prints the canceled event: the head's run on the base was cancelled.
FUN
__scheduler__landing__event_canceled() {
  println "$scheduler__landing__EVENT_CANCELED"
}

: <<'FUN'
Fails naming the run <status> the tick does not know.
FUN
__scheduler__landing__unknown_status() {
  log "scheduler landing: the head's run has a status the tick does not know: $1"
  return 1
}

: <<'FUN'
Prints true when the merge request <mr>'s landing run is on its head and
failed: this head's verdict, not an older head's.
FUN
__scheduler__landing__red_on_head() {
  if ! @is_true "$(__scheduler__landing__has_run "$1")"; then
    @false __scheduler__landing__red_on_head__out
    println "$__scheduler__landing__red_on_head__out"
    return 0
  fi
  if @get __scheduler__landing__red_on_head__get_15 "$1" '.run.sha' ''; @get __scheduler__landing__red_on_head__get_16 "$1" '.head' ''; [ "$__scheduler__landing__red_on_head__get_15" != "$__scheduler__landing__red_on_head__get_16" ]; then
    @false __scheduler__landing__red_on_head__out
    println "$__scheduler__landing__red_on_head__out"
    return 0
  fi

  @get __scheduler__landing__red_on_head__get_17 "$1" '.run.status' ''
  @succeeds __scheduler__landing__red_on_head__out [ "$__scheduler__landing__red_on_head__get_17" = failed ]
  println "$__scheduler__landing__red_on_head__out"
}

: <<'FUN'
Prints true when the merge request <mr> has a landing run at all.
FUN
__scheduler__landing__has_run() {
  @get __scheduler__landing__has_run__get_18 "$1" '.run.sha' ''
  @succeeds __scheduler__landing__has_run__out @defined "$__scheduler__landing__has_run__get_18"
  println "$__scheduler__landing__has_run__out"
}

: <<'FUN'
Prints true when the merge request <mr>'s landing run is running.
FUN
__scheduler__landing__running() {
  @get __scheduler__landing__running__get_19 "$1" '.run.status' ''
  @succeeds __scheduler__landing__running__out [ "$__scheduler__landing__running__get_19" = running ]
  println "$__scheduler__landing__running__out"
}

: <<'FUN'
Prints true when the merge request <mr>'s landing run is the run of its
current head on the trunk's base of <snapshot>, so its verdict will count.
FUN
__scheduler__landing__run_on_head() {
  if @get __scheduler__landing__run_on_head__get_20 "$1" '.run.sha' ''; @get __scheduler__landing__run_on_head__get_21 "$1" '.head' ''; [ "$__scheduler__landing__run_on_head__get_20" != "$__scheduler__landing__run_on_head__get_21" ]; then
    @false __scheduler__landing__run_on_head__out
    println "$__scheduler__landing__run_on_head__out"
    return 0
  fi

  @get __scheduler__landing__run_on_head__get_22 "$1" '.run.base' ''
  @get __scheduler__landing__run_on_head__get_23 "$2" '.trunk.base' ''
  @succeeds __scheduler__landing__run_on_head__out [ "$__scheduler__landing__run_on_head__get_22" = "$__scheduler__landing__run_on_head__get_23" ]
  println "$__scheduler__landing__run_on_head__out"
}

: <<'FUN'
@reduce callback: prints <acc> with the actions the transitions <table>
give the judged merge request <mr> against <snapshot>: the label when its
state changes, its leaving reported when a state in the queue goes to
reviewing, then the row's actions.
FUN
__scheduler__landing__step() {
  @get __scheduler__landing__step__event "$2" '.event'
  __scheduler__landing__step__row="$(__scheduler__landing__row "$3" "$__scheduler__landing__step__event")"
  @get __scheduler__landing__step__to "$__scheduler__landing__step__row" '.to'

  __scheduler__landing__step__acc="$(__scheduler__landing__label_action "$1" "$2" "$__scheduler__landing__step__to" "$__scheduler__landing__step__event")"
  __scheduler__landing__step__acc="$(__scheduler__landing__leave_action "$__scheduler__landing__step__acc" "$2" "$__scheduler__landing__step__to" "$__scheduler__landing__step__event")"
  @get __scheduler__landing__step__get_24 "$__scheduler__landing__step__row" '.actions'
  @reduce __scheduler__landing__step__out __scheduler__landing__perform "$__scheduler__landing__step__get_24" "$__scheduler__landing__step__acc" "$2" "$4" "$__scheduler__landing__step__event"
  println "$__scheduler__landing__step__out"
}

: <<'FUN'
Prints the row of <table> for <event>.
FUN
__scheduler__landing__row() {
  @get __scheduler__landing__row__get_25 "$1" '.transitions'
  @find __scheduler__landing__row__out __scheduler__landing__row_for "$__scheduler__landing__row__get_25" "$2"
  println "$__scheduler__landing__row__out"
}

: <<'FUN'
@find callback: returns 0 when the row <row> answers <event>.
FUN
__scheduler__landing__row_for() {
  @get __scheduler__landing__row_for__get_26 "$1" '.event' ''
  [ "$__scheduler__landing__row_for__get_26" = "$2" ]
}

: <<'FUN'
@reduce callback: prints <acc> with the action a row names as <name> built
for the merge request <mr> against <snapshot>, under the rule <event>. Fails
naming an action no row may name.
FUN
__scheduler__landing__perform() {
  @unwrap __scheduler__landing__perform__name "$2"
  case "$__scheduler__landing__perform__name" in
    "$scheduler__landing__ACTION_CANCEL_STALE_RUN") __scheduler__landing__cancel_stale_action "$1" "$3" "$4" "$5" ;;
    "$scheduler__landing__ACTION_CANCEL_RUN") __scheduler__landing__cancel_action "$1" "$3" "$5" ;;
    "$scheduler__landing__ACTION_REBASE") __scheduler__landing__rebase_action "$1" "$3" "$4" "$5" ;;
    "$scheduler__landing__ACTION_START_RUN") __scheduler__landing__start_action "$1" "$3" "$5" ;;
    "$scheduler__landing__ACTION_MERGE") __scheduler__landing__merge_action "$1" "$3" "$5" ;;
    *) __scheduler__landing__unknown_action "$__scheduler__landing__perform__name" "$5" ;;
  esac
}

: <<'FUN'
Fails naming the action <name> the row for <event> asks for, which the tick
cannot build.
FUN
__scheduler__landing__unknown_action() {
  log "scheduler landing: the row for $2 names an action the tick cannot build: $1"
  return 1
}

: <<'FUN'
Prints <acc> with a label action for <mr> when the label it carries is not
<label>, under <rule>; <acc> unchanged when it already is.
FUN
__scheduler__landing__label_action() {
  @get __scheduler__landing__label_action__from "$2" '.label' ''
  if [ "$__scheduler__landing__label_action__from" = "$3" ]; then
    println "$1"
    return 0
  fi

  @obj __scheduler__landing__label_action__facts '.from' "$__scheduler__landing__label_action__from"
  @get __scheduler__landing__label_action__get_27 "$2" '.iid'
  __scheduler__landing__label_action__action="$(__scheduler__landing__action "$scheduler__landing__PERFORMS_LABEL" "$__scheduler__landing__label_action__get_27" "$4" "$__scheduler__landing__label_action__facts" '.label' "$3")"
  @push __scheduler__landing__label_action__out "$1" "$__scheduler__landing__label_action__action"
  println "$__scheduler__landing__label_action__out"
}

: <<'FUN'
Prints <acc> with a leave action for <mr> when the label it carries had it
in the queue and its state <to> is reviewing, so leaving is reported once,
with <event> as the reason; <acc> unchanged otherwise.
FUN
__scheduler__landing__leave_action() {
  @get __scheduler__landing__leave_action__from "$2" '.label' ''
  if [ "$3" != "$scheduler__landing__STATE_REVIEWING" ]; then
    println "$1"
    return 0
  fi
  if [ "$__scheduler__landing__leave_action__from" != "$scheduler__landing__STATE_WAITING" ] \
    && [ "$__scheduler__landing__leave_action__from" != "$scheduler__landing__STATE_HEAD" ]; then
    println "$1"
    return 0
  fi

  @get __scheduler__landing__leave_action__get_28 "$2" '.head'
  @obj __scheduler__landing__leave_action__facts '.from' "$__scheduler__landing__leave_action__from" '.head' "$__scheduler__landing__leave_action__get_28"
  @get __scheduler__landing__leave_action__get_29 "$2" '.iid'
  __scheduler__landing__leave_action__action="$(__scheduler__landing__action "$scheduler__landing__PERFORMS_LEAVE" "$__scheduler__landing__leave_action__get_29" "$4" "$__scheduler__landing__leave_action__facts" '.reason' "$4")"
  @push __scheduler__landing__leave_action__out "$1" "$__scheduler__landing__leave_action__action"
  println "$__scheduler__landing__leave_action__out"
}

: <<'FUN'
Prints <acc> with a cancel_run action for the head <mr> when its run is
running and is not the run of its head on the trunk's base of <snapshot>,
under <event>; <acc> unchanged otherwise.
FUN
__scheduler__landing__cancel_stale_action() {
  if ! @is_true "$(__scheduler__landing__running "$2")"; then
    println "$1"
    return 0
  fi
  if @is_true "$(__scheduler__landing__run_on_head "$2" "$3")"; then
    println "$1"
    return 0
  fi

  @get __scheduler__landing__cancel_stale_action__get_30 "$2" '.head'
  @get __scheduler__landing__cancel_stale_action__get_31 "$2" '.run.base' ''
  @get __scheduler__landing__cancel_stale_action__get_32 "$3" '.trunk.base' ''
  @obj __scheduler__landing__cancel_stale_action__facts \
    '.head' "$__scheduler__landing__cancel_stale_action__get_30" \
    '.run_base' "$__scheduler__landing__cancel_stale_action__get_31" \
    '.trunk_base' "$__scheduler__landing__cancel_stale_action__get_32"
  @get __scheduler__landing__cancel_stale_action__get_33 "$2" '.iid'
  @get __scheduler__landing__cancel_stale_action__get_34 "$2" '.run.sha'
  __scheduler__landing__cancel_stale_action__action="$(__scheduler__landing__action "$scheduler__landing__PERFORMS_CANCEL_RUN" "$__scheduler__landing__cancel_stale_action__get_33" "$4" "$__scheduler__landing__cancel_stale_action__facts" '.run' "$__scheduler__landing__cancel_stale_action__get_34")"
  @push __scheduler__landing__cancel_stale_action__out "$1" "$__scheduler__landing__cancel_stale_action__action"
  println "$__scheduler__landing__cancel_stale_action__out"
}

: <<'FUN'
Prints <acc> with a cancel_run action for <mr> under <event> when its run
is running, since a merge request that is not the head has no run to
finish; <acc> unchanged otherwise.
FUN
__scheduler__landing__cancel_action() {
  if ! @is_true "$(__scheduler__landing__running "$2")"; then
    println "$1"
    return 0
  fi

  @get __scheduler__landing__cancel_action__get_35 "$2" '.head'
  @obj __scheduler__landing__cancel_action__facts '.head' "$__scheduler__landing__cancel_action__get_35"
  @get __scheduler__landing__cancel_action__get_36 "$2" '.iid'
  @get __scheduler__landing__cancel_action__get_37 "$2" '.run.sha'
  __scheduler__landing__cancel_action__action="$(__scheduler__landing__action "$scheduler__landing__PERFORMS_CANCEL_RUN" "$__scheduler__landing__cancel_action__get_36" "$3" "$__scheduler__landing__cancel_action__facts" '.run' "$__scheduler__landing__cancel_action__get_37")"
  @push __scheduler__landing__cancel_action__out "$1" "$__scheduler__landing__cancel_action__action"
  println "$__scheduler__landing__cancel_action__out"
}

: <<'FUN'
Prints <acc> with a rebase action for the head <mr> onto the trunk's base
of <snapshot>, under <event>.
FUN
__scheduler__landing__rebase_action() {
  @get __scheduler__landing__rebase_action__get_38 "$2" '.head'
  @get __scheduler__landing__rebase_action__get_39 "$2" '.base' ''
  @obj __scheduler__landing__rebase_action__facts '.head' "$__scheduler__landing__rebase_action__get_38" '.base' "$__scheduler__landing__rebase_action__get_39"
  @get __scheduler__landing__rebase_action__get_40 "$2" '.iid'
  @get __scheduler__landing__rebase_action__get_41 "$3" '.trunk.base'
  __scheduler__landing__rebase_action__action="$(__scheduler__landing__action "$scheduler__landing__PERFORMS_REBASE" "$__scheduler__landing__rebase_action__get_40" "$4" "$__scheduler__landing__rebase_action__facts" '.onto' "$__scheduler__landing__rebase_action__get_41")"
  @push __scheduler__landing__rebase_action__out "$1" "$__scheduler__landing__rebase_action__action"
  println "$__scheduler__landing__rebase_action__out"
}

: <<'FUN'
Prints <acc> with a start_run action for the marked head <mr>, under
<event>.
FUN
__scheduler__landing__start_action() {
  @get __scheduler__landing__start_action__get_42 "$2" '.run.sha' ''
  @get __scheduler__landing__start_action__get_43 "$2" '.run.status' ''
  @obj __scheduler__landing__start_action__facts '.run' "$__scheduler__landing__start_action__get_42" '.status' "$__scheduler__landing__start_action__get_43"
  @get __scheduler__landing__start_action__get_44 "$2" '.iid'
  @get __scheduler__landing__start_action__get_45 "$2" '.head'
  __scheduler__landing__start_action__action="$(__scheduler__landing__action "$scheduler__landing__PERFORMS_START_RUN" "$__scheduler__landing__start_action__get_44" "$3" "$__scheduler__landing__start_action__facts" '.head' "$__scheduler__landing__start_action__get_45")"
  @push __scheduler__landing__start_action__out "$1" "$__scheduler__landing__start_action__action"
  println "$__scheduler__landing__start_action__out"
}

: <<'FUN'
Prints <acc> with a merge action for the head <mr> at its head, whose
landing run is green, under <event>.
FUN
__scheduler__landing__merge_action() {
  @get __scheduler__landing__merge_action__get_46 "$2" '.run.sha'
  @get __scheduler__landing__merge_action__get_47 "$2" '.run.status'
  @obj __scheduler__landing__merge_action__facts '.run' "$__scheduler__landing__merge_action__get_46" '.status' "$__scheduler__landing__merge_action__get_47"
  @get __scheduler__landing__merge_action__get_48 "$2" '.iid'
  @get __scheduler__landing__merge_action__get_49 "$2" '.head'
  __scheduler__landing__merge_action__action="$(__scheduler__landing__action "$scheduler__landing__PERFORMS_MERGE" "$__scheduler__landing__merge_action__get_48" "$3" "$__scheduler__landing__merge_action__facts" '.sha' "$__scheduler__landing__merge_action__get_49")"
  @push __scheduler__landing__merge_action__out "$1" "$__scheduler__landing__merge_action__action"
  println "$__scheduler__landing__merge_action__out"
}

: <<'FUN'
Prints one action: <action> on the merge request <iid> (null for the
repository), under <rule>, with <facts>, and any path and value pairs that
follow set on it.

  __scheduler__landing__action merge 12 green "$facts" '.sha' h1
  -> {"action":"merge","iid":12,"rule":"green","facts":{...},"sha":"h1"}
FUN
__scheduler__landing__action() {
  @obj __scheduler__landing__action__action '.action' "$1" '.iid' "$2" '.rule' "$3" '.facts' "$4"
  shift 4
  if [ $# -eq 0 ]; then
    println "$__scheduler__landing__action__action"
    return 0
  fi

  @set __scheduler__landing__action__out "$__scheduler__landing__action__action" "$@"
  println "$__scheduler__landing__action__out"
}

: <<'FUN'
Prints the transitions in the yaml file <file> as a struct, validated
against the schema. Fails when the file is missing, is not yaml, or does not
have the shape the schema says.
FUN
__scheduler__landing__load() {
  __scheduler__landing__load__text="$(cat "$1")" || return 1
  @from_yaml __scheduler__landing__load__table "$__scheduler__landing__load__text" || return 1
  @validate "$__scheduler__landing__load__table" "$__scheduler__landing__SCHEMA" || return 1

  println "$__scheduler__landing__load__table"
}

: <<'FUN'
Prints the problems with the transitions <table>, as a struct array of
messages: a discipline the queue kind does not know, an event with no row
or more than one, a row naming an event or a state the queue does not
have. Empty when the table is fit to walk.
FUN
__scheduler__landing__problems() {
  @arr __scheduler__landing__problems__arr_50
  __scheduler__landing__problems__acc="$(__scheduler__landing__discipline_problem "$__scheduler__landing__problems__arr_50" "$1")"
  @enum_values __scheduler__landing__problems__enum_values_51 scheduler__landing__EVENT
  @reduce __scheduler__landing__problems__acc __scheduler__landing__event_problem "$__scheduler__landing__problems__enum_values_51" "$__scheduler__landing__problems__acc" "$1"
  @get __scheduler__landing__problems__get_52 "$1" '.transitions'
  @reduce __scheduler__landing__problems__out __scheduler__landing__row_problem "$__scheduler__landing__problems__get_52" "$__scheduler__landing__problems__acc"
  println "$__scheduler__landing__problems__out"
}

: <<'FUN'
Prints <acc> with a problem when the <table>'s discipline is not one the
queue kind loaded.
FUN
__scheduler__landing__discipline_problem() {
  @get __scheduler__landing__discipline_problem__name "$2" '.discipline' ''
  if @any __scheduler__landing__discipline_problem__any_53 __scheduler__landing__is_word "$(queue__names)" "$__scheduler__landing__discipline_problem__name"; @is_true "$__scheduler__landing__discipline_problem__any_53"; then
    println "$1"
    return 0
  fi

  @wrap __scheduler__landing__discipline_problem__wrap_54 "the discipline is not one the queue kind knows: $__scheduler__landing__discipline_problem__name"
  @push __scheduler__landing__discipline_problem__out "$1" "$__scheduler__landing__discipline_problem__wrap_54"
  println "$__scheduler__landing__discipline_problem__out"
}

: <<'FUN'
@any callback: returns 0 when the wrapped <word> is <name>.
FUN
__scheduler__landing__is_word() {
  @unwrap __scheduler__landing__is_word__unwrap_55 "$1"
  [ "$__scheduler__landing__is_word__unwrap_55" = "$2" ]
}

: <<'FUN'
@reduce callback: prints <acc> with a problem when the wrapped <event> has
no row in <table>, or more than one.
FUN
__scheduler__landing__event_problem() {
  @unwrap __scheduler__landing__event_problem__event "$2"
  @get __scheduler__landing__event_problem__get_56 "$3" '.transitions'
  @reduce __scheduler__landing__event_problem__count __scheduler__landing__count_rows "$__scheduler__landing__event_problem__get_56" 0 "$__scheduler__landing__event_problem__event"
  if [ "$__scheduler__landing__event_problem__count" -eq 1 ]; then
    println "$1"
    return 0
  fi

  @wrap __scheduler__landing__event_problem__wrap_57 "the event $__scheduler__landing__event_problem__event has $__scheduler__landing__event_problem__count rows, not one"
  @push __scheduler__landing__event_problem__out "$1" "$__scheduler__landing__event_problem__wrap_57"
  println "$__scheduler__landing__event_problem__out"
}

: <<'FUN'
@reduce callback: prints <count> plus one when the row <row> answers
<event>.
FUN
__scheduler__landing__count_rows() {
  if @get __scheduler__landing__count_rows__get_58 "$2" '.event' ''; [ "$__scheduler__landing__count_rows__get_58" = "$3" ]; then
    println "$(( $1 + 1 ))"
    return 0
  fi

  println "$1"
}

: <<'FUN'
@reduce callback: prints <acc> with a problem for each of the row <row>'s
event and state that the queue does not have.
FUN
__scheduler__landing__row_problem() {
  __scheduler__landing__row_problem__acc="$1"
  @get __scheduler__landing__row_problem__event "$2" '.event' ''
  @get __scheduler__landing__row_problem__to "$2" '.to' ''
  if ! @enum_check __scheduler__landing__row_problem__event_checked scheduler__landing__EVENT "$__scheduler__landing__row_problem__event" >/dev/null 2>&1; then
    @wrap __scheduler__landing__row_problem__wrap_59 "a row names an event the queue does not judge: $__scheduler__landing__row_problem__event"
    @push __scheduler__landing__row_problem__acc "$__scheduler__landing__row_problem__acc" "$__scheduler__landing__row_problem__wrap_59"
  fi
  if ! @enum_check __scheduler__landing__row_problem__to_checked scheduler__landing__STATE "$__scheduler__landing__row_problem__to" >/dev/null 2>&1; then
    @wrap __scheduler__landing__row_problem__wrap_60 "a row goes to a state the queue does not have: $__scheduler__landing__row_problem__to"
    @push __scheduler__landing__row_problem__acc "$__scheduler__landing__row_problem__acc" "$__scheduler__landing__row_problem__wrap_60"
  fi

  @arr __scheduler__landing__row_problem__arr_61
  @get __scheduler__landing__row_problem__get_62 "$2" '.actions' "$__scheduler__landing__row_problem__arr_61"
  @reduce __scheduler__landing__row_problem__out __scheduler__landing__action_problem "$__scheduler__landing__row_problem__get_62" "$__scheduler__landing__row_problem__acc" "$__scheduler__landing__row_problem__event"
  println "$__scheduler__landing__row_problem__out"
}

: <<'FUN'
@reduce callback: prints <acc> with a problem when the wrapped action
<name> in the row for <event> is not one the tick can build.
FUN
__scheduler__landing__action_problem() {
  @unwrap __scheduler__landing__action_problem__name "$2"
  if @enum_check __scheduler__landing__action_problem__name_checked scheduler__landing__ACTION "$__scheduler__landing__action_problem__name" >/dev/null 2>&1; then
    println "$1"
    return 0
  fi

  @wrap __scheduler__landing__action_problem__wrap_63 "the row for $3 names an action the tick cannot build: $__scheduler__landing__action_problem__name"
  @push __scheduler__landing__action_problem__out "$1" "$__scheduler__landing__action_problem__wrap_63"
  println "$__scheduler__landing__action_problem__out"
}

: <<'FUN'
@reduce callback: prints <acc> with a problem when the merge request <mr>
has a landing run in a status the tick does not know.
FUN
__scheduler__landing__status_problem() {
  @get __scheduler__landing__status_problem__status "$2" '.run.status' ''
  if ! @is_true "$(__scheduler__landing__has_run "$2")"; then
    println "$1"
    return 0
  fi
  if @enum_check __scheduler__landing__status_problem__status_checked scheduler__landing__STATUS "$__scheduler__landing__status_problem__status" >/dev/null 2>&1; then
    println "$1"
    return 0
  fi

  @get __scheduler__landing__status_problem__get_64 "$2" '.iid'
  @wrap __scheduler__landing__status_problem__wrap_65 "the run of $__scheduler__landing__status_problem__get_64 has a status the tick does not know: $__scheduler__landing__status_problem__status"
  @push __scheduler__landing__status_problem__out "$1" "$__scheduler__landing__status_problem__wrap_65"
  println "$__scheduler__landing__status_problem__out"
}

: <<'FUN'
@foreach callback: logs the wrapped problem <message>.
FUN
__scheduler__landing__report() {
  @unwrap __scheduler__landing__report__unwrap_66 "$1"
  log "scheduler landing: $__scheduler__landing__report__unwrap_66"
}
