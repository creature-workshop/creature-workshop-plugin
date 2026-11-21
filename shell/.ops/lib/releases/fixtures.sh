#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/releases/record/api.sh" \
  "$SHELLOPS_DIR/lib/releases/record/commit.sh"

: <<'FRAGMENT'
The on-disk release shapes a test needs standing up before it can assert
anything.

A fixture is domain knowledge -- what a repository looks like once it has
released, and what has to be there alongside it for a case to mean something
-- so it belongs to the module that owns the domain rather than to whichever
suite needed it first. It sits beside api.sh instead of inside it so importing
the releases module does not hand production code a set of fixtures.

Nothing here knows what runs it: paths are given, not read out of a harness
variable.
FRAGMENT

: <<'PUB_FUN'
Builds a repository at <dir> shaped like the end of a certification attempt
(ADR 000044), and prints <dir>.

The trunk, main, carries a landing tagged <dev-tag>. Every <record-tag> that
follows sits on a record off the trunk: a commit whose parent is that landing,
whose tree differs from it in manifest.json alone, and whose message carries
the Release-Record trailer, so no branch reaches it and only its tag does.
The trunk then moves one landing past, untagged, which is where the release
job stands when it reads the tags. Every commit is dated one minute after
the last, so the tags' dates order the way the commits were made.

The names are taken as written, so a case about tag prefixes gives the tags
the form it means to test.

Usage: releases__fixture_attempt_repo "$BATS_TEST_TMPDIR/repo" 1.2.0-dev.9 1.2.0-alpha.1 1.2.0-rc.1 1.2.0
PUB_FUN
releases__fixture_attempt_repo() {
  __releases__fixture_attempt_repo__dir="$1"
  __releases__fixture_attempt_repo__dev_tag="$2"
  shift 2

  __releases__fixture__init "$__releases__fixture_attempt_repo__dir"
  __releases__fixture__landing "$__releases__fixture_attempt_repo__dir" 0 seed
  __releases__fixture__landing "$__releases__fixture_attempt_repo__dir" 1 landing
  __releases__fixture__tag "$__releases__fixture_attempt_repo__dir" "$__releases__fixture_attempt_repo__dev_tag"

  __releases__fixture_attempt_repo__minute=2
  for __releases__fixture_attempt_repo__tag in "$@"; do
    __releases__fixture__record \
      "$__releases__fixture_attempt_repo__dir" \
      "$__releases__fixture_attempt_repo__minute" \
      "$__releases__fixture_attempt_repo__dev_tag" \
      "$__releases__fixture_attempt_repo__tag"
    __releases__fixture_attempt_repo__minute=$((__releases__fixture_attempt_repo__minute + 1))
  done

  __releases__fixture__landing "$__releases__fixture_attempt_repo__dir" "$__releases__fixture_attempt_repo__minute" "next landing"

  println "$__releases__fixture_attempt_repo__dir"
}

: <<'FUN'
Initialises an empty repository at <dir> on main, with an identity and no
signing, so every commit and tag a case makes is plain.
FUN
__releases__fixture__init() {
  git init -q -b main "$1"
  git -C "$1" config user.name test
  git -C "$1" config user.email test@example.com
  git -C "$1" config commit.gpgSign false
  git -C "$1" config tag.gpgSign false
}

: <<'FUN'
Commits a landing on <dir>'s current branch: a change to a file that is not a
version file, so the tree moves the way a merge moves it, at <minute> past
the fixture's epoch, under <message>.
FUN
__releases__fixture__landing() {
  println "$3" >> "$1/file.txt"
  git -C "$1" add file.txt
  __releases__fixture__commit "$1" "$2" "$3"
}

: <<'FUN'
Commits a record of <tag>'s version off the trunk at <minute> past the
fixture's epoch: detached at <dev-tag>'s commit, the lock alone changed to
name the version as its latest, the message carrying the Release-Record
trailer, and the tag on it. Leaves <dir> back on main.
FUN
__releases__fixture__record() {
  __releases__fixture__record__version="${4#v}"

  git -C "$1" checkout -q --detach "$3"
  releases__record__set_latest "$__releases__fixture__record__version" "$1"
  git -C "$1" add .ops/lock
  __releases__fixture__commit \
    "$1" \
    "$2" \
    "$(releases__record__message "$__releases__fixture__record__version")"
  __releases__fixture__tag "$1" "$4"
  git -C "$1" checkout -q main
}

: <<'FUN'
Commits what is staged in <dir> at <minute> past the fixture's epoch, under
<message>. Both dates are set, so the commit's identity and its date are the
same run to run.
FUN
__releases__fixture__commit() {
  __releases__fixture__commit__date="$(printf '2026-01-01T00:%02d:00Z' "$2")"

  GIT_AUTHOR_DATE="$__releases__fixture__commit__date" \
    GIT_COMMITTER_DATE="$__releases__fixture__commit__date" \
    git -C "$1" commit -q -m "$3"
}

: <<'FUN'
Tags <dir>'s HEAD <tag>, as a plain ref: a release tag is a ref pointing at
a commit, and the signing configuration around a test would otherwise make
it an annotated one that needs a message.
FUN
__releases__fixture__tag() {
  git -C "$1" -c tag.gpgSign=false tag "$2"
}
