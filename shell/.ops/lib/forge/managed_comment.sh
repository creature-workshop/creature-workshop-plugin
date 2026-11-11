#!/bin/sh

:<<'MODULE'
A comment on a code review that an action owns: posted once, rewritten in place
after that, and found again by a marker rather than by remembering an id.

Its own module because nothing here is any one action's: a bot that keeps a
single comment current -- rather than commenting again every pipeline -- wants
the whole set, and the marker discipline is what makes that work.

The marker is the identity, so the lifecycle is closed: whoever can write the
comment can also find it and take it away again, and an action that stops
having something to say is not stuck leaving its last word up forever.
MODULE

import "$SHELLOPS_DIR/lib/forge/api.sh"

# CONST: A newline, the boundary of a comment's first line.
__forge__managed_comment__NL='
'

:<<'PUB_FUN'
Returns 0 when COMMENT is the one MARKER identifies, which is to say the comment
whose first line is MARKER and nothing else.

The whole first line, rather than the marker appearing anywhere: a human writing
about a panel quotes its marker, and matching loosely would adopt that comment
as ours and overwrite what they wrote. Where the marker sits is this module's to
decide, so the test can afford to be exact.

Usage: forge__is_managed_comment "$comment" "<!-- shellops:linear-prompt -->"
PUB_FUN
forge__is_managed_comment() {
  @get __forge__is_managed_comment__body "$1" '.body' ''
  __forge__is_managed_comment__first_line="${__forge__is_managed_comment__body%%"$__forge__managed_comment__NL"*}"

  [ "$__forge__is_managed_comment__first_line" = "$2" ]
}

:<<'PUB_FUN'
Prints the comment MARKER identifies among COMMENTS, or nothing when it has
not been posted yet.

The earliest one, if a review somehow carries two -- two pipelines can race to
post the first. That keeps the live comment the one people have been replying
under, and leaves the other inert, rather than consecutive runs taking turns
rewriting a different one. COMMENTS arrives oldest first from every backend, so
the first match is the earliest.

Usage: forge__find_managed_comment "$comments" "$marker"
PUB_FUN
forge__find_managed_comment() {
  @find __forge__find_managed_comment__out forge__is_managed_comment "$1" "$2"
  println "$__forge__find_managed_comment__out"
}

:<<'PUB_FUN'
Writes BODY as the comment MARKER identifies on the code review OPTIONS names,
and prints the id of the comment it wrote: posted when it is not there yet,
rewritten when the text has changed. Prints nothing when the
text matches what is already there, so a rerun over an unchanged review is not
an edit -- which is what keeps a long-lived review from collecting a
notification per pipeline.

MARKER is prepended here, and BODY is passed without it: the comment is
findable next run because this wrote the marker, not because a caller
remembered to.

Usage: forge__sync_managed_comment "$options" "$comments" "$marker" "$body"
PUB_FUN
forge__sync_managed_comment() {
  __forge__sync_managed_comment__body="$(printf '%s\n%s' "$3" "$4")"
  __forge__sync_managed_comment__existing="$(forge__find_managed_comment "$2" "$3")"

  if ! @defined "$__forge__sync_managed_comment__existing"; then
    __forge__sync_managed_comment__posted="$(
      forge__create_review_comment "$1" "$__forge__sync_managed_comment__body"
    )" || return 1

    @get __forge__sync_managed_comment__out "$__forge__sync_managed_comment__posted" '.id'
    println "$__forge__sync_managed_comment__out"
    return 0
  fi

  @get __forge__sync_managed_comment__current "$__forge__sync_managed_comment__existing" '.body' ''
  if [ "$__forge__sync_managed_comment__current" = "$__forge__sync_managed_comment__body" ]; then
    return 0
  fi

  @get __forge__sync_managed_comment__id "$__forge__sync_managed_comment__existing" '.id'
  @set __forge__sync_managed_comment__options "$1" '.comment_id' "$__forge__sync_managed_comment__id"

  # The rewritten comment is the one we just found, so the response says nothing
  # the caller does not have; a failed write is reported by the adaptor.
  forge__update_review_comment \
    "$__forge__sync_managed_comment__options" \
    "$__forge__sync_managed_comment__body" \
    > /dev/null || return 1

  println "$__forge__sync_managed_comment__id"
}

:<<'PUB_FUN'
Takes the comment MARKER identifies off the code review OPTIONS names, and
prints the id it removed. Prints nothing when there is none of ours there, so
retracting a comment twice is not an error -- the state asked for is the state
reached either way.

Usage: forge__delete_managed_comment "$options" "$comments" "$marker"
PUB_FUN
forge__delete_managed_comment() {
  __forge__delete_managed_comment__existing="$(forge__find_managed_comment "$2" "$3")"
  @defined "$__forge__delete_managed_comment__existing" || return 0

  @get __forge__delete_managed_comment__id "$__forge__delete_managed_comment__existing" '.id'
  @set __forge__delete_managed_comment__options "$1" '.comment_id' "$__forge__delete_managed_comment__id"

  # Both forges answer a delete with an empty body; a refusal is reported by the
  # adaptor rather than carried in what is printed here.
  forge__delete_review_comment "$__forge__delete_managed_comment__options" > /dev/null \
    || return 1

  println "$__forge__delete_managed_comment__id"
}
