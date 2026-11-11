#!/bin/sh

:<<'FRAGMENT'
How GitLab reads a review's options: the owner, repo and number a call may leave to the manifest and the environment.
FRAGMENT

: <<'FUN'
Canonicalize the caller's options so every PR-comment function sees a
consistent set of keys regardless of which subset the caller populated.

.review_number and .issue_number are coalesced to whichever was supplied (PR
first), so downstream code can read either key without caring which the
caller set. Owner/repo are passed through when present but never backfilled
from the manifest — the flat manifest identity would collapse a nested
project path like group/sub/repo to group/repo, shadowing the subgroup-
correct fallback chain in __gitlab__project_path.

Usage: __gitlab__normalize_review_options "$options"
FUN
__gitlab__normalize_review_options() {
  @let "$1" __gitlab__normalize_review_options__ review_number issue_number owner repo

  __gitlab__normalize_review_options__chosen="$__gitlab__normalize_review_options__review_number"
  ! @defined "$__gitlab__normalize_review_options__chosen" && __gitlab__normalize_review_options__chosen="$__gitlab__normalize_review_options__issue_number"

  @set __gitlab__normalize_review_options__out "$1" \
    '.review_number'    "$__gitlab__normalize_review_options__chosen" \
    '.issue_number' "$__gitlab__normalize_review_options__chosen" \
    '.owner'        "$__gitlab__normalize_review_options__owner" \
    '.repo'         "$__gitlab__normalize_review_options__repo"
  println "$__gitlab__normalize_review_options__out"
  __gitlab__normalize_review_options__status=$?
  @unlet __gitlab__normalize_review_options__ review_number issue_number owner repo
  return "$__gitlab__normalize_review_options__status"
}
