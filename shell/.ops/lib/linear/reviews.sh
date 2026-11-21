#!/bin/sh
# shellcheck disable=SC2119  # bare @arr is the structs empty constructor

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/forge/api.sh"

: <<'MODULE'
Judging the code reviews that a Linear issue links to, so that a caller can
tell whether the issue's work has merged.

An issue's attachments are URLs. Some of them are the pages of code reviews
on this forge. This module picks those out, asks the forge what state each
review is in, and reads the states together as one status of the issue's
work, one of the linear__reviews__STATUS words.

The status says what the reviews show. What to do about it is the caller's
decision: the action that moves issues to Done applies its own policy on
top.

The module is separate from lib/linear/api.sh because that module talks to
Linear, and this one only reads what Linear answered and asks the forge
about it.
MODULE

: <<'PUB_CONST'
The status linear__reviews__status gives an issue: what the code reviews
the issue links to say, taken together, about whether its work has merged.

  merged  every review has merged
  open    a review is still open, or the issue links to no review on this
          forge
  closed  no review is open and not every one has merged: one was closed
          without merging, or the forge did not answer for one
PUB_CONST
@enum linear__reviews__STATUS MERGED OPEN CLOSED

: <<'CONST'
The state word for a code review the forge refuses to answer for, because it
was deleted or the token cannot see it. The forge's own states are the three
forge__REVIEW_STATE words.
CONST
__linear__reviews__UNANSWERED="unknown"

: <<'PUB_FUN'
Judges an issue's attachments in one call: prints the status, the refs of
the reviews that have merged, and each other review with its state. The
forge is asked with the options $2.

  linear__reviews__judgement "$attachments" "$forge_options"
    -> {"status": "closed", "merged": ["org/tool!7"],
        "unmerged": [{"ref": "org/tool!5", "state": "closed"}]}

Usage: linear__reviews__judgement "$attachments" "$forge_options"
PUB_FUN
linear__reviews__judgement() {
  __linear__reviews__judgement__links="$(linear__reviews__links "$1")"
  __linear__reviews__judgement__reviews="$(linear__reviews__states "$__linear__reviews__judgement__links" "$2")"

  @obj __linear__reviews__judgement__out \
    '.status' "$(linear__reviews__status "$__linear__reviews__judgement__reviews")" \
    '.merged' "$(__linear__reviews__merged_refs "$__linear__reviews__judgement__reviews")" \
    '.unmerged' "$(__linear__reviews__unmerged "$__linear__reviews__judgement__reviews")"
  println "$__linear__reviews__judgement__out"
}

: <<'PUB_FUN'
Prints the code reviews on this forge that the attachments $1, a struct
array of {url}, link to, each once, as a struct array of
{owner, repo, review_number, ref}. A link to anything else, or to another
host, is left out.

  linear__reviews__links '[{"url": "https://gitlab.example.com/org/tool/-/merge_requests/7"}]'
    -> [{"owner": "org", "repo": "tool", "review_number": 7, "ref": "org/tool!7"}]

Usage: linear__reviews__links "$attachments"
PUB_FUN
linear__reviews__links() {
  @pluck __linear__reviews__links__urls "$1" '.url'
  @arr __linear__reviews__links__arr_1
  @reduce __linear__reviews__links__links __linear__reviews__collect_link "$__linear__reviews__links__urls" "$__linear__reviews__links__arr_1"

  @unique __linear__reviews__links__out "$__linear__reviews__links__links"
  println "$__linear__reviews__links__out"
}

: <<'FUN'
@reduce callback: the links so far, plus the code review the wrapped URL $2
points at on this forge, when it points at one.
FUN
__linear__reviews__collect_link() {
  @unwrap __linear__reviews__collect_link__url "$2"
  __linear__reviews__collect_link__link="$(__linear__reviews__link "$__linear__reviews__collect_link__url")"
  if ! @defined "$__linear__reviews__collect_link__link"; then
    println "$1"
    return 0
  fi

  @push __linear__reviews__collect_link__out "$1" "$__linear__reviews__collect_link__link"
  println "$__linear__reviews__collect_link__out"
}

: <<'FUN'
Prints the code review the URL $1 points at on this forge, as
{owner, repo, review_number, ref}, and nothing for any other URL. The ref is
the review's number under its repository, written as the forge writes it in
prose, for example org/tool!7 on GitLab.

  __linear__reviews__link https://gitlab.example.com/org/tool/-/merge_requests/7#note_1
    -> {"owner": "org", "repo": "tool", "review_number": 7, "ref": "org/tool!7"}

Usage: __linear__reviews__link "$url"
FUN
__linear__reviews__link() {
  __linear__reviews__link__review="$(forge__review_from_url "$1")"
  if ! @defined "$__linear__reviews__link__review"; then
    return 0
  fi

  @let "$__linear__reviews__link__review" __linear__reviews__link__ owner repo review_number
  __linear__reviews__link__number="$(forge__review_ref "$__linear__reviews__link__review_number")"
  @set __linear__reviews__link__out "$__linear__reviews__link__review" \
    '.ref' "${__linear__reviews__link__owner}/${__linear__reviews__link__repo}${__linear__reviews__link__number}"
  println "$__linear__reviews__link__out"
  @unlet __linear__reviews__link__ owner repo review_number
}

: <<'PUB_FUN'
Asks the forge for the state of each code review in $1, as
linear__reviews__links prints them, and prints a struct array of
{ref, state}: merged, open or closed, or unknown for a review the forge
refuses to answer for. The forge is asked with the options $2.

Usage: linear__reviews__states "$links" "$forge_options"
PUB_FUN
linear__reviews__states() {
  @map __linear__reviews__states__out __linear__reviews__with_state "$1" "$2"
  println "$__linear__reviews__states__out"
}

: <<'FUN'
@map callback: the code review $1 as {ref, state}, with the state the forge
reports when asked with the options $2.
FUN
__linear__reviews__with_state() {
  @get __linear__reviews__with_state__get_2 "$1" '.ref'
  @obj __linear__reviews__with_state__out \
    '.ref' "$__linear__reviews__with_state__get_2" \
    '.state' "$(__linear__reviews__state "$1" "$2")"
  println "$__linear__reviews__with_state__out"
}

: <<'FUN'
Prints the state the forge reports the code review $1 in: merged, open or
closed. Prints unknown when the forge refuses the review, because it was
deleted or the token cannot see it, and leaves the forge's own error line
in the log to say which. The forge is asked with the options $2.

Usage: __linear__reviews__state "$link" "$forge_options"
FUN
__linear__reviews__state() {
  @let "$1" __linear__reviews__state__ owner repo review_number
  @set __linear__reviews__state__options "$2" \
    '.owner' "$__linear__reviews__state__owner" \
    '.repo' "$__linear__reviews__state__repo" \
    '.review_number' "$__linear__reviews__state__review_number"
  @unlet __linear__reviews__state__ owner repo review_number

  __linear__reviews__state__review="$(forge__get_review "$__linear__reviews__state__options")" || {
    println "$__linear__reviews__UNANSWERED"
    return 0
  }
  __linear__reviews__state__state="$(forge__review_state "$__linear__reviews__state__review")"
  if ! @defined "$__linear__reviews__state__state"; then
    println "$__linear__reviews__UNANSWERED"
    return 0
  fi

  println "$__linear__reviews__state__state"
}

: <<'PUB_FUN'
Prints the status the reviews $1, as linear__reviews__states prints them,
give their issue: one of the linear__reviews__STATUS words.

Usage: linear__reviews__status "$reviews"
PUB_FUN
linear__reviews__status() {
  if @any __linear__reviews__status__any_3 __linear__reviews__is_open "$1"; @empty "$1" || @is_true "$__linear__reviews__status__any_3"; then
    println "$linear__reviews__STATUS_OPEN"
  elif @all __linear__reviews__status__all_4 __linear__reviews__is_merged "$1"; @is_true "$__linear__reviews__status__all_4"; then
    println "$linear__reviews__STATUS_MERGED"
  else
    println "$linear__reviews__STATUS_CLOSED"
  fi
}

: <<'FUN'
@any callback: succeeds when the code review $1 is still open.
FUN
__linear__reviews__is_open() {
  @get __linear__reviews__is_open__get_5 "$1" '.state'
  [ "$__linear__reviews__is_open__get_5" = "$forge__REVIEW_STATE_OPEN" ]
}

: <<'FUN'
@all callback: succeeds when the code review $1 has merged.
FUN
__linear__reviews__is_merged() {
  @get __linear__reviews__is_merged__get_6 "$1" '.state'
  [ "$__linear__reviews__is_merged__get_6" = "$forge__REVIEW_STATE_MERGED" ]
}

: <<'FUN'
Prints the refs of the reviews in $1 that have merged, as a struct array.

Usage: __linear__reviews__merged_refs "$reviews"
FUN
__linear__reviews__merged_refs() {
  @filter __linear__reviews__merged_refs__merged "$1" silt__text_is .state "$forge__REVIEW_STATE_MERGED"

  @pluck __linear__reviews__merged_refs__out "$__linear__reviews__merged_refs__merged" '.ref'
  println "$__linear__reviews__merged_refs__out"
}

: <<'FUN'
Prints the reviews in $1 that have not merged, with their states, as a
struct array of {ref, state}.

Usage: __linear__reviews__unmerged "$reviews"
FUN
__linear__reviews__unmerged() {
  @filter __linear__reviews__unmerged__out "$1" silt__text_is_not .state "$forge__REVIEW_STATE_MERGED"
  println "$__linear__reviews__unmerged__out"
}
