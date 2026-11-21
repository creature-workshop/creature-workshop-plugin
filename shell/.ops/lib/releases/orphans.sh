#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/tags.sh" \
  "$SHELLOPS_DIR/lib/releases/record/api.sh" \
  "$SHELLOPS_DIR/lib/releases/record/commit.sh"

: <<'MODULE'
Telling an orphaned tag from a release. A release above dev is recorded on a
commit off the trunk that its tag alone reaches (ADR 000044), so whether a
branch reaches a tag's commit cannot say on its own that the tag is an
orphan: a record is a release wherever it sits.
MODULE

: <<'PUB_FUN'
Prints true when <tag> is an orphan: no branch reaches its commit and the
commit records no release, the shape a force-push leaves behind. A tag some
branch reaches, one on a record, and one that points at no commit at all
answer false.

  releases__tag_is_orphan 1.2.0-rc.1  ->  false   (a record off the trunk)
  releases__tag_is_orphan stray       ->  true    (a dropped commit)

Usage: releases__tag_is_orphan <tag>
PUB_FUN
releases__tag_is_orphan() {
  __releases__tag_is_orphan__commit="$(git__commit_of "$1")" || {
    @false __releases__tag_is_orphan__out
    println "$__releases__tag_is_orphan__out"
    return 0
  }

  if @is_true "$(git__tag_reached "$1")"; then
    @false __releases__tag_is_orphan__out
    println "$__releases__tag_is_orphan__out"
    return 0
  fi

  if @defined "$(releases__record__at "$__releases__tag_is_orphan__commit")"; then
    @false __releases__tag_is_orphan__out
    println "$__releases__tag_is_orphan__out"
    return 0
  fi

  @true __releases__tag_is_orphan__out
  println "$__releases__tag_is_orphan__out"
}
