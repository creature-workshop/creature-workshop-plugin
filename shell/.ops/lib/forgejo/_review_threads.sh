#!/bin/sh

:<<'FRAGMENT'
The comments a pull request's reviews left on its diff. Forgejo files them
under the review that made them rather than under the pull request, so
listing them is one request for the reviews and one more for each review.
FRAGMENT

:<<'FUN'
@reduce callback: the comments gathered so far plus the ones review $2 left on
the diff.

Usage: __forgejo__add_review_comments "$comments" "$review" "$options" "$http_opts"
FUN
__forgejo__add_review_comments() {
  @get __forgejo__add_review_comments__id "$2" '.id'
  @set __forgejo__add_review_comments__options "$3" '.review_id' "$__forgejo__add_review_comments__id"
  __forgejo__add_review_comments__endpoint="$(
    __forgejo__render_endpoint \
      "$__forgejo__PULL_REVIEW_COMMENTS_ENDPOINT" \
      "$__forgejo__add_review_comments__options"
  )"
  __forgejo__add_review_comments__found="$(
    http__get "$__forgejo__add_review_comments__endpoint" "$4"
  )" || return 1

  @concat __forgejo__add_review_comments__out "$1" "$__forgejo__add_review_comments__found"
  println "$__forgejo__add_review_comments__out"
}
