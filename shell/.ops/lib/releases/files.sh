#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/ecosystems/api.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh"

: <<'MODULE'
The files a release rewrites: the lock, which carries the release record
(ADR 000049), and every version file the declared ecosystems name. The
release commit names exactly this set, and a branch move vouches for a
rewritten version record by the same set (ADR 000044), so the set is
defined once, here, for both. A file joins it only by an ADR.
MODULE

# CONST: The lock, where the release record lives, relative to the repository's root.
__releases__files__LOCK='.ops/lock'

: <<'PUB_FUN'
Returns the files a release writes, as an array of paths: the lock, then
every version file the declared ecosystems name.

  releases__release_files  ->  [".ops/lock"]                       none declared
  releases__release_files  ->  [".ops/lock", "engine/Cargo.lock", "/p/engine/Cargo.toml"]

The release commit names exactly this set. Committing --all would run git add -A
and sweep whatever the job left untracked in the tree, such as the toolchain
it provisioned to run the sync, into the release.
PUB_FUN
releases__release_files() {
  __releases__release_files__ecosystems="$(ecosystems__version_files)" || return 1

  @arr __releases__release_files__arr_1 "$__releases__files__LOCK"
  @concat __releases__release_files__out "$__releases__release_files__arr_1" "$__releases__release_files__ecosystems"
  println "$__releases__release_files__out"
}

: <<'PUB_FUN'
Prints the commits after <base> up to <head> that mix a version file with a
file outside the set, as a struct array of {commit, files}, files being the
ones outside it; the empty array when every commit that touches a version
file touches the version files alone. That is check B (ADR.17@global): the
version moves through one commit on an approved merge request, and that
commit carries nothing else, so the set stays the one place a version is
written and a commit past it reads as any other.

  releases__commits_mixing_version_files 7d681d79 HEAD  ->  [{"commit": "3f1c...", "files": ["README.md"]}]
  releases__commits_mixing_version_files 7d681d79 HEAD  ->  []

Usage: releases__commits_mixing_version_files <base> <head>
PUB_FUN
releases__commits_mixing_version_files() {
  __releases__commits_mixing_version_files__files="$(releases__release_files)" || return 1
  @map __releases__commits_mixing_version_files__relative __releases__files__relative "$__releases__commits_mixing_version_files__files"
  __releases__commits_mixing_version_files__commits="$(git__side_commits "$2" "$1")" || return 1

  @arr __releases__commits_mixing_version_files__arr_2
  @reduce __releases__commits_mixing_version_files__out __releases__files__mixing "$__releases__commits_mixing_version_files__commits" "$__releases__commits_mixing_version_files__arr_2" "$__releases__commits_mixing_version_files__relative"
  println "$__releases__commits_mixing_version_files__out"
}

: <<'FUN'
@map callback: the wrapped version file <path> relative to the project, as
git names it, whether the ecosystem named it from the project's root or
from the filesystem's.

  __releases__files__relative '"/p/engine/Cargo.toml"'  ->  engine/Cargo.toml   (PROJ=/p)
FUN
__releases__files__relative() {
  @unwrap __releases__files__relative__path "$1"
  println "${__releases__files__relative__path#"$PROJ"/}"
}

: <<'FUN'
@reduce callback: prints <acc> with {commit, files} for the wrapped commit
<sha> when it touches one of the version files <version_files> together
with a file outside them, the files being those outside; <acc> unchanged
otherwise.
FUN
__releases__files__mixing() {
  @unwrap __releases__files__mixing__commit "$2"
  __releases__files__mixing__touched="$(git__commit_files "$__releases__files__mixing__commit")" || return 1
  @difference __releases__files__mixing__outside "$__releases__files__mixing__touched" "$3"

  if @intersect __releases__files__mixing__intersect_3 "$__releases__files__mixing__touched" "$3"; @empty "$__releases__files__mixing__intersect_3" || @empty "$__releases__files__mixing__outside"; then
    println "$1"
    return 0
  fi

  @obj __releases__files__mixing__obj_4 '.commit' "$__releases__files__mixing__commit" '.files' "$__releases__files__mixing__outside"
  @push __releases__files__mixing__out "$1" "$__releases__files__mixing__obj_4"
  println "$__releases__files__mixing__out"
}
