#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/branches.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/git/forge.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
What the worktree repository does (worktree.repository.op.sh beside this
file): a checkout is a linked worktree of the clone the program runs in,
detached at the commit the ref points at, read fresh from the remote the
repository names, or from the clone's own refs when it names none. A
repository on another forge has the clone readied for it first
(lib/git/forge.sh). An update moves the ref under a lease on the
token the checkout printed, so a ref another update moved meanwhile is
refused; a force moves it under a lease on whatever it holds now. A commit
is made through shellops' git-commit, as the author given, and commits
nothing when nothing changed. An archive is the checkout's commit as files,
through git archive.
FRAGMENT

: <<'FUN'
Prints the remote the repository <repository> names, the clone readied for
it, or nothing for a repository that names none.
FUN
__git__worktree_repository__remote() {
  if @get __git__worktree_repository__remote__get_1 "$1" '.remote' ''; @defined "$__git__worktree_repository__remote__get_1"; then
    git__forge__ready "$1"
  fi
}

: <<'FUN'
Prints the commit <ref> points at in <repository>, fetched fresh from its
remote when it names one; nothing when the ref does not exist.

Usage: __git__worktree_repository__tip <repository> <ref>
FUN
__git__worktree_repository__tip() {
  __git__worktree_repository__tip__remote="$(__git__worktree_repository__remote "$1")" || return 1

  if @defined "$__git__worktree_repository__tip__remote"; then
    git__remote_branch_tip "$__git__worktree_repository__tip__remote" "$2"
  else
    git__commit_of "refs/heads/$2" 2>/dev/null || true
  fi
}

: <<'FUN'
Checks <ref> out of <repository> as a detached worktree at <dir>, at its
tip or at a commit holding no files when the repository has no such ref,
and prints the tip, empty when there was none.

Usage: __git__worktree_repository__checkout <repository> <ref> <dir>
FUN
__git__worktree_repository__checkout() {
  __git__worktree_repository__checkout__tip="$(__git__worktree_repository__tip "$1" "$2")" || return 1

  if @defined "$__git__worktree_repository__checkout__tip"; then
    git__worktree_checkout "$3" "$__git__worktree_repository__checkout__tip" || return 1
  else
    git__worktree_checkout "$3" "$(git__commits__empty "start $2" "")" || return 1
  fi

  println "$__git__worktree_repository__checkout__tip"
}

: <<'FUN'
Commits everything under the worktree <dir> as <author> with <email>, under
<message>, through shellops' git-commit, which commits nothing when nothing
changed. The author is set as the repository's identity first.

Usage: __git__worktree_repository__commit <dir> <message> <author> <email>
FUN
__git__worktree_repository__commit() {
  (cd "$1" && "$SHELLOPS_DIR/action" git config "$3" "$4") || return 1
  (cd "$1" && "$SHELLOPS_DIR/cli/git-commit" --all -m "$2")
}

: <<'FUN'
Points <ref> in <repository> at <commit> under a lease on <token>: pushed to
the remote when the repository names one, and moved in the clone otherwise.
An empty token is the lease that the ref does not exist yet.

Usage: __git__worktree_repository__update <repository> <ref> <token> <commit>
FUN
__git__worktree_repository__update() {
  __git__worktree_repository__update__remote="$(__git__worktree_repository__remote "$1")" || return 1

  if @defined "$__git__worktree_repository__update__remote"; then
    git__force_move_branch "$__git__worktree_repository__update__remote" "$2" "$3" "$4"
  else
    git -C "$(__git__worktree_repository__clone)" update-ref "refs/heads/$2" "$4" "$(__git__worktree_repository__expected "$3")"
  fi
}

: <<'FUN'
Points <ref> in <repository> at <commit> under a lease on whatever the ref
holds now, creating it when it has none: the move a promotion makes, which
the caller has already vouched for.

Usage: __git__worktree_repository__force <repository> <ref> <commit>
FUN
__git__worktree_repository__force() {
  __git__worktree_repository__force__current="$(__git__worktree_repository__tip "$1" "$2")" || return 1
  __git__worktree_repository__update "$1" "$2" "$__git__worktree_repository__force__current" "$3"
}

: <<'FUN'
Pushes the tag <tag> this clone holds to the remote <repository> names, and
does nothing for a repository that names none, whose tags are the clone's.
Non-zero when the remote refuses it.

Usage: __git__worktree_repository__tag <repository> <tag>
FUN
__git__worktree_repository__tag() {
  __git__worktree_repository__tag__remote="$(__git__worktree_repository__remote "$1")" || return 1

  if @defined "$__git__worktree_repository__tag__remote"; then
    git__push_tag "$__git__worktree_repository__tag__remote" "$2"
  fi
}

: <<'FUN'
Prints the clone the program runs in, where refs are read and moved.
FUN
__git__worktree_repository__clone() {
  println "${GIT_REPO:-${PROJ:-.}}"
}

: <<'FUN'
Prints the value git update-ref expects a ref to hold: <token>, or the
null commit when the token is empty, which is the lease that the ref does
not exist yet.
FUN
__git__worktree_repository__expected() {
  if @defined "$1"; then
    println "$1"
  else
    printf '%040d\n' 0
  fi
}

: <<'FUN'
Writes the files of the commit the worktree <dir> is at under <out>,
through git archive, so nothing of the repository comes along.

Usage: __git__worktree_repository__archive <dir> <out>
FUN
__git__worktree_repository__archive() {
  __git__worktree_repository__archive__tar="$(mktemp)" || return 1
  mkdir -p "$2" || return 1
  git -C "$1" archive --format=tar HEAD > "$__git__worktree_repository__archive__tar" || return 1
  tar -x -f "$__git__worktree_repository__archive__tar" -C "$2"
  __git__worktree_repository__archive__status=$?
  rm -f "$__git__worktree_repository__archive__tar"
  return "$__git__worktree_repository__archive__status"
}
