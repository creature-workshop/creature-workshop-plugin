#!/bin/sh

import "$SHELLOPS_DIR/lib/git/api.sh"

: <<'MODULE'
Branches on a remote: reading where one points, and moving one to a commit
under a lease on what the remote holds, so a branch that moved since it was
read rejects the push rather than being overwritten.
MODULE

: <<'PUB_FUN'
Prints the commit <branch> points at on <remote>, fetched fresh; nothing when
the remote has no such branch.

Usage: git__remote_branch_tip <remote> <branch>
PUB_FUN
git__remote_branch_tip() {
  if ! git -C "$(__git__repo)" fetch --quiet "$1" "refs/heads/$2" 2>/dev/null; then
    return 0
  fi

  git -C "$(__git__repo)" rev-parse FETCH_HEAD
}

: <<'PUB_FUN'
Points <branch> on <remote> at <target>, forcing the move, with a lease on
<current>: the push is rejected when the remote's branch is not at <current>
any more. An empty <current> is the lease that the branch does not exist yet,
so the push creates it. <options>, when given, are push options the forge
reads, each sent as --push-option; left out, none is sent. Non-zero when the
push is rejected.

Usage: git__force_move_branch <remote> <branch> <current> <target> [<options>]

  git__force_move_branch origin main 7d681d79 HEAD '["ci.skip"]'
PUB_FUN
git__force_move_branch() {
  __git__force_move_branch__options="${5:-}"
  if ! @defined "$__git__force_move_branch__options"; then
    @arr __git__force_move_branch__options
  fi
  @map __git__force_move_branch__flags __git__branches__push_option_flag "$__git__force_move_branch__options"

  @apply \
    git -C "$(__git__repo)" push --quiet \
    "--force-with-lease=refs/heads/${2}:${3}" \
    "$1" \
    "${4}:refs/heads/${2}" \
    "$__git__force_move_branch__flags"
}

: <<'FUN'
@map callback: the git flag carrying the wrapped push option.

  __git__branches__push_option_flag '"ci.skip"'  ->  --push-option=ci.skip
FUN
__git__branches__push_option_flag() {
  @unwrap __git__branches__push_option_flag__unwrap_1 "$1"
  printf -- '--push-option=%s\n' "$__git__branches__push_option_flag__unwrap_1"
}
