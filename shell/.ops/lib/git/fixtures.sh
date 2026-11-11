#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
The on-disk git shapes a test needs standing up before it can assert anything.

A fixture is domain knowledge -- what a repository looks like on disk, and what
has to be there alongside it for a case to mean something -- so it belongs to
the module that owns the domain rather than to whichever suite needed it first.
It sits beside api.sh instead of inside it so importing the git module does not
hand production code a set of fixtures.

Nothing here knows what runs it: paths are given, not read out of a harness
variable.
FRAGMENT

: <<'PUB_FUN'
Builds a repository at <dir> holding one commit, and tags that commit with
every name that follows, in the order given. Prints <dir>.

The names are taken as written, so a case about tag prefixes gives the tags
the form it means to test.

Usage: git__fixture_tagged_repo "$BATS_TEST_TMPDIR/repo" v3.0.0-dev.33 v3.0.0-dev.34
PUB_FUN
git__fixture_tagged_repo() {
  __git__fixture_tagged_repo__dir="$1"
  shift

  git init -q -b main "$__git__fixture_tagged_repo__dir"
  git -C "$__git__fixture_tagged_repo__dir" config user.name test
  git -C "$__git__fixture_tagged_repo__dir" config user.email test@example.com
  git -C "$__git__fixture_tagged_repo__dir" config commit.gpgSign false
  git -C "$__git__fixture_tagged_repo__dir" config tag.gpgSign false
  git -C "$__git__fixture_tagged_repo__dir" commit -q --allow-empty -m seed

  # A signing configuration around the test would turn these into annotated
  # tags, which need a message; a release tag is a plain ref pointing at a
  # commit, and that is what the guard is given to read.
  for __git__fixture_tagged_repo__tag in "$@"; do
    git -C "$__git__fixture_tagged_repo__dir" \
      -c tag.gpgSign=false \
      tag "$__git__fixture_tagged_repo__tag"
  done

  println "$__git__fixture_tagged_repo__dir"
}

: <<'PUB_FUN'
Builds a repository at <dir> whose one commit records a submodule at the
relative path <path>, backed by a second repository at <dir>.sub that holds
one commit. Prints <dir>. The caller allows the file protocol around the
test (protocol.file.allow=always), since git refuses a local submodule
otherwise.

Usage: git__fixture_repo_with_submodule "$BATS_TEST_TMPDIR/main" vendor/sub
PUB_FUN
git__fixture_repo_with_submodule() {
  __git__fixture_repo_with_submodule__dir="$1"
  __git__fixture_repo_with_submodule__path="$2"
  __git__fixture_repo_with_submodule__sub="$1.sub"

  git init -q -b main "$__git__fixture_repo_with_submodule__sub"
  __git__fixture_identity "$__git__fixture_repo_with_submodule__sub"
  git -C "$__git__fixture_repo_with_submodule__sub" commit -q --allow-empty -m seed

  git init -q -b main "$__git__fixture_repo_with_submodule__dir"
  __git__fixture_identity "$__git__fixture_repo_with_submodule__dir"
  git -C "$__git__fixture_repo_with_submodule__dir" commit -q --allow-empty -m seed
  git -C "$__git__fixture_repo_with_submodule__dir" submodule add -q \
    "$__git__fixture_repo_with_submodule__sub" \
    "$__git__fixture_repo_with_submodule__path"
  git -C "$__git__fixture_repo_with_submodule__dir" commit -q -m submodule

  println "$__git__fixture_repo_with_submodule__dir"
}

: <<'PUB_FUN'
Builds a bare repository at <dir> standing in for a forge, its main holding
one commit, and prints <dir>. A clone of it (git__fixture_clone) is what a
tick works in, and two clones are two ticks.

Usage: git__fixture_bare_remote "$BATS_TEST_TMPDIR/forge.git"
PUB_FUN
git__fixture_bare_remote() {
  __git__fixture_bare_remote__seed="$1.seed"

  git init -q --bare -b main "$1"
  git init -q -b main "$__git__fixture_bare_remote__seed"
  __git__fixture_identity "$__git__fixture_bare_remote__seed"
  git -C "$__git__fixture_bare_remote__seed" commit -q --allow-empty -m seed
  git -C "$__git__fixture_bare_remote__seed" push -q "$1" main
  rm -rf "$__git__fixture_bare_remote__seed"

  println "$1"
}

: <<'PUB_FUN'
Clones the repository at <remote> to <dir>, as origin, with an identity that
lets the clone commit, and prints <dir>.

Usage: git__fixture_clone "$forge" "$BATS_TEST_TMPDIR/tick-a"
PUB_FUN
git__fixture_clone() {
  git clone -q "$1" "$2"
  __git__fixture_identity "$2"

  println "$2"
}

: <<'PUB_FUN'
Publishes the files the clone at <dir> holds in its working tree as the
branch <branch> on its origin: one commit with no parent, holding those
files and nothing else. Prints the commit and leaves the clone on the
branch. With git__fixture_bare_remote and git__fixture_clone, this stands
up a remote whose branch holds exactly a given set of files.

Usage: git__fixture_orphan_branch "$clone" store
PUB_FUN
git__fixture_orphan_branch() {
  git -C "$1" checkout -q --orphan "$2"
  git -C "$1" add -A
  git -C "$1" commit -q --allow-empty -m "$2"
  git -C "$1" push -q origin "$2"

  git -C "$1" rev-parse HEAD
}

: <<'FUN'
Gives the repository at <dir> a test identity and no signing, so a commit or
a tag needs no key and names no person.
FUN
__git__fixture_identity() {
  git -C "$1" config user.name test
  git -C "$1" config user.email test@example.com
  git -C "$1" config commit.gpgSign false
  git -C "$1" config tag.gpgSign false
}
