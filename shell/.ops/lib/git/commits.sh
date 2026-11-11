#!/bin/sh

import "$SHELLOPS_DIR/lib/git/api.sh"

: <<'MODULE'
Reading commits as git relates them: which ones a branch holds beyond
another, whether one descends from another, the identity of the change one
carries, the message one carries, and the source a `cherry-pick -x` recorded
in its message.
MODULE

: <<'PUB_FUN'
Prints the commits reachable from <branch> and not from <target>, oldest
first, as a struct array of SHAs; the empty array when the target holds
everything the branch does.

  git__side_commits released main  ->  ["3f1c...", "9a02..."]

Usage: git__side_commits <branch> <target>
PUB_FUN
git__side_commits() {
  __git__side_commits__listed="$(git -C "$(__git__repo)" rev-list --reverse "$1" "^$2")" || return 1
  if ! @defined "$__git__side_commits__listed"; then
    @arr __git__side_commits__out
    println "$__git__side_commits__out"
    return 0
  fi

  @split __git__side_commits__out "$__git__side_commits__listed"
  println "$__git__side_commits__out"
}

: <<'PUB_FUN'
Prints the full message of <sha>: the subject, a blank line, the body.

  git__commit_message HEAD
    ->  Merge branch 'fix/tool' into 'main'
        (blank)
        See merge request org/tool!7

Usage: git__commit_message <sha>
PUB_FUN
git__commit_message() {
  git -C "$(__git__repo)" log -1 --format=%B "$1"
}

: <<'PUB_FUN'
Prints the commit that <sha>'s cherry-pick trailer names, the line
`cherry-pick -x` appends to a message; nothing when the message carries none.

Usage: git__cherry_pick_source <sha>
PUB_FUN
git__cherry_pick_source() {
  git__commit_message "$1" \
    | awk -f "$SHELLOPS_DIR/lib/git/cherry_pick_source.awk"
}

: <<'PUB_FUN'
Prints true when <ancestor> is reachable from <descendant>, false otherwise.

Usage: git__is_ancestor <ancestor> <descendant>
PUB_FUN
git__is_ancestor() {
  @succeeds __git__is_ancestor__out git -C "$(__git__repo)" merge-base --is-ancestor "$1" "$2"
  println "$__git__is_ancestor__out"
}

: <<'PUB_FUN'
Prints the stable patch id of one commit: the identity of its change, which
survives a rebase or a cherry-pick that resolved cleanly.

Usage: git__patch_id <sha>
PUB_FUN
git__patch_id() {
  git -C "$(__git__repo)" diff-tree -p "$1" \
    | git -C "$(__git__repo)" patch-id --stable \
    | cut -d' ' -f1
}

: <<'PUB_FUN'
Prints the stable patch ids of every non-merge commit in a revision range, as
a struct array; the empty array for an empty range.

  git__patch_ids main ^released  ->  ["e1b6...", "77a0..."]

Usage: git__patch_ids <rev-list arguments...>
PUB_FUN
git__patch_ids() {
  __git__patch_ids__listed="$(git -C "$(__git__repo)" log -p --no-merges "$@" \
    | git -C "$(__git__repo)" patch-id --stable \
    | cut -d' ' -f1)" || return 1
  if ! @defined "$__git__patch_ids__listed"; then
    @arr __git__patch_ids__out
    println "$__git__patch_ids__out"
    return 0
  fi

  @split __git__patch_ids__out "$__git__patch_ids__listed"
  println "$__git__patch_ids__out"
}

: <<'PUB_FUN'
Prints the first parent of <sha>; nothing for a root commit, which has none.
Non-zero when <sha> resolves to no commit.

  git__commits__parent_of 9a02...  ->  3f1c...

Usage: git__commits__parent_of <sha>
PUB_FUN
git__commits__parent_of() {
  __git__commits__parent_of__line="$(git -C "$(__git__repo)" rev-list --parents -n 1 "$1")" || return 1
  println "$__git__commits__parent_of__line" | cut -d' ' -f2 -s
}

: <<'PUB_FUN'
Prints the commit <a> and <b> last met at, the base a head that forked from a
branch is rebased on. Non-zero, printing nothing, when either resolves to no
commit the clone holds, or when they share no history at all.

  git__commits__fork_point feat/lower origin/main  ->  7d681d79...

Usage: git__commits__fork_point <a> <b>
PUB_FUN
git__commits__fork_point() {
  git -C "$(__git__repo)" merge-base "$1" "$2" 2>/dev/null
}

: <<'PUB_FUN'
Prints the commits in a revision range whose first parent is <parent>, as a
struct array of SHAs; the empty array when none is. A version record's twin
on a branch is found this way: the two share a parent.

  git__commits__with_parent 3f1c... main ^released  ->  ["9a02..."]

Usage: git__commits__with_parent <parent> <rev-list arguments...>
PUB_FUN
git__commits__with_parent() {
  __git__commits__with_parent__parent="$1"
  shift
  __git__commits__with_parent__lines="$(git -C "$(__git__repo)" rev-list --parents "$@")" || return 1
  __git__commits__with_parent__listed="$(println "$__git__commits__with_parent__lines" \
    | awk -v parent="$__git__commits__with_parent__parent" -f "$SHELLOPS_DIR/lib/git/commits_with_parent.awk"
  )"
  if ! @defined "$__git__commits__with_parent__listed"; then
    @arr __git__commits__with_parent__out
    println "$__git__commits__with_parent__out"
    return 0
  fi

  @split __git__commits__with_parent__out "$__git__commits__with_parent__listed"
  println "$__git__commits__with_parent__out"
}

: <<'PUB_FUN'
Rewrites the commit at HEAD in place: the same parent, the message <message>,
and exactly <paths> as the working tree holds them, whatever else the index
or the tree carries. Non-zero when git refuses.

Usage: git__commits__amend "chore: release 1.2.0-rc.1" '["manifest.json"]'
PUB_FUN
git__commits__amend() {
  @apply \
    git -C "$(__git__repo)" commit --quiet --amend \
    -m "$1" \
    -- \
    "$2"
}

: <<'PUB_FUN'
Prints the value of the trailer <token> in <sha>'s message, the last one when
the message carries several; nothing when it carries none. Non-zero when
<sha> resolves to no commit.

  git__commits__trailer 9a02... Release-Record  ->  1.2.0-rc.1

Usage: git__commits__trailer <sha> <token>
PUB_FUN
git__commits__trailer() {
  __git__commits__trailer__message="$(git -C "$(__git__repo)" log -1 --format=%B "$1")" || return 1

  println "$__git__commits__trailer__message" \
    | git interpret-trailers --parse \
    | awk -v token="$2" -f "$SHELLOPS_DIR/lib/git/trailer_value.awk"
}

: <<'PUB_FUN'
Writes a commit carrying the tree of <tree_ref> on top of the <parent>s
given, in order, into the object database, and prints it: a root commit
when no parent is given. The checkout keeps the branch, index and working
tree it had, and the commit is not signed. Non-zero when <tree_ref>
resolves to no tree or git refuses.

  git__commits__graft 3f1c... "certified: 0.67.0-6.rc" 7d68... 3f1c...  ->  9a02...

args:
  $1     The ref whose tree the commit carries
  $2     The message
  $3...  The parents, oldest first; none for a root commit
PUB_FUN
git__commits__graft() {
  __git__commits__graft__tree="$(git -C "$(__git__repo)" rev-parse --verify --quiet "${1}^{tree}")" || return 1
  __git__commits__graft__message="$2"
  shift 2
  __git__commits__graft__parents=""
  for __git__commits__graft__parent in "$@"; do
    __git__commits__graft__parents="$__git__commits__graft__parents -p $__git__commits__graft__parent"
  done
  # shellcheck disable=SC2086 # the parents are commit ids, split into -p pairs on purpose
  git -C "$(__git__repo)" commit-tree --no-gpg-sign "$__git__commits__graft__tree" $__git__commits__graft__parents -m "$__git__commits__graft__message"
}

: <<'PUB_FUN'
Writes a commit holding no files into the object database and prints it:
<message> on top of <parent>, or a root commit when <parent> is empty. The
checkout keeps the branch, index and working tree it had, and the commit is
not signed, so a lease or a marker needs no key. Non-zero when git refuses.

  git__commits__empty "lease landing: dispatcher-1 tick tick-42" 3f1c...  ->  9a02...

args:
  $1  The message
  $2  The parent, or empty for none
PUB_FUN
git__commits__empty() {
  __git__commits__empty__tree="$(git -C "$(__git__repo)" hash-object -w -t tree /dev/null)" || return 1

  if @defined "$2"; then
    git -C "$(__git__repo)" commit-tree --no-gpg-sign "$__git__commits__empty__tree" -p "$2" -m "$1"
  else
    git -C "$(__git__repo)" commit-tree --no-gpg-sign "$__git__commits__empty__tree" -m "$1"
  fi
}

: <<'PUB_FUN'
Prints the committer date of <sha> as whole seconds since the epoch, the
clock a lease's age is measured from. Non-zero when <sha> resolves to no
commit.

  git__commits__committed_at 9a02...  ->  1790000000
PUB_FUN
git__commits__committed_at() {
  git -C "$(__git__repo)" log -1 --format=%ct "$1"
}

: <<'PUB_FUN'
Prints the files <sha> changes against its first parent, as a struct array
of repository-relative paths; the empty array for a commit that changes
none. A root commit's files are everything it adds, and a merge's are what
it brought onto its first parent. Non-zero when <sha> resolves to no commit.

  git__commit_files 9a02...  ->  [".ops/lock", "engine/Cargo.lock"]

Usage: git__commit_files <sha>
PUB_FUN
git__commit_files() {
  __git__commit_files__listed="$(git -C "$(__git__repo)" show --format= --name-only --first-parent -m "$1")" || return 1
  if ! @defined "$__git__commit_files__listed"; then
    @arr __git__commit_files__out
    println "$__git__commit_files__out"
    return 0
  fi

  @split __git__commit_files__out "$__git__commit_files__listed"
  println "$__git__commit_files__out"
}
