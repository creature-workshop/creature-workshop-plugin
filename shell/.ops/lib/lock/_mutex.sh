#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh" \
  "$SHELLOPS_DIR/lib/time/api.sh"

: <<'FRAGMENT'
The mutex lock: a queue's lease, one ref on the forge that one tick holds at
a time.

A tick takes the lease before anything else and ends when it cannot. The
lease is refs/scheduler/lease/<queue> on the forge, pointing at a commit
whose trailers name the dispatcher and the tick that took it and whose
committer date is when; each lease commit has the one before it as its
parent, so the ref's history is the record of who held the queue. Taking it
is a push conditioned on the value read, so of two ticks that read the same
value one lands and the other is refused. A lease older than the longest a
tick may run is stale and may be taken the same way. Every git write a tick
makes goes in one atomic push with its lease, so a tick whose lease was
taken over writes nothing to git. The dispatcher kills a tick at a time
limit shorter than the staleness, so no tick still writes once another may
hold its lease, and a tick asks lock__mutex__expired before a write the
fence cannot cover. Reached through lib/lock/api.sh as the plugin mutex.

The git module reads the tick's clone from PROJ.
FRAGMENT

# CONST: The longest a tick may run before its lease is stale, in seconds.
__lock__mutex__STALE_AFTER=1800

# CONST: The time limit the dispatcher kills a tick at, in seconds, shorter than the staleness.
__lock__mutex__TIME_LIMIT=1500

__lock__mutex__REF_PREFIX=refs/scheduler/lease

: <<'PUB_FUN'
Prints the options a lease is taken with: the queue, the dispatcher and the
tick taking it, the remote the forge is on, and the two durations in seconds,
the staleness and the tick's time limit, at their defaults. A caller changes
a field with @set.

  lock__mutex__options landing dispatcher-1 tick-42
  -> {"queue":"landing","dispatcher":"dispatcher-1","tick":"tick-42",
      "remote":"origin","stale_after":1800,"time_limit":1500}

args:
  $1  The queue
  $2  The dispatcher taking the lease
  $3  The tick taking it
PUB_FUN
lock__mutex__options() {
  @obj __lock__mutex__options__out \
    '.queue' "$1" \
    '.dispatcher' "$2" \
    '.tick' "$3" \
    '.remote' origin \
    '.stale_after' "$__lock__mutex__STALE_AFTER" \
    '.time_limit' "$__lock__mutex__TIME_LIMIT"
  println "$__lock__mutex__options__out"
}

: <<'PUB_FUN'
Prints the ref a queue's lease lives under on the forge.

  lock__mutex__ref landing  ->  refs/scheduler/lease/landing
PUB_FUN
lock__mutex__ref() {
  printf '%s/%s\n' "$__lock__mutex__REF_PREFIX" "$1"
}

: <<'PUB_FUN'
Takes the lease of the queue in <options> for the tick in it, and prints the
lease as it stands afterwards: .held true when this tick holds it, false when
another does, and in either case the ref, the commit it points at, the
dispatcher and tick holding it, when it was taken and its age in seconds.
Fails, printing nothing, when the forge could not be asked, or when the
options put the time limit at or past the staleness, since a tick could then
still be writing once another may hold its lease.

A lease the forge holds fresh refuses this tick; one older than .stale_after
is taken over, and the takeover's commit has the stale lease as its parent.

  lock__mutex__acquire "$(lock__mutex__options landing dispatcher-1 tick-42)"
  -> {"held":true,"queue":"landing","ref":"refs/scheduler/lease/landing",
      "remote":"origin","sha":"9a02...","dispatcher":"dispatcher-1",
      "tick":"tick-42","taken_at":1790000000,"age":0,
      "stale_after":1800,"time_limit":1500}

args:
  $1  The options (lock__mutex__options)
PUB_FUN
lock__mutex__acquire() {
  __lock__mutex__acquire__options="$1"
  @get __lock__mutex__acquire__remote "$__lock__mutex__acquire__options" '.remote' origin
  @get __lock__mutex__acquire__get_1 "$__lock__mutex__acquire__options" '.queue'
  __lock__mutex__acquire__ref="$(lock__mutex__ref "$__lock__mutex__acquire__get_1")"

  __lock__mutex__limit_is_shorter "$__lock__mutex__acquire__options" || return 1

  __lock__mutex__acquire__holder="$(__lock__mutex__holder "$__lock__mutex__acquire__remote" "$__lock__mutex__acquire__ref")" || return 1
  if ! @is_true "$(__lock__mutex__free "$__lock__mutex__acquire__holder" "$__lock__mutex__acquire__options")"; then
    __lock__mutex__lease "$__lock__mutex__acquire__options" "$__lock__mutex__acquire__holder" false
    return 0
  fi

  @get __lock__mutex__acquire__expected "$__lock__mutex__acquire__holder" '.sha' ''
  __lock__mutex__acquire__commit="$(__lock__mutex__commit "$__lock__mutex__acquire__options" "$__lock__mutex__acquire__expected")" || return 1
  __lock__mutex__acquire__pushed="$(git__remotes__push_expecting \
    "$__lock__mutex__acquire__remote" \
    "$__lock__mutex__acquire__ref" \
    "$__lock__mutex__acquire__expected" \
    "$__lock__mutex__acquire__commit"
  )" || return 1

  if @is_true "$__lock__mutex__acquire__pushed"; then
    __lock__mutex__acquire__facts="$(__lock__mutex__facts "$__lock__mutex__acquire__commit")" || return 1
    __lock__mutex__lease "$__lock__mutex__acquire__options" "$__lock__mutex__acquire__facts" true
    return 0
  fi

  __lock__mutex__acquire__holder="$(__lock__mutex__holder "$__lock__mutex__acquire__remote" "$__lock__mutex__acquire__ref")" || return 1
  __lock__mutex__lease "$__lock__mutex__acquire__options" "$__lock__mutex__acquire__holder" false
}

: <<'PUB_FUN'
Pushes the tick's git writes, each a <refspec>, in one atomic push with
<lease>, so they land only while the forge still holds the lease at the
commit this tick took, and none lands otherwise. With no refspec it only
proves the lease is still held. Prints true when the writes landed, false
when the forge refused them, and fails when it could not be asked.

  lock__mutex__fence "$lease" HEAD:refs/heads/main refs/notes/facts  ->  true

args:
  $1     The lease (lock__mutex__acquire, with .held true)
  $2...  The refspecs to push
PUB_FUN
lock__mutex__fence() {
  __lock__mutex__fence__lease="$1"
  shift
  @get __lock__mutex__fence__get_2 "$__lock__mutex__fence__lease" '.remote' origin
  @get __lock__mutex__fence__get_3 "$__lock__mutex__fence__lease" '.ref'
  @get __lock__mutex__fence__get_4 "$__lock__mutex__fence__lease" '.sha'
  git__remotes__push_atomic_expecting \
    "$__lock__mutex__fence__get_2" \
    "$__lock__mutex__fence__get_3" \
    "$__lock__mutex__fence__get_4" \
    "$@"
}

: <<'PUB_FUN'
Prints true when <lease> is older than <stale_after> seconds, the longest a
tick may run, so another tick may take it over; false while it is fresh.

  lock__mutex__stale "$lease" 1800  ->  false

args:
  $1  A lease (lock__mutex__acquire)
  $2  The staleness in seconds
PUB_FUN
lock__mutex__stale() {
  @get __lock__mutex__stale__get_5 "$1" '.taken_at' 0
  @succeeds __lock__mutex__stale__out [ "$(__lock__mutex__age "$__lock__mutex__stale__get_5")" -gt "$2" ]
  println "$__lock__mutex__stale__out"
}

: <<'PUB_FUN'
Prints true when the tick holding <lease> has passed its time limit, so it
writes nothing more through the forge's API: another tick may hold the lease
once the staleness passes, and the limit is the shorter. False while the
tick is within it.

  lock__mutex__expired "$lease"  ->  false
PUB_FUN
lock__mutex__expired() {
  @get __lock__mutex__expired__get_6 "$1" '.taken_at' 0
  __lock__mutex__expired__age="$(__lock__mutex__age "$__lock__mutex__expired__get_6")"
  @get __lock__mutex__expired__get_7 "$1" '.time_limit' "$__lock__mutex__TIME_LIMIT"
  @succeeds __lock__mutex__expired__out [ "$__lock__mutex__expired__age" -gt "$__lock__mutex__expired__get_7" ]
  println "$__lock__mutex__expired__out"
}

: <<'FUN'
Returns 0 when <options>' time limit is shorter than its staleness, and
fails naming both otherwise.
FUN
__lock__mutex__limit_is_shorter() {
  @get __lock__mutex__limit_is_shorter__limit "$1" '.time_limit' "$__lock__mutex__TIME_LIMIT"
  @get __lock__mutex__limit_is_shorter__stale "$1" '.stale_after' "$__lock__mutex__STALE_AFTER"
  if [ "$__lock__mutex__limit_is_shorter__limit" -lt "$__lock__mutex__limit_is_shorter__stale" ]; then
    return 0
  fi

  log "lock mutex: the time limit (${__lock__mutex__limit_is_shorter__limit}s) must be shorter than the staleness (${__lock__mutex__limit_is_shorter__stale}s)"
  return 1
}

: <<'FUN'
Prints the lease lock__mutex__acquire answers with: the queue, its ref, the
remote and the two durations from <options>, the holder's facts from
<facts>, and <held>, whether this tick is that holder.
FUN
__lock__mutex__lease() {
  @get __lock__mutex__lease__get_8 "$1" '.queue'
  @get __lock__mutex__lease__get_9 "$1" '.queue'
  @get __lock__mutex__lease__get_10 "$1" '.remote' origin
  @get __lock__mutex__lease__get_11 "$2" '.sha' ''
  @get __lock__mutex__lease__get_12 "$2" '.dispatcher' ''
  @get __lock__mutex__lease__get_13 "$2" '.tick' ''
  @get __lock__mutex__lease__get_14 "$2" '.taken_at' 0
  @get __lock__mutex__lease__get_15 "$2" '.age' 0
  @get __lock__mutex__lease__get_16 "$1" '.stale_after' "$__lock__mutex__STALE_AFTER"
  @get __lock__mutex__lease__get_17 "$1" '.time_limit' "$__lock__mutex__TIME_LIMIT"
  @obj __lock__mutex__lease__out \
    '.held' "$3" \
    '.queue' "$__lock__mutex__lease__get_8" \
    '.ref' "$(lock__mutex__ref "$__lock__mutex__lease__get_9")" \
    '.remote' "$__lock__mutex__lease__get_10" \
    '.sha' "$__lock__mutex__lease__get_11" \
    '.dispatcher' "$__lock__mutex__lease__get_12" \
    '.tick' "$__lock__mutex__lease__get_13" \
    '.taken_at' "$__lock__mutex__lease__get_14" \
    '.age' "$__lock__mutex__lease__get_15" \
    '.stale_after' "$__lock__mutex__lease__get_16" \
    '.time_limit' "$__lock__mutex__lease__get_17"
  println "$__lock__mutex__lease__out"
}

: <<'FUN'
Prints the facts of the lease <remote> holds under <ref>, fetched into the
clone under the same name: its commit, dispatcher, tick, when it was taken
and its age. Prints an empty struct when the forge holds none, and fails
when it could not be asked.
FUN
__lock__mutex__holder() {
  __lock__mutex__holder__has="$(git__remotes__has_ref "$1" "$2")" || return 1
  if ! @is_true "$__lock__mutex__holder__has"; then
    @obj __lock__mutex__holder__out
    println "$__lock__mutex__holder__out"
    return 0
  fi

  git__remotes__fetch_ref "$1" "$2" || return 1
  __lock__mutex__facts "$2"
}

: <<'FUN'
Prints the facts the lease commit <rev> carries: its sha, the dispatcher and
tick its trailers name, the committer date it was taken at, and its age now.
FUN
__lock__mutex__facts() {
  __lock__mutex__facts__sha="$(git__commit_of "$1")" || return 1
  __lock__mutex__facts__taken_at="$(git__commits__committed_at "$__lock__mutex__facts__sha")" || return 1

  @obj __lock__mutex__facts__out \
    '.sha' "$__lock__mutex__facts__sha" \
    '.dispatcher' "$(git__commits__trailer "$__lock__mutex__facts__sha" Dispatcher)" \
    '.tick' "$(git__commits__trailer "$__lock__mutex__facts__sha" Tick)" \
    '.taken_at' "$__lock__mutex__facts__taken_at" \
    '.age' "$(__lock__mutex__age "$__lock__mutex__facts__taken_at")"
  println "$__lock__mutex__facts__out"
}

: <<'FUN'
Prints true when the lease at <holder> may be taken: the forge holds none,
or the one it holds is older than <options>' staleness.
FUN
__lock__mutex__free() {
  if @get __lock__mutex__free__get_18 "$1" '.sha' ''; ! @defined "$__lock__mutex__free__get_18"; then
    @true __lock__mutex__free__out
    println "$__lock__mutex__free__out"
    return 0
  fi

  @get __lock__mutex__free__get_19 "$2" '.stale_after' "$__lock__mutex__STALE_AFTER"
  lock__mutex__stale "$1" "$__lock__mutex__free__get_19"
}

: <<'FUN'
Writes the commit a lease points at and prints it: no files, <parent> as its
parent when the forge held a lease before, and a message naming the queue,
the dispatcher and the tick from <options>, the three as trailers a reader
finds again. Its committer date is when the lease was taken.
FUN
__lock__mutex__commit() {
  @get __lock__mutex__commit__queue "$1" '.queue'
  @get __lock__mutex__commit__dispatcher "$1" '.dispatcher'
  @get __lock__mutex__commit__tick "$1" '.tick'
  __lock__mutex__commit__message="$(printf 'lease %s: %s tick %s\n\nQueue: %s\nDispatcher: %s\nTick: %s\n' \
    "$__lock__mutex__commit__queue" \
    "$__lock__mutex__commit__dispatcher" \
    "$__lock__mutex__commit__tick" \
    "$__lock__mutex__commit__queue" \
    "$__lock__mutex__commit__dispatcher" \
    "$__lock__mutex__commit__tick"
  )"

  git__commits__empty "$__lock__mutex__commit__message" "$2"
}

: <<'FUN'
Prints the seconds from <taken_at> to now.
FUN
__lock__mutex__age() {
  println "$(( $(time__epoch_seconds) - $1 ))"
}
