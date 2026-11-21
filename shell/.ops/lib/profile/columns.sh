#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/profile/_measure.sh"

: <<'MODULE'
The two columns a profile report compares: the merge base against this
head, or, under PROFILE_VARIANT, this head as is against this head under one
NAME=value assignment. The phrases that name the base column for the gate
and for the comment live here too, since what the base column is decides
them.
MODULE

: <<'PUB_FUN'
The NAME=value PROFILE_VARIANT names for the commands to run under, or
nothing.
PUB_FUN
profile__variant() {
  println "${PROFILE_VARIANT:-}"
}

: <<'PUB_FUN'
The merge base the review context names, or nothing outside a review.
PUB_FUN
profile__review_base() {
  println "${FORGE_REVIEW_BASE_SHA:-${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}}"
}

: <<'PUB_FUN'
The columns the report compares, as a struct {base_sha, base, head}: the
merge base against this head, or, under the variant, this head as is
against this head under it.

  $1  The profiling declaration
PUB_FUN
profile__columns() {
  if @defined "$(profile__variant)"; then
    __profile__columns__against_variant "$1"
  else
    __profile__columns__against_base "$1"
  fi
}

: <<'PUB_FUN'
What the base column measures, named for a verdict: the merge base, or,
under the variant, this head without it.
PUB_FUN
profile__base_name() {
  if @defined "$(profile__variant)"; then
    println "this head without $(profile__variant)"
  else
    println "the merge base"
  fi
}

: <<'PUB_FUN'
What a head's count is above when it is above the base column's <count>.

  profile__base_count_phrase 2657  ->  the merge base's 2657
  PROFILE_VARIANT=STRUCTS_BACKEND=silt profile__base_count_phrase 2657  ->  2657 without STRUCTS_BACKEND=silt
PUB_FUN
profile__base_count_phrase() {
  if @defined "$(profile__variant)"; then
    println "$1 without $(profile__variant)"
  else
    println "the merge base's $1"
  fi
}

: <<'PUB_FUN'
How a breach says that a command exits <status> where the base column's
run exited zero.

  profile__exit_phrase 1  ->  exits 1, and 0 on the merge base
  PROFILE_VARIANT=STRUCTS_BACKEND=silt profile__exit_phrase 1  ->  exits 1 under STRUCTS_BACKEND=silt, and 0 without
PUB_FUN
profile__exit_phrase() {
  if @defined "$(profile__variant)"; then
    println "exits $1 under $(profile__variant), and 0 without"
  else
    println "exits $1, and 0 on the merge base"
  fi
}

: <<'PUB_FUN'
The signed difference between the head column's <head> and the base
column's <base>, or "-" when there is no base column.

  profile__delta 2510 2343  ->  -167
  profile__delta 100 120    ->  +20
  profile__delta "" 120     ->  -
PUB_FUN
profile__delta() {
  if ! @defined "$1"; then
    printf -- '-\n'
    return 0
  fi

  profile__delta__diff=$(($2 - $1))
  if [ "$profile__delta__diff" -gt 0 ]; then
    printf '+%d\n' "$profile__delta__diff"
  else
    printf '%d\n' "$profile__delta__diff"
  fi
}

: <<'FUN'
This head's measurements as the head column and the merge base's as the
base column. Without a merge base in context, the base column is empty
and the head is reported alone.

  $1  The profiling declaration
FUN
__profile__columns__against_base() {
  __profile__columns__against_base__head="$(profile__measure__head "$1")" || return 1
  __profile__columns__against_base__sha="$(profile__review_base)"
  @obj __profile__columns__against_base__base
  if @defined "$__profile__columns__against_base__sha"; then
    __profile__columns__against_base__base="$(profile__measure__base "$__profile__columns__against_base__sha" "$1")" || return 1
  else
    log "No merge base in context; reporting this head alone."
  fi

  __profile__columns__of "$__profile__columns__against_base__sha" "$__profile__columns__against_base__base" "$__profile__columns__against_base__head"
}

: <<'FUN'
This head's measurements as is as the base column and under the variant
as the head column, on fresh worktrees of the same commit, so the two
differ in the assignment alone. The merge base goes unmeasured.

  $1  The profiling declaration
FUN
__profile__columns__against_variant() {
  __profile__columns__against_variant__under="$(profile__variant)"
  __profile__columns__against_variant__sha="$(git__worktree_head "$PROJ")"
  log "Measuring this head as is and under $__profile__columns__against_variant__under."
  __profile__columns__against_variant__base="$(profile__measure__commit "$__profile__columns__against_variant__sha" "$1")" || return 1
  __profile__columns__against_variant__head="$(profile__measure__commit "$__profile__columns__against_variant__sha" "$1" "$__profile__columns__against_variant__under")" || return 1

  __profile__columns__of "$__profile__columns__against_variant__sha" "$__profile__columns__against_variant__base" "$__profile__columns__against_variant__head"
}

: <<'FUN'
The report's columns as one struct {base_sha, base, head}.

  $1  The base column's sha, or nothing   $2  Base measurements   $3  Head measurements
FUN
__profile__columns__of() {
  @wrap __profile__columns__of__sha "$1"
  @obj __profile__columns__of__out \
    '.base_sha' "$__profile__columns__of__sha" \
    '.base' "$2" \
    '.head' "$3"
  println "$__profile__columns__of__out"
}
