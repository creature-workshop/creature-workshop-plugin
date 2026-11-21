#!/bin/sh

import "$SHELLOPS_DIR/lib/git/api.sh"

: <<'MODULE'
Tags as refs: which ones the repository holds, which sit on a commit, whether
a branch reaches one, and dropping one here and on a remote.
MODULE

: <<'PUB_FUN'
Prints every tag the repository holds, as a struct array of names; the empty
array when it holds none.

  git__tags  ->  ["1.2.0-dev.9", "1.2.0-rc.1", "nightly"]

Usage: git__tags
PUB_FUN
git__tags() {
  __git__tags__listed="$(git -C "$(__git__repo)" tag -l)" || return 1
  if ! @defined "$__git__tags__listed"; then
    @arr __git__tags__out
    println "$__git__tags__out"
    return 0
  fi

  @split __git__tags__out "$__git__tags__listed"
  println "$__git__tags__out"
}

: <<'PUB_FUN'
Prints the tags pointing at the commit <ref> names, as a struct array; the
empty array when none does. Non-zero when <ref> resolves to no commit.

  git__tags_at HEAD  ->  ["1.2.0-dev.9", "v1.2.0-dev.9"]

Usage: git__tags_at <ref>
PUB_FUN
git__tags_at() {
  __git__tags_at__commit="$(git__commit_of "$1")" || return 1
  __git__tags_at__listed="$(git -C "$(__git__repo)" tag --points-at "$__git__tags_at__commit")" || return 1
  if ! @defined "$__git__tags_at__listed"; then
    @arr __git__tags_at__out
    println "$__git__tags_at__out"
    return 0
  fi

  @split __git__tags_at__out "$__git__tags_at__listed"
  println "$__git__tags_at__out"
}

: <<'PUB_FUN'
Prints the branches, local and remote-tracking, whose history holds the
commit <ref> names, as a struct array; the empty array when none does.
Non-zero when <ref> resolves to no commit.

The listing is read whole rather than piped into a reader that stops at the
first line: a reader closing the pipe early hands git a broken pipe, which
under pipefail reads as no branch at all.

  git__branches_containing 1.2.0-dev.9  ->  ["main", "origin/main"]

Usage: git__branches_containing <ref>
PUB_FUN
git__branches_containing() {
  __git__branches_containing__commit="$(git__commit_of "$1")" || return 1
  __git__branches_containing__listed="$(git -C "$(__git__repo)" branch -a --format='%(refname:short)' --contains "$__git__branches_containing__commit")" || return 1
  if ! @defined "$__git__branches_containing__listed"; then
    @arr __git__branches_containing__out
    println "$__git__branches_containing__out"
    return 0
  fi

  @split __git__branches_containing__out "$__git__branches_containing__listed"
  println "$__git__branches_containing__out"
}

: <<'PUB_FUN'
Prints true when some branch, local or remote-tracking, reaches the commit
<tag> points at, and false when none does. Non-zero when <tag> points at no
commit.

  git__tag_reached 1.2.0-dev.9  ->  true    (on the trunk)
  git__tag_reached 1.2.0-rc.1   ->  false   (on a record off it)

Usage: git__tag_reached <tag>
PUB_FUN
git__tag_reached() {
  __git__tag_reached__branches="$(git__branches_containing "$1")" || return 1

  if @len __git__tag_reached__len_1 "$__git__tag_reached__branches"; [ "$__git__tag_reached__len_1" -gt 0 ]; then
    @true __git__tag_reached__out
    println "$__git__tag_reached__out"
  else
    @false __git__tag_reached__out
    println "$__git__tag_reached__out"
  fi
}

: <<'PUB_FUN'
Deletes <tag> from this clone. A tag the clone does not hold is nothing to do
and succeeds.

Usage: git__tag_delete <tag>
PUB_FUN
git__tag_delete() {
  if ! git__ref_exists "refs/tags/$1"; then
    return 0
  fi

  git -C "$(__git__repo)" tag -d "$1" >/dev/null
}

: <<'PUB_FUN'
Deletes <tag> on <remote>. Non-zero when the remote refuses.

Usage: git__tag_delete_remote <remote> <tag>
PUB_FUN
git__tag_delete_remote() {
  git -C "$(__git__repo)" push --quiet "$1" ":refs/tags/$2"
}

: <<'PUB_FUN'
Tags the commit <ref> names, HEAD when none is given, with the annotated
tag <tag>, its message the tag's name; signed when the repository is
configured to sign tags. Non-zero when git refuses, a tag of that name
already held included.

Usage: git__tag_annotate 1.2.0-4.dev
PUB_FUN
git__tag_annotate() {
  git -C "$(__git__repo)" tag -a "$1" -m "$1" "${2:-HEAD}"
}
