#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh"

: <<'MODULE'
Replaying a branch's commits onto another commit, and asking whether they go
cleanly, in a clone that keeps the branch, index and working tree it had.

Both questions are one replay, run in a scratch worktree the caller never
sees. The replay signs nothing: the commits are the author's, so the clone
needs no signing key, and two replays of the same head onto the same commit
write the same commit.
MODULE

: <<'PUB_FUN'
Prints the commit <head> becomes when its commits since it forked from <onto>
are replayed onto <onto>; <onto>'s own commit when <head> holds nothing it
does not. Non-zero, printing nothing, when a commit conflicts.

  git__rebase__onto feat/lower 7d681d79  ->  9a02f1c3...

args:
  $1  The head to replay, a commit or a branch
  $2  The commit to replay it onto
PUB_FUN
git__rebase__onto() {
  __git__rebase__onto__scratch="$(mktemp -d)" || return 1
  __git__rebase__onto__status=0
  __git__rebase__onto__commit="$(__git__rebase__replay "$1" "$2" "$__git__rebase__onto__scratch/tree")" \
    || __git__rebase__onto__status=$?
  git__worktree_remove "$__git__rebase__onto__scratch/tree"
  rm -rf "$__git__rebase__onto__scratch"

  if [ "$__git__rebase__onto__status" -ne 0 ]; then
    return "$__git__rebase__onto__status"
  fi
  println "$__git__rebase__onto__commit"
}

: <<'PUB_FUN'
Prints true when <head> replays onto <onto> with no conflict, false when a
commit conflicts. Non-zero when either resolves to no commit, so a head the
clone has not fetched never reads as a conflict.

  git__rebase__clean feat/lower origin/main  ->  true

args:
  $1  The head to replay, a commit or a branch
  $2  The commit to replay it onto
PUB_FUN
git__rebase__clean() {
  git__commit_of "$1" > /dev/null || return 1
  git__commit_of "$2" > /dev/null || return 1

  __git__rebase__clean__status=0
  git__rebase__onto "$1" "$2" > /dev/null || __git__rebase__clean__status=$?

  @succeeds __git__rebase__clean__out [ "$__git__rebase__clean__status" -eq 0 ]
  println "$__git__rebase__clean__out"
}

: <<'FUN'
Prints the commit <head> becomes when replayed onto <onto>, in a detached
worktree at <dir>: the fork point is where the two last met, and the commits
above it are replayed there. Leaves the worktree behind for the caller to
remove, and abandons a replay that conflicts so the worktree can go. Non-zero
when a commit conflicts or git refuses.
FUN
__git__rebase__replay() {
  __git__rebase__replay__head="$1"
  __git__rebase__replay__onto="$2"
  __git__rebase__replay__dir="$3"

  git__worktree_checkout "$__git__rebase__replay__dir" "$__git__rebase__replay__head" || return 1
  __git__rebase__replay__fork="$(git__commits__fork_point \
    "$__git__rebase__replay__head" \
    "$__git__rebase__replay__onto"
  )" || return 1

  __git__rebase__replay__clean="$(__git__rebase__replays \
    "$__git__rebase__replay__dir" \
    "$__git__rebase__replay__onto" \
    "$__git__rebase__replay__fork"
  )"
  if ! @is_true "$__git__rebase__replay__clean"; then
    __git__rebase__abandon "$__git__rebase__replay__dir"
    return 1
  fi

  __git__rebase__head_of "$__git__rebase__replay__dir"
}

: <<'FUN'
Prints true when the commits above <fork> at the head of the worktree at
<dir> replay onto <onto> with no conflict, false when one conflicts or git
refuses the replay. A replay that conflicts is left in progress, for the
caller to abandon.

args:
  $1  The worktree the replay runs in
  $2  The commit to replay onto
  $3  The fork point, below which nothing is replayed
FUN
__git__rebase__replays() {
  __git__rebase__replays__status=0
  git -C "$1" -c commit.gpgSign=false rebase \
    --onto "$2" \
    "$3" \
    HEAD \
    > /dev/null \
    2>&1 \
    || __git__rebase__replays__status=$?

  @succeeds __git__rebase__replays__out [ "$__git__rebase__replays__status" -eq 0 ]
  println "$__git__rebase__replays__out"
}

: <<'FUN'
Abandons the replay in progress in the worktree at <dir>, so its head is back
where the replay started and the worktree can be removed.
FUN
__git__rebase__abandon() {
  git -C "$1" rebase --abort > /dev/null 2>&1
}

: <<'FUN'
Prints the commit the worktree at <dir> has checked out.
FUN
__git__rebase__head_of() {
  git -C "$1" rev-parse HEAD
}
