#!/bin/sh
import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh" \
  "$SHELLOPS_DIR/lib/git/branches.sh" \
  "$SHELLOPS_DIR/lib/releases/files.sh" \
  "$SHELLOPS_DIR/lib/releases/record/api.sh" \
  "$SHELLOPS_DIR/lib/releases/record/commit.sh"

: <<'MODULE'
certified: the branch on the box that publishes the top record of each
finished attempt (ADR.4@global, ADR.44@shellops). It advances by one
commit per attempt, carrying the top record's tree, whose parents are the
previous certified head and the record's commit; the first advance has the
record alone as its parent. Nothing merges textually, nothing is
force-pushed, only the release bot writes it, and it never merges back.

An advance is a write for releases__record__publish, so the top tier's tag
and certified land in one atomic push or not at all: the tier is never
earned without the branch following, and the branch never moves without
the tier. Before the write is made the record passes the stamp check: its
parent is on the trunk, and its tree differs from the parent's in the
version files alone. A record that fails it is refused and certified does
not move.

  releases__certified__write "$record"
    ->  {"ref": "refs/heads/certified", "expected": "7d68...", "commit": "9a02..."}
MODULE

# CONST: The branch certified is published on.
__releases__certified__BRANCH="certified"

# CONST: The remote certified is read from and published to.
__releases__certified__REMOTE="origin"

: <<'PUB_FUN'
Prints the write that advances certified to the <record>, for
releases__record__publish: the branch's ref, the commit origin holds it at,
empty when origin has no certified yet, and the new commit, carrying the
record's tree on top of that head and the record's commit. Fails when the
record fails the stamp check, naming the reason, or when origin cannot be
asked.

  releases__certified__write "$record"
    ->  {"ref": "refs/heads/certified", "expected": "7d68...", "commit": "9a02..."}

Usage: releases__certified__write <record>
PUB_FUN
releases__certified__write() {
  releases__certified__assert_stamp "$1" || return 1
  __releases__certified__write__head="$(git__remote_branch_tip "$__releases__certified__REMOTE" "$__releases__certified__BRANCH")" || return 1
  __releases__certified__write__commit="$(__releases__certified__advance "$1" "$__releases__certified__write__head")" || return 1
  @obj __releases__certified__write__out \
    '.ref' "refs/heads/$__releases__certified__BRANCH" \
    '.expected' "$__releases__certified__write__head" \
    '.commit' "$__releases__certified__write__commit"
  println "$__releases__certified__write__out"
}

: <<'FUN'
Writes the commit that advances certified from <head> to the <record> and
prints it: the record's tree, on the previous head and the record's commit,
or on the record's commit alone when <head> is empty, the first advance.
FUN
__releases__certified__advance() {
  @get __releases__certified__advance__commit "$1" '.commit'
  @get __releases__certified__advance__get_1 "$1" '.name'
  __releases__certified__advance__message="certified: $__releases__certified__advance__get_1"
  if @defined "$2"; then
    git__commits__graft "$__releases__certified__advance__commit" "$__releases__certified__advance__message" "$2" "$__releases__certified__advance__commit"
    return
  fi
  git__commits__graft "$__releases__certified__advance__commit" "$__releases__certified__advance__message" "$__releases__certified__advance__commit"
}

: <<'PUB_FUN'
Passes quietly when the <record> carries the stamp (ADR.44@shellops): its
candidate is on the trunk, and its tree differs from the candidate's in the
version files alone. Fails naming the reason otherwise, or when the trunk
cannot be read off origin.

Usage: releases__certified__assert_stamp "$record"
PUB_FUN
releases__certified__assert_stamp() {
  @get __releases__certified__assert_stamp__candidate "$1" '.candidate'
  @get __releases__certified__assert_stamp__commit "$1" '.commit'
  __releases__certified__assert_stamp__trunk="$(git__remote_branch_tip "$__releases__certified__REMOTE" "$(git__default_branch)")" || return 1
  if ! @is_true "$(git__is_ancestor "$__releases__certified__assert_stamp__candidate" "$__releases__certified__assert_stamp__trunk")"; then
    @get __releases__certified__assert_stamp__get_2 "$1" '.name'
    error "certified: the record $__releases__certified__assert_stamp__get_2 sits on ${__releases__certified__assert_stamp__candidate}, which is not on the trunk; certified does not move."
    return 1
  fi
  __releases__certified__assert_stamp__files="$(releases__release_files)" || return 1
  if ! @is_true "$(git__trees_match_outside "$__releases__certified__assert_stamp__candidate" "$__releases__certified__assert_stamp__commit" "$__releases__certified__assert_stamp__files")"; then
    @get __releases__certified__assert_stamp__get_3 "$1" '.name'
    error "certified: the record $__releases__certified__assert_stamp__get_3 differs from its candidate outside the version files; certified does not move."
    return 1
  fi
}
