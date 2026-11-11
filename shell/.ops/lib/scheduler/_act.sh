#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/git/rebase.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/scheduler/_landing.sh"

: <<'FRAGMENT'
Performing what a tick decided, on the forge it read (ADR.16@global).

Every write checks the fact it rests on, read again here rather than carried
over from the snapshot, and a check that no longer holds writes nothing and
leaves the action to the next tick (ADR.4@scheduler): the merge carries the
head that was tested and the approval read again on it, the rebase is pushed
on the head the reviewer last pushed, and a run is cancelled only while it is
still the run the tick decided about. The rebase's push goes in one atomic
push with the tick's lease, so a tick that lost its lease writes nothing to
git, and a tick that writes at all holds one.

Under --dry-run every check is resolved and nothing is written, so a week of
ticks beside the shepherd says what the tick would have done without doing
any of it.

A merge request leaving the queue is reported and nothing more. The note that
tells its reviewer is the merge request's own record of the run, which is
built where the tick's events are (OPS-1339).
FRAGMENT

: <<'PUB_CONST'
How an action turned out: performed, skipped because the fact it rested on
had moved, or resolved and left unwritten under --dry-run.
PUB_CONST
@enum scheduler__landing__OUTCOME PERFORMED SKIPPED DRY_RUN=dry-run

: <<'PUB_FUN'
Performs <actions> on the forge in the order they were given, and prints what
it did: each action with .outcome, and .reason on one it skipped. Fails,
printing what it performed up to that point, when the forge refuses a write,
so the tick reports the same way whether it finished or not.

  scheduler__landing__act "$options" "$(scheduler__landing__decide "$snapshot")"
  -> [{"action":"label","iid":12,...,"outcome":"performed"},
      {"action":"merge","iid":12,...,"outcome":"skipped","reason":"its head moved"}]

args:
  $1  The options (scheduler__landing__options)
  $2  The actions (scheduler__landing__decide)
PUB_FUN
scheduler__landing__act() {
  __scheduler__landing__act__leased "$1" || return 1

  @arr __scheduler__landing__act__arr_1
  @obj __scheduler__landing__act__obj_2 '.performed' "$__scheduler__landing__act__arr_1" '.refused' ''
  @reduce __scheduler__landing__act__done __scheduler__landing__act__step "$2" "$__scheduler__landing__act__obj_2" "$1"
  @get __scheduler__landing__act__get_3 "$__scheduler__landing__act__done" '.performed'
  println "$__scheduler__landing__act__get_3"

  @get __scheduler__landing__act__get_4 "$__scheduler__landing__act__done" '.refused' ''
  @defined "$__scheduler__landing__act__get_4" && return 1
  return 0
}

: <<'FUN'
Returns 0 when the tick may write: it holds a lease, or it is writing nothing
at all. Otherwise says the lease is missing and returns 1, since the tick's
git writes land only beside one (ADR.4@scheduler).
FUN
__scheduler__landing__act__leased() {
  if @get __scheduler__landing__act__leased__get_5 "$1" '.dry_run' false; @is_true "$__scheduler__landing__act__leased__get_5"; then
    return 0
  fi
  if @get __scheduler__landing__act__leased__get_6 "$1" '.lease.ref' ''; @defined "$__scheduler__landing__act__leased__get_6"; then
    return 0
  fi

  error "scheduler landing: a tick writes under its queue's lease, and these options carry none"
  return 1
}

: <<'FUN'
@reduce callback: prints <acc> with the <action> performed and recorded, and
<acc> untouched once a write has been refused, so the actions after the one
that failed are left to the next tick.

args:
  $1  The accumulator ({performed, refused})
  $2  The action
  $3  The options
FUN
__scheduler__landing__act__step() {
  if @get __scheduler__landing__act__step__get_7 "$1" '.refused' ''; @defined "$__scheduler__landing__act__step__get_7"; then
    println "$1"
    return 0
  fi

  if ! __scheduler__landing__act__step__outcome="$(__scheduler__landing__act__perform "$3" "$2")"; then
    @get __scheduler__landing__act__step__get_8 "$2" '.action'
    @set __scheduler__landing__act__step__out "$1" '.refused' "$__scheduler__landing__act__step__get_8"
    println "$__scheduler__landing__act__step__out"
    return 0
  fi

  @get __scheduler__landing__act__step__get_9 "$1" '.performed'
  @merge __scheduler__landing__act__step__merge_10 "$2" "$__scheduler__landing__act__step__outcome"
  @push __scheduler__landing__act__step__push_11 "$__scheduler__landing__act__step__get_9" "$__scheduler__landing__act__step__merge_10"
  @set __scheduler__landing__act__step__out "$1" '.performed' "$__scheduler__landing__act__step__push_11"
  println "$__scheduler__landing__act__step__out"
}

: <<'FUN'
Prints how the one <action> turned out, having performed it: .outcome, and
.reason for one whose fact had moved. Fails when the forge refused the write,
or when the action is one the adaptor cannot perform.

args:
  $1  The options
  $2  The action
FUN
__scheduler__landing__act__perform() {
  @get __scheduler__landing__act__perform__get_12 "$2" '.action'
  case "$__scheduler__landing__act__perform__get_12" in
    "$scheduler__landing__PERFORMS_LABEL") __scheduler__landing__act__label "$1" "$2" ;;
    "$scheduler__landing__PERFORMS_LEAVE") __scheduler__landing__act__leave "$1" "$2" ;;
    "$scheduler__landing__PERFORMS_CANCEL_RUN") __scheduler__landing__act__cancel_run "$1" "$2" ;;
    "$scheduler__landing__PERFORMS_REBASE") __scheduler__landing__act__rebase "$1" "$2" ;;
    "$scheduler__landing__PERFORMS_START_RUN") __scheduler__landing__act__start_run "$1" "$2" ;;
    "$scheduler__landing__PERFORMS_MERGE") __scheduler__landing__act__merge "$1" "$2" ;;
    *) @get __scheduler__landing__act__perform__get_13 "$2" '.action'; __scheduler__landing__act__unknown "$__scheduler__landing__act__perform__get_13" ;;
  esac
}

: <<'FUN'
Fails naming the <action> the adaptor cannot perform.
FUN
__scheduler__landing__act__unknown() {
  error "scheduler landing: an action the adaptor cannot perform: $1"
  return 1
}

: <<'FUN'
Renders the queue's state on the merge request: the state <action> names
goes on and the other two come off, in one change. A label rests on no fact
of the forge, so it is written with no check (ADR.4@scheduler).
FUN
__scheduler__landing__act__label() {
  @get __scheduler__landing__act__label__label "$2" '.label'
  @enum_values __scheduler__landing__act__label__enum_values_14 scheduler__landing__STATE
  @filter __scheduler__landing__act__label__off "$__scheduler__landing__act__label__enum_values_14" silt__text_is_not . "$__scheduler__landing__act__label__label"

  @get __scheduler__landing__act__label__get_15 "$2" '.iid'
  @arr __scheduler__landing__act__label__arr_16 "$__scheduler__landing__act__label__label"
  __scheduler__landing__performed "$1" \
    "label !$__scheduler__landing__act__label__get_15 $__scheduler__landing__act__label__label" \
    forge__reconcile_review_labels \
    "$(__scheduler__landing__act__for "$1" "$2")" \
    "$__scheduler__landing__act__label__arr_16" \
    "$__scheduler__landing__act__label__off"
}

: <<'FUN'
Reports that the merge request has left the queue, and why. The state it
leaves in is the label beside this action; the note that tells its reviewer
is built with the tick's events (OPS-1339), so nothing is written here.
FUN
__scheduler__landing__act__leave() {
  @get __scheduler__landing__act__leave__get_17 "$2" '.iid'
  @get __scheduler__landing__act__leave__get_18 "$2" '.reason'
  log "scheduler landing: !$__scheduler__landing__act__leave__get_17 leaves the queue: $__scheduler__landing__act__leave__get_18"
  @obj __scheduler__landing__act__leave__out '.outcome' "$scheduler__landing__OUTCOME_PERFORMED"
  println "$__scheduler__landing__act__leave__out"
}

: <<'FUN'
Cancels the landing run the <action> names, having read it again: a run that
has finished, or one no longer the run of that commit, is left alone and the
action skipped.
FUN
__scheduler__landing__act__cancel_run() {
  __scheduler__landing__act__cancel_run__options="$(__scheduler__landing__act__for "$1" "$2")"
  __scheduler__landing__act__cancel_run__run="$(forge__landing_run "$__scheduler__landing__act__cancel_run__options")" || return 1

  if @get __scheduler__landing__act__cancel_run__get_19 "$__scheduler__landing__act__cancel_run__run" '.sha' ''; @get __scheduler__landing__act__cancel_run__get_20 "$2" '.run'; [ "$__scheduler__landing__act__cancel_run__get_19" != "$__scheduler__landing__act__cancel_run__get_20" ]; then
    __scheduler__landing__skipped 'its landing run is another commit now'
    return 0
  fi
  if @get __scheduler__landing__act__cancel_run__get_21 "$__scheduler__landing__act__cancel_run__run" '.status' ''; [ "$__scheduler__landing__act__cancel_run__get_21" != running ]; then
    __scheduler__landing__skipped 'its landing run has finished'
    return 0
  fi

  @get __scheduler__landing__act__cancel_run__get_22 "$2" '.iid'
  @get __scheduler__landing__act__cancel_run__get_23 "$2" '.run'
  @get __scheduler__landing__act__cancel_run__get_24 "$__scheduler__landing__act__cancel_run__run" '.id'
  __scheduler__landing__performed "$1" \
    "cancel the landing run of !$__scheduler__landing__act__cancel_run__get_22 on $__scheduler__landing__act__cancel_run__get_23" \
    forge__cancel_run \
    "$__scheduler__landing__act__cancel_run__options" \
    "$__scheduler__landing__act__cancel_run__get_24"
}

: <<'FUN'
Replays the merge request's head onto the commit the <action> names and
pushes it, in one atomic push with the tick's lease and on the head the
reviewer last pushed. The push is what starts the head's landing run, since
the merge request is marked and the forge runs a push to a marked one as
one (ADR.2@scheduler), so no run is started after it. A head that moved
since the tick read it skips the action; a replay that conflicts fails it,
since the tick judged that it would not.
FUN
__scheduler__landing__act__rebase() {
  @get __scheduler__landing__act__rebase__get_25 "$2" '.facts.head'
  __scheduler__landing__act__rebase__review="$(__scheduler__landing__act__review "$1" "$2" "$__scheduler__landing__act__rebase__get_25")" || return 1
  if ! @defined "$__scheduler__landing__act__rebase__review"; then
    __scheduler__landing__skipped 'its head moved'
    return 0
  fi

  @get __scheduler__landing__act__rebase__onto "$2" '.onto'
  @get __scheduler__landing__act__rebase__get_26 "$2" '.facts.head'
  __scheduler__landing__act__rebase__commit="$(git__rebase__onto "$__scheduler__landing__act__rebase__get_26" "$__scheduler__landing__act__rebase__onto")" || return 1
  @get __scheduler__landing__act__rebase__get_27 "$__scheduler__landing__act__rebase__review" '.head'
  @get __scheduler__landing__act__rebase__get_28 "$2" '.facts.head'
  __scheduler__landing__act__rebase__writes="$(__scheduler__landing__act__writes \
    "$1" \
    "refs/heads/$__scheduler__landing__act__rebase__get_27" \
    "$__scheduler__landing__act__rebase__get_28" \
    "$__scheduler__landing__act__rebase__commit"
  )"

  @get __scheduler__landing__act__rebase__get_29 "$2" '.iid'
  __scheduler__landing__performed "$1" \
    "rebase !$__scheduler__landing__act__rebase__get_29 onto $__scheduler__landing__act__rebase__onto as $__scheduler__landing__act__rebase__commit" \
    __scheduler__landing__act__push \
    "$1" \
    "$__scheduler__landing__act__rebase__writes"
}

: <<'FUN'
Pushes <writes> to the remote the options name. Fails when the remote refused
them, which is the tick's lease or the head having moved under it: either way
nothing landed and the next tick reads the forge afresh.
FUN
__scheduler__landing__act__push() {
  @get __scheduler__landing__act__push__get_30 "$1" '.remote' origin
  __scheduler__landing__act__push__landed="$(git__remotes__push_leased "$__scheduler__landing__act__push__get_30" "$2")" || return 1
  if @is_true "$__scheduler__landing__act__push__landed"; then
    return 0
  fi

  error "scheduler landing: the remote refused the push; the lease or the head moved under the tick"
  return 1
}

: <<'FUN'
Prints the writes a rebase pushes: the tick's lease at the commit it holds,
and <ref> moved from <expected> to <commit>, so neither lands without the
other (ADR.4@scheduler).

args:
  $1  The options
  $2  The ref the rebased head is pushed to
  $3  The commit the remote is expected to hold it at
  $4  The rebased head
FUN
__scheduler__landing__act__writes() {
  @get __scheduler__landing__act__writes__get_31 "$1" '.lease.ref' ''
  @get __scheduler__landing__act__writes__get_32 "$1" '.lease.sha' ''
  @get __scheduler__landing__act__writes__get_33 "$1" '.lease.sha' ''
  @obj __scheduler__landing__act__writes__obj_34 \
      '.ref' "$__scheduler__landing__act__writes__get_31" \
      '.expected' "$__scheduler__landing__act__writes__get_32" \
      '.commit' "$__scheduler__landing__act__writes__get_33"
  @obj __scheduler__landing__act__writes__obj_35 '.ref' "$2" '.expected' "$3" '.commit' "$4"
  @arr __scheduler__landing__act__writes__out \
    "$__scheduler__landing__act__writes__obj_34" \
    "$__scheduler__landing__act__writes__obj_35"
  println "$__scheduler__landing__act__writes__out"
}

: <<'FUN'
Creates the landing run on the marked head. A head that moved since the tick
read it skips the action, since the run a push of it started is not the run
the tick decided on.
FUN
__scheduler__landing__act__start_run() {
  @get __scheduler__landing__act__start_run__get_36 "$2" '.head'
  __scheduler__landing__act__start_run__review="$(__scheduler__landing__act__review "$1" "$2" "$__scheduler__landing__act__start_run__get_36")" || return 1
  if ! @defined "$__scheduler__landing__act__start_run__review"; then
    __scheduler__landing__skipped 'its head moved'
    return 0
  fi

  @get __scheduler__landing__act__start_run__get_37 "$2" '.iid'
  @get __scheduler__landing__act__start_run__get_38 "$2" '.head'
  __scheduler__landing__performed "$1" \
    "start the landing run of !$__scheduler__landing__act__start_run__get_37 on $__scheduler__landing__act__start_run__get_38" \
    __scheduler__landing__act__start \
    "$(__scheduler__landing__act__for "$1" "$2")" \
    "$__scheduler__landing__act__start_run__review"
}

: <<'FUN'
Starts the landing run of the merge request <options> name, once <review>
shows the mark on it. A merge request the tick labelled and finds unmarked is
a project that does not define the label, since GitLab drops a label it does
not know without a word, and a run started on it would run the governance
checks alone: that fails the tick, naming the label, rather than starting a
run each tick that proves nothing.
FUN
__scheduler__landing__act__start() {
  if ! @is_true "$(__scheduler__landing__act__marked "$2")"; then
    @get __scheduler__landing__act__start__get_39 "$1" '.review_number'
    error "scheduler landing: !$__scheduler__landing__act__start__get_39 does not carry $scheduler__landing__STATE_HEAD after it was set; does the project define the label?"
    return 1
  fi

  forge__start_landing_run "$1"
}

: <<'FUN'
Merges the merge request at the head the <action> names, unsquashed, having
read both facts it rests on again: the head is still that commit, and the
approval rules still hold on it. Either having moved skips the merge, which
is how a withdrawn approval keeps its merge request on the forge
(ADR.4@scheduler).
FUN
__scheduler__landing__act__merge() {
  __scheduler__landing__act__merge__options="$(__scheduler__landing__act__for "$1" "$2")"
  @get __scheduler__landing__act__merge__get_40 "$2" '.sha'
  __scheduler__landing__act__merge__review="$(__scheduler__landing__act__review "$1" "$2" "$__scheduler__landing__act__merge__get_40")" || return 1
  if ! @defined "$__scheduler__landing__act__merge__review"; then
    __scheduler__landing__skipped 'its head moved'
    return 0
  fi

  __scheduler__landing__act__merge__approval="$(forge__review_approval "$__scheduler__landing__act__merge__options")" || return 1
  if @get __scheduler__landing__act__merge__get_41 "$__scheduler__landing__act__merge__approval" '.approved' false; ! @is_true "$__scheduler__landing__act__merge__get_41"; then
    __scheduler__landing__skipped 'its approval was withdrawn'
    return 0
  fi

  @get __scheduler__landing__act__merge__get_42 "$2" '.iid'
  @get __scheduler__landing__act__merge__get_43 "$2" '.sha'
  @get __scheduler__landing__act__merge__get_44 "$2" '.sha'
  __scheduler__landing__performed "$1" \
    "merge !$__scheduler__landing__act__merge__get_42 at $__scheduler__landing__act__merge__get_43" \
    forge__merge_review \
    "$__scheduler__landing__act__merge__options" \
    "$__scheduler__landing__act__merge__get_44"
}

: <<'FUN'
Prints the merge request the <action> concerns, read again, and nothing when
its head is no longer <head>, the commit the tick decided about. Fails when
the forge could not be asked.

args:
  $1  The options
  $2  The action
  $3  The head the tick decided about
FUN
__scheduler__landing__act__review() {
  __scheduler__landing__act__review__read="$(forge__get_review "$(__scheduler__landing__act__for "$1" "$2")")" || return 1

  if @get __scheduler__landing__act__review__get_45 "$__scheduler__landing__act__review__read" '.sha' ''; [ "$__scheduler__landing__act__review__get_45" != "$3" ]; then
    printf '\n'
    return 0
  fi

  println "$__scheduler__landing__act__review__read"
}

: <<'FUN'
Prints true when <review> carries the landing mark, false otherwise.
FUN
__scheduler__landing__act__marked() {
  @arr __scheduler__landing__act__marked__arr_46
  @get __scheduler__landing__act__marked__get_47 "$1" '.labels' "$__scheduler__landing__act__marked__arr_46"
  @any __scheduler__landing__act__marked__out __scheduler__landing__act__is_mark "$__scheduler__landing__act__marked__get_47"
  println "$__scheduler__landing__act__marked__out"
}

: <<'FUN'
@any predicate: returns 0 when the <label> is the queue's landing mark.
FUN
__scheduler__landing__act__is_mark() {
  @get __scheduler__landing__act__is_mark__get_48 "$1" '.name' ''
  [ "$__scheduler__landing__act__is_mark__get_48" = "$scheduler__landing__STATE_HEAD" ]
}

: <<'FUN'
Prints the options addressed at the merge request the <action> concerns.
FUN
__scheduler__landing__act__for() {
  @get __scheduler__landing__act__for__get_49 "$2" '.iid'
  @set __scheduler__landing__act__for__out "$1" '.review_number' "$__scheduler__landing__act__for__get_49"
  println "$__scheduler__landing__act__for__out"
}

: <<'FUN'
Prints the outcome of a write the tick made, or would have made: runs the
command after <sentence> and says it was performed, and under --dry-run says
what it would have done and writes nothing. Fails when the command fails.

args:
  $1     The options
  $2     What the write does, as a sentence
  $3...  The command that writes
FUN
__scheduler__landing__performed() {
  __scheduler__landing__performed__options="$1"
  __scheduler__landing__performed__sentence="$2"
  shift 2

  if @get __scheduler__landing__performed__get_50 "$__scheduler__landing__performed__options" '.dry_run' false; @is_true "$__scheduler__landing__performed__get_50"; then
    log "scheduler landing: would $__scheduler__landing__performed__sentence"
    @obj __scheduler__landing__performed__out '.outcome' "$scheduler__landing__OUTCOME_DRY_RUN"
    println "$__scheduler__landing__performed__out"
    return 0
  fi

  "$@" > /dev/null || return 1
  log "scheduler landing: $__scheduler__landing__performed__sentence"
  @obj __scheduler__landing__performed__out '.outcome' "$scheduler__landing__OUTCOME_PERFORMED"
  println "$__scheduler__landing__performed__out"
}

: <<'FUN'
Prints the outcome of an action left undone because the fact it rested on had
moved, with <reason> as what had.
FUN
__scheduler__landing__skipped() {
  @obj __scheduler__landing__skipped__out '.outcome' "$scheduler__landing__OUTCOME_SKIPPED" '.reason' "$1"
  println "$__scheduler__landing__skipped__out"
}
