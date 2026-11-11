#!/bin/sh

:<<'FRAGMENT'
How Forgejo reads a review's options: the owner, repo and number a call may leave to the manifest and the environment.
FRAGMENT

__forgejo__normalize_review_options() {
  @let "$1" __forgejo__normalize_review_options__ review_number issue_number owner repo

  __forgejo__normalize_review_options__chosen="$__forgejo__normalize_review_options__review_number"
  ! @defined "$__forgejo__normalize_review_options__chosen" && __forgejo__normalize_review_options__chosen="$__forgejo__normalize_review_options__issue_number"

  ! @defined "$__forgejo__normalize_review_options__owner" && __forgejo__normalize_review_options__owner="$(manifest__get org 2>/dev/null || echo '')"
  ! @defined "$__forgejo__normalize_review_options__repo" && __forgejo__normalize_review_options__repo="$(manifest__get repo 2>/dev/null || echo '')"

  @set __forgejo__normalize_review_options__out "$1" \
    '.review_number'    "$__forgejo__normalize_review_options__chosen" \
    '.issue_number' "$__forgejo__normalize_review_options__chosen" \
    '.owner'        "$__forgejo__normalize_review_options__owner" \
    '.repo'         "$__forgejo__normalize_review_options__repo"
  println "$__forgejo__normalize_review_options__out"
  __forgejo__normalize_review_options__status=$?
  @unlet __forgejo__normalize_review_options__ review_number issue_number owner repo
  return "$__forgejo__normalize_review_options__status"
}
