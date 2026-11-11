#!/bin/sh

import "$SHELLOPS_DIR/lib/forge/api.sh"

:<<'MODULE'
Whether the run a job belongs to is still worth finishing.

Under semi-linear merge a run is spent the moment nothing will merge its
commit: the merge request closed, a push moved its head, main moved under a
rebased tree that must be rebased again, or a second run of the same commit
was already going. The forge retires a run only when a new push to the same
merge request supersedes it; the rest hold a runner slot until they finish
on a commit nothing will merge. This module reads the facts off the forge
once per judgement and names the first reason that holds, so a job can stop
its own run.

The judgement fails open: a forge it cannot reach is no verdict at all, and
the caller carries on, since a slot spent on a healthy run costs less than a
healthy run killed on a hiccup.
MODULE

: <<'PUB_CONST'
The reasons a run is stale, in the order they are judged. Public because
the guard spells each one for the log, and a caller may dispatch on them.
PUB_CONST
@enum forge__stale__REASON CLOSED SUPERSEDED BASE_MOVED=base-moved DUPLICATE

:<<'PUB_FUN'
Prints why the current run is stale, or an empty line when it is not, and
fails when the forge could not be asked.

The reasons, in the order they are judged:

  closed       the merge request is merged or closed
  superseded   the merge request's head is another commit
  base-moved   a landing run whose merge request was rebased onto a commit
               that is no longer the target branch's head
  duplicate    an older run of the same commit on the same ref is running,
               and this run is not a landing one

A run outside a merge request, on main or a tag, can only be a duplicate.

  forge__stale__reason "$(@set "$(forge__new_run_options)" '.token' "$token")"
  -> superseded

args:
  $1  Forge options (.token; .owner and .repo optional)
PUB_FUN
forge__stale__reason() {
  __forge__stale__reason__facts="$(__forge__stale__facts "$1")" || return 1
  @enum_values __forge__stale__reason__enum_values_1 forge__stale__REASON
  @find __forge__stale__reason__found __forge__stale__holds "$__forge__stale__reason__enum_values_1" "$__forge__stale__reason__facts"

  if @defined "$__forge__stale__reason__found"; then
    @unwrap __forge__stale__reason__out "$__forge__stale__reason__found"
    println "$__forge__stale__reason__out"
  else
    printf '\n'
  fi
}

:<<'PUB_FUN'
Cancels the current run, every job in it included, this one among them.

args:
  $1  Forge options (.token; .owner and .repo optional)
PUB_FUN
forge__stale__cancel_current() {
  __forge__stale__cancel_current__run="$(forge__current_run "$1")" || return 1
  @get __forge__stale__cancel_current__get_2 "$__forge__stale__cancel_current__run" '.pipeline_id' ''
  forge__cancel_run "$1" "$__forge__stale__cancel_current__get_2"
}

:<<'FUN'
The facts the reasons are judged from, read off the forge once: the run, the
merge request it builds when it builds one, the head of the target branch
when the run is a landing one with a base, and the runs going on the same
ref and commit. Fails when any of them could not be read.

  __forge__stale__facts "$options"
  -> {"run": {...}, "review": {...}, "target_head": "0851af33...", "running": [...]}

args:
  $1  Forge options
FUN
__forge__stale__facts() {
  __forge__stale__facts__run="$(forge__current_run "$1")" || return 1
  @obj __forge__stale__facts__facts '.run' "$__forge__stale__facts__run"

  @get __forge__stale__facts__number "$__forge__stale__facts__run" '.review_number' ''
  if @defined "$__forge__stale__facts__number"; then
    @set __forge__stale__facts__set_3 "$1" '.review_number' "$__forge__stale__facts__number"
    __forge__stale__facts__review="$(forge__get_review "$__forge__stale__facts__set_3")" || return 1
    @set __forge__stale__facts__facts "$__forge__stale__facts__facts" '.review' "$__forge__stale__facts__review"
  fi

  __forge__stale__facts__target_head="$(__forge__stale__target_head "$1" "$__forge__stale__facts__facts")" || return 1
  if @defined "$__forge__stale__facts__target_head"; then
    @set __forge__stale__facts__facts "$__forge__stale__facts__facts" '.target_head' "$__forge__stale__facts__target_head"
  fi

  @get __forge__stale__facts__get_4 "$__forge__stale__facts__run" '.ref' ''
  @get __forge__stale__facts__get_5 "$__forge__stale__facts__run" '.sha' ''
  __forge__stale__facts__running="$(forge__running_runs "$1" "$__forge__stale__facts__get_4" "$__forge__stale__facts__get_5")" || return 1
  @set __forge__stale__facts__out "$__forge__stale__facts__facts" '.running' "$__forge__stale__facts__running"
  println "$__forge__stale__facts__out"
}

:<<'FUN'
Prints the head of the run's target branch when the run is a landing one
rebased onto a known base, an empty line for any other run, and fails when
the branch could not be read.

args:
  $1  Forge options
  $2  The facts so far ({run, review})
FUN
__forge__stale__target_head() {
  @get __forge__stale__target_head__base "$2" '.run.base_sha' ''
  @get __forge__stale__target_head__target "$2" '.review.base' ''

  if @get __forge__stale__target_head__get_6 "$2" '.run.landing' false; ! @is_true "$__forge__stale__target_head__get_6" \
    || ! @defined "$__forge__stale__target_head__base" \
    || ! @defined "$__forge__stale__target_head__target"; then
    printf '\n'
    return 0
  fi

  forge__branch_head "$1" "$__forge__stale__target_head__target"
}

:<<'FUN'
@find predicate: succeeds when the reason $1 (wrapped) holds for the facts
$2, each reason judged by its own predicate.

args:
  $1  A reason, wrapped
  $2  The facts ({run, review, target_head, running})
FUN
__forge__stale__holds() {
  @unwrap __forge__stale__holds__unwrap_7 "$1"
  case "$__forge__stale__holds__unwrap_7" in
    "$forge__stale__REASON_CLOSED") @is_true "$(__forge__stale__closed "$2")" ;;
    "$forge__stale__REASON_SUPERSEDED") @is_true "$(__forge__stale__superseded "$2")" ;;
    "$forge__stale__REASON_BASE_MOVED") @is_true "$(__forge__stale__base_moved "$2")" ;;
    "$forge__stale__REASON_DUPLICATE") @is_true "$(__forge__stale__duplicate "$2")" ;;
  esac
}

:<<'FUN'
Prints true when the run builds a merge request that is no longer open,
false while it is open or when the run builds none. GitLab spells the open
state "opened" and Forgejo spells it "open".

args:
  $1  The facts
FUN
__forge__stale__closed() {
  @get __forge__stale__closed__state "$1" '.review.state' ''

  if ! @defined "$__forge__stale__closed__state"; then
    @false __forge__stale__closed__out
    println "$__forge__stale__closed__out"
    return 0
  fi

  case "$__forge__stale__closed__state" in
    opened|open) @false __forge__stale__closed__out; println "$__forge__stale__closed__out" ;;
    *) @true __forge__stale__closed__out; println "$__forge__stale__closed__out" ;;
  esac
}

:<<'FUN'
Prints true when the merge request's head is a commit other than the one
the run builds, false when it is the same or when the forge does not report
a head.

args:
  $1  The facts
FUN
__forge__stale__superseded() {
  @get __forge__stale__superseded__head "$1" '.review.sha' ''

  if ! @defined "$__forge__stale__superseded__head"; then
    @false __forge__stale__superseded__out
    println "$__forge__stale__superseded__out"
    return 0
  fi

  @get __forge__stale__superseded__get_8 "$1" '.run.sha' ''
  @succeeds __forge__stale__superseded__out [ "$__forge__stale__superseded__head" != "$__forge__stale__superseded__get_8" ]
  println "$__forge__stale__superseded__out"
}

:<<'FUN'
Prints true when a landing run's merge request was rebased onto a commit
that is no longer the head of its target branch, false for any other run.

args:
  $1  The facts
FUN
__forge__stale__base_moved() {
  @get __forge__stale__base_moved__head "$1" '.target_head' ''

  if ! @defined "$__forge__stale__base_moved__head"; then
    @false __forge__stale__base_moved__out
    println "$__forge__stale__base_moved__out"
    return 0
  fi

  @get __forge__stale__base_moved__get_9 "$1" '.run.base_sha' ''
  @succeeds __forge__stale__base_moved__out [ "$__forge__stale__base_moved__head" != "$__forge__stale__base_moved__get_9" ]
  println "$__forge__stale__base_moved__out"
}

:<<'FUN'
Prints true when a run older than this one is running the same commit on the
same ref and this run is not a landing one, false otherwise. The younger run
is the duplicate, so only it ever answers true and the two never cancel each
other. A landing run is never the duplicate: the scheduler creates it on
purpose, once per head, beside the push's own run on the same commit, and
that run is not its twin.

args:
  $1  The facts
FUN
__forge__stale__duplicate() {
  @get __forge__stale__duplicate__id "$1" '.run.pipeline_id' ''

  if @get __forge__stale__duplicate__get_10 "$1" '.run.landing' false; ! @defined "$__forge__stale__duplicate__id" \
    || @is_true "$__forge__stale__duplicate__get_10"; then
    @false __forge__stale__duplicate__out
    println "$__forge__stale__duplicate__out"
    return 0
  fi

  @get __forge__stale__duplicate__get_11 "$1" '.running' ''
  @any __forge__stale__duplicate__out __forge__stale__older "$__forge__stale__duplicate__get_11" "$__forge__stale__duplicate__id"
  println "$__forge__stale__duplicate__out"
}

:<<'FUN'
@any predicate: succeeds when a listed run's id is below this run's.

args:
  $1  A listed run ({id})
  $2  This run's id
FUN
__forge__stale__older() {
  @get __forge__stale__older__get_12 "$1" '.id' 0
  [ "$__forge__stale__older__get_12" -lt "$2" ]
}
