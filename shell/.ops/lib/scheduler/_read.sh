#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh" \
  "$SHELLOPS_DIR/lib/git/rebase.sh" \
  "$SHELLOPS_DIR/lib/scheduler/_landing.sh" \
  "$SHELLOPS_DIR/lib/time/api.sh"

: <<'FRAGMENT'
One tick's reading of a repository: the snapshot lib/scheduler/api.sh
describes, filled from the forge's own answers and from the clone the tick
keeps beside it.

The forge says which merge requests are open and where each head stands,
then of each one whether its approval rules are met and since when, and
which of its pipelines is the landing run. The clone says the rest, because
the forge cannot: where the trunk stands, which commit a head is rebased on,
and whether it rebases at all. Nothing here decides anything; what a tick
does about what it read is scheduler__landing__decide.

A merge request the forge or the clone would not answer for fails the read
rather than being judged on facts the tick does not have, so a queue read in
half never reaches the tick as a whole one.
FRAGMENT

@obj __scheduler__landing__priorities \
  '."priority/low"' -1 \
  '."priority/high"' 1 \
  '."priority/urgent"' 2

: <<'CONST'
What a person's priority label scores a merge request, against the 0 of one
carrying none, so a label moves it either way (ADR.19@global).
CONST
__scheduler__landing__PRIORITIES="$__scheduler__landing__priorities"

# CONST: One newline, which separates the labels in a list of labels kept as text.
__scheduler__landing__NL="
"

: <<'FUN'
A predicate for @filter: answers true in the variable $1 when the entry $3
carries .unread, the reason its merge request could not be read, and false
otherwise.
FUN
__scheduler__landing__is_unread() {
  @get __scheduler__landing__is_unread__reason "$3" '.unread'
  @succeeds "$1" @defined "$__scheduler__landing__is_unread__reason"
}

: <<'PUB_FUN'
Prints the snapshot of the repository <options> names, as lib/scheduler/api.sh
says a snapshot carries it. Fetches the remote first, so the clone holds the
trunk and the heads the snapshot speaks of. Fails when the forge or the clone
could not answer, naming each merge request left unread.

  scheduler__landing__read "$(scheduler__landing__options "$token")"
  -> {"now":1790000000,"trunk":{"branch":"main",...},"merge_requests":[...]}

args:
  $1  The options (scheduler__landing__options)
PUB_FUN
scheduler__landing__read() {
  __scheduler__landing__read__branch="$(__scheduler__landing__branch "$1")" || return 1
  @get __scheduler__landing__read__get_1 "$1" '.remote' origin
  git__fetch_prune "$__scheduler__landing__read__get_1" || return 1

  __scheduler__landing__read__trunk="$(scheduler__landing__trunk "$1" "$__scheduler__landing__read__branch")" || return 1
  __scheduler__landing__read__reviews="$(forge__open_reviews "$1" "$__scheduler__landing__read__branch")" || return 1
  @map __scheduler__landing__read__entries __scheduler__landing__entry "$__scheduler__landing__read__reviews" "$1" "$__scheduler__landing__read__trunk"
  @filter __scheduler__landing__read__unread "$__scheduler__landing__read__entries" __scheduler__landing__is_unread
  if @len __scheduler__landing__read__len_2 "$__scheduler__landing__read__unread"; ! @is_zero "$__scheduler__landing__read__len_2"; then
    @foreach __scheduler__landing__unread_report "$__scheduler__landing__read__unread"
    return 1
  fi

  @obj __scheduler__landing__read__out \
    '.now' "$(time__epoch_seconds)" \
    '.trunk' "$__scheduler__landing__read__trunk" \
    '.merge_requests' "$__scheduler__landing__read__entries"
  println "$__scheduler__landing__read__out"
}

: <<'FUN'
Prints the trunk the tick lands on: the branch <options> names, or the one
the forge calls its default.
FUN
__scheduler__landing__branch() {
  @get __scheduler__landing__branch__named "$1" '.branch' ''
  if @defined "$__scheduler__landing__branch__named"; then
    println "$__scheduler__landing__branch__named"
    return 0
  fi

  forge__default_branch "$1"
}

: <<'PUB_FUN'
Prints the trunk as the tick lands on it, the .trunk of a snapshot: <branch>,
the commit the clone's remote holds it at, and the commit a head rebases
onto, which is that same commit. Reads the clone as it stands, so a caller
fetches first. Fails when the clone does not hold the branch.

  scheduler__landing__trunk "$options" main
  -> {"branch":"main","head":"7d68...","base":"7d68..."}

args:
  $1  The options (scheduler__landing__options)
  $2  The trunk's branch
PUB_FUN
scheduler__landing__trunk() {
  @get __scheduler__landing__trunk__get_3 "$1" '.remote' origin
  __scheduler__landing__trunk__ref="$__scheduler__landing__trunk__get_3/$2"
  __scheduler__landing__trunk__head="$(git__commit_of "$__scheduler__landing__trunk__ref")" || return 1

  @obj __scheduler__landing__trunk__out \
    '.branch' "$2" \
    '.head' "$__scheduler__landing__trunk__head" \
    '.base' "$__scheduler__landing__trunk__head"
  println "$__scheduler__landing__trunk__out"
}

: <<'FUN'
@map callback: prints the open merge request <review> as a snapshot entry,
asking the forge its approval and its landing run, and the clone the commit
its head is rebased on, whether it rebases onto the trunk's base, and the
base of that run. Prints an entry carrying .unread instead when either would
not answer, since a callback's failure does not reach the caller of @map.

args:
  $1  The merge request (iid, head, target, labels)
  $2  The options
  $3  The trunk
FUN
__scheduler__landing__entry() {
  @get __scheduler__landing__entry__iid "$1" '.iid'
  @get __scheduler__landing__entry__head "$1" '.head' ''
  @set __scheduler__landing__entry__options "$2" '.review_number' "$__scheduler__landing__entry__iid"

  if ! __scheduler__landing__entry__approval="$(forge__review_approval "$__scheduler__landing__entry__options")"; then
    __scheduler__landing__unread "$__scheduler__landing__entry__iid" 'the forge would not answer its approval'
    return 0
  fi
  if ! __scheduler__landing__entry__run="$(forge__landing_run "$__scheduler__landing__entry__options")"; then
    __scheduler__landing__unread "$__scheduler__landing__entry__iid" 'the forge would not answer its landing run'
    return 0
  fi
  if @get __scheduler__landing__entry__get_4 "$3" '.head'; ! __scheduler__landing__entry__base="$(git__commits__fork_point "$__scheduler__landing__entry__head" "$__scheduler__landing__entry__get_4")"; then
    __scheduler__landing__unread "$__scheduler__landing__entry__iid" 'the clone does not hold its head'
    return 0
  fi
  @get __scheduler__landing__entry__get_5 "$3" '.base'
  __scheduler__landing__entry__clean="$(git__rebase__clean "$__scheduler__landing__entry__head" "$__scheduler__landing__entry__get_5")" || {
    __scheduler__landing__unread "$__scheduler__landing__entry__iid" 'whether its head rebases onto the trunk'
    return 0
  }
  @arr __scheduler__landing__entry__arr_6
  @get __scheduler__landing__entry__get_7 "$1" '.labels' "$__scheduler__landing__entry__arr_6"
  __scheduler__landing__entry__marks="$(scheduler__landing__marks "$__scheduler__landing__entry__get_7")" || return 1

  @get __scheduler__landing__entry__get_8 "$1" '.target' ''
  @get __scheduler__landing__entry__get_9 "$__scheduler__landing__entry__approval" '.approved' false
  @get __scheduler__landing__entry__get_10 "$__scheduler__landing__entry__approval" '.approved_at' 0
  @get __scheduler__landing__entry__get_11 "$__scheduler__landing__entry__marks" '.priority' 0
  @get __scheduler__landing__entry__get_12 "$__scheduler__landing__entry__marks" '.label' ''
  @obj __scheduler__landing__entry__out \
    '.iid' "$__scheduler__landing__entry__iid" \
    '.head' "$__scheduler__landing__entry__head" \
    '.target' "$__scheduler__landing__entry__get_8" \
    '.base' "$__scheduler__landing__entry__base" \
    '.approved' "$__scheduler__landing__entry__get_9" \
    '.approved_at' "$__scheduler__landing__entry__get_10" \
    '.priority' "$__scheduler__landing__entry__get_11" \
    '.label' "$__scheduler__landing__entry__get_12" \
    '.run' "$(__scheduler__landing__run "$__scheduler__landing__entry__run" "$3")" \
    '.rebases_cleanly' "$__scheduler__landing__entry__clean"
  println "$__scheduler__landing__entry__out"
}

: <<'FUN'
Prints the landing <run> as the snapshot carries it, with the commit it was
rebased on in place of the forge's own id, and null for a merge request with
no run. A run the clone can no longer reach was rebased on a commit nothing
holds, which reads as no base at all: the trunk's base it is not, which is
what the tick makes of it.

args:
  $1  The run the forge answered with, or null
  $2  The trunk
FUN
__scheduler__landing__run() {
  @get __scheduler__landing__run__sha "$1" '.sha' ''
  if ! @defined "$__scheduler__landing__run__sha"; then
    @null __scheduler__landing__run__out
    println "$__scheduler__landing__run__out"
    return 0
  fi

  @get __scheduler__landing__run__get_13 "$2" '.head'
  __scheduler__landing__run__base="$(git__commits__fork_point "$__scheduler__landing__run__sha" "$__scheduler__landing__run__get_13")" || __scheduler__landing__run__base=""

  @get __scheduler__landing__run__get_14 "$1" '.status' ''
  @obj __scheduler__landing__run__out \
    '.sha' "$__scheduler__landing__run__sha" \
    '.base' "$__scheduler__landing__run__base" \
    '.status' "$__scheduler__landing__run__get_14"
  println "$__scheduler__landing__run__out"
}

: <<'PUB_FUN'
Prints the marks the labels <labels> carry: .label, the state of the queue
they show, and .priority, the score a person set on the merge request. The
state is the tick's own rendering, read only so a tick that finds it right
writes nothing (ADR.2@scheduler). A merge request that carries two states is
read at the one the queue has first. The priority is a person's mark that
the tick obeys (ADR.19@global): the highest score among the labels, low,
high or urgent, against the 0 of none.

  scheduler__landing__marks '["type/fix","priority/urgent","scheduler/next-merge"]'
  -> {"label":"scheduler/next-merge","priority":2}
PUB_FUN
scheduler__landing__marks() {
  __scheduler__landing__marks__labels="$1"
  if @typeof __scheduler__landing__marks__kind "$1"; [ "$__scheduler__landing__marks__kind" != array ]; then
    @arr __scheduler__landing__marks__labels
  fi

  @enum_values __scheduler__landing__marks__enum_values_15 scheduler__landing__STATE
  @intersect __scheduler__landing__marks__shown "$__scheduler__landing__marks__enum_values_15" "$__scheduler__landing__marks__labels"
  @get __scheduler__landing__marks__label "$__scheduler__landing__marks__shown" '.[0]' ''
  @wrap __scheduler__landing__marks__label "$__scheduler__landing__marks__label"

  @entries __scheduler__landing__marks__scores "$__scheduler__landing__PRIORITIES"
  @join __scheduler__landing__marks__carried "$__scheduler__landing__marks__labels" "$__scheduler__landing__NL"
  @filter __scheduler__landing__marks__set "$__scheduler__landing__marks__scores" __scheduler__landing__is_carried "$__scheduler__landing__marks__carried"
  @pluck __scheduler__landing__marks__values "$__scheduler__landing__marks__set" '.value'
  @max __scheduler__landing__marks__priority "$__scheduler__landing__marks__values"
  if ! @defined "$__scheduler__landing__marks__priority"; then
    __scheduler__landing__marks__priority=0
  fi

  @obj __scheduler__landing__marks__out \
    '.label' "$__scheduler__landing__marks__label" \
    '.priority' "$__scheduler__landing__marks__priority"
  println "$__scheduler__landing__marks__out"
}

: <<'FUN'
A predicate for @filter: answers true in the variable $1 when the key of the
entry $3, a priority label, is one of the labels $4, which are one on each
line, and false otherwise.
FUN
__scheduler__landing__is_carried() {
  @get __scheduler__landing__is_carried__label "$3" '.key' ''

  case "$__scheduler__landing__NL$4$__scheduler__landing__NL" in
    # structs-lint: allow -- whether a label is among labels kept one on each line, in plain text
    *"$__scheduler__landing__NL$__scheduler__landing__is_carried__label$__scheduler__landing__NL"*) @true "$1" ;;
    *) @false "$1" ;;
  esac
}

: <<'FUN'
Prints the entry standing for a merge request <iid> left unread, for
<reason>.
FUN
__scheduler__landing__unread() {
  @obj __scheduler__landing__unread__out '.iid' "$1" '.unread' "$2"
  println "$__scheduler__landing__unread__out"
}

: <<'FUN'
@foreach callback: says which merge request's <entry> was left unread.
FUN
__scheduler__landing__unread_report() {
  @get __scheduler__landing__unread_report__get_16 "$1" '.iid'
  @get __scheduler__landing__unread_report__get_17 "$1" '.unread'
  log "scheduler landing: !$__scheduler__landing__unread_report__get_16 could not be read: $__scheduler__landing__unread_report__get_17"
}
