#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
The snapshots a case of the tick logic needs building before it can assert
anything: a forge's trunk and its open merge requests, as
lib/scheduler/api.sh says a snapshot carries them. A fixture is domain
knowledge, so it sits beside the module rather than in whichever suite
needed it first, and outside api.sh so importing the module hands no fixture
to production code.
FRAGMENT

: <<'PUB_FUN'
Builds a snapshot taken at <now> of a forge whose trunk main stands at
<head>, that commit also the base a head rebases onto, and no merge
requests. A case adds merge requests with
scheduler__fixture_with.

  scheduler__fixture_snapshot 1790000000 t1
PUB_FUN
scheduler__fixture_snapshot() {
  @obj __scheduler__fixture_snapshot__trunk '.branch' main '.head' "$2" '.base' "$2"
  @arr __scheduler__fixture_snapshot__arr_1
  @obj __scheduler__fixture_snapshot__out '.now' "$1" '.trunk' "$__scheduler__fixture_snapshot__trunk" '.merge_requests' "$__scheduler__fixture_snapshot__arr_1"
  println "$__scheduler__fixture_snapshot__out"
}

: <<'PUB_FUN'
Builds an open merge request <iid> whose head <head> is rebased on <base>,
approved at <approved_at>, targeting main, with no priority, no label, no
landing run, and rebasing cleanly. A case changes a field with @set.

  scheduler__fixture_merge_request 12 h1 t1 1789990000
PUB_FUN
scheduler__fixture_merge_request() {
  @obj __scheduler__fixture_merge_request__out \
    '.iid' "$1" \
    '.head' "$2" \
    '.target' main \
    '.base' "$3" \
    '.approved' true \
    '.approved_at' "$4" \
    '.priority' 0 \
    '.label' '' \
    '.run' null \
    '.rebases_cleanly' true
  println "$__scheduler__fixture_merge_request__out"
}

: <<'PUB_FUN'
Builds a landing run of the commit <sha> rebased on <base>, in <status>:
running, success, failed or canceled.

  scheduler__fixture_run h1 t1 running
PUB_FUN
scheduler__fixture_run() {
  @obj __scheduler__fixture_run__out '.sha' "$1" '.base' "$2" '.status' "$3"
  println "$__scheduler__fixture_run__out"
}

: <<'PUB_FUN'
Prints <snapshot> with the merge request <mr> added to its open ones.

  scheduler__fixture_with "$snapshot" "$(scheduler__fixture_merge_request 12 h1 t1 1789990000)"
PUB_FUN
scheduler__fixture_with() {
  @arr __scheduler__fixture_with__arr_2
  @get __scheduler__fixture_with__get_3 "$1" '.merge_requests' "$__scheduler__fixture_with__arr_2"
  @push __scheduler__fixture_with__requests "$__scheduler__fixture_with__get_3" "$2"
  @set __scheduler__fixture_with__out "$1" '.merge_requests' "$__scheduler__fixture_with__requests"
  println "$__scheduler__fixture_with__out"
}
