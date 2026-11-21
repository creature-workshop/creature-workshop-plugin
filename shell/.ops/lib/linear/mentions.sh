#!/bin/sh
# shellcheck disable=SC2119  # bare @arr is the structs empty constructor

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/linear/api.sh" \
  "$SHELLOPS_DIR/lib/linear/refs.sh" \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/forge/managed_comment.sh"

:<<'MODULE'
Which Linear issues a code review names, where and how, and what Linear knows
about them.

Every identifier in the title, the description, the head branch name, a
commit message, or a comment as its author wrote it, on the conversation or
on a line of the diff, is a record: the id, where it was named and how, as
linear__mention_records reads them, for the teams whose keys KEYS names
as linear__keys_pattern prints them. Nothing here weighs whether a record
closes the issue; linear__mention_closes does, for the action that closes
and the panel that promises alike. The one comment left out is the prompt
linear/sync-refs maintains, which is a projection of this set and would pin
an identifier the author had since removed.
MODULE

__linear__mentions__PROMPT_MARKER="<!-- shellops:linear-prompt -->"

:<<'PUB_FUN'
Prints the marker the Linear prompt comment opens with.

Usage: linear__prompt_marker
PUB_FUN
linear__prompt_marker() {
  println "$__linear__mentions__PROMPT_MARKER"
}

:<<'PUB_FUN'
Prints the branch the code review is merging, as the runner names it, and
nothing outside a code-review pipeline.

Usage: linear__review_head_branch
PUB_FUN
linear__review_head_branch() {
  println "${GITHUB_HEAD_REF:-${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-}}"
}

:<<'PUB_FUN'
Prints one record per mention on the code review, {id, where, how}, as a
struct array, and an empty array when KEYS is empty: without a team no
text can name an issue. The title, the description and the head branch name
are read from REVIEW. COMMENTS are the conversation and THREADS the comments
in threads on the diff, each read as its author wrote it, the prompt comment
left out. COMMITS are commit message texts, a struct array of strings.

  linear__review_mention_records "$review" "$comments" "$threads" "$commits" "OPS"
    -> [{"id": "OPS-10", "where": "title", "how": "mention"}, ...]

Usage: linear__review_mention_records "$review" "$comments" "$threads" "$commits" "$keys"
PUB_FUN
linear__review_mention_records() {
  if ! @defined "$5"; then
    @arr __linear__review_mention_records__out
    println "$__linear__review_mention_records__out"
    return 0
  fi

  __linear__review_mention_records__sources="$(__linear__mentions__review_sources "$1" "$2" "$3" "$4")"

  linear__mention_records_in "$__linear__review_mention_records__sources" "$5"
}

:<<'FUN'
Prints every text of the code review paired with where it was written, as a
struct array of {where, text}, in the order the records are listed: the
title, the description, the head branch name, the commit messages, then
each comment as its author wrote it, on the conversation and then in the
threads on the diff. The prompt comment is left out.

Usage: __linear__mentions__review_sources "$review" "$comments" "$threads" "$commits"
FUN
__linear__mentions__review_sources() {
  @let "$1" __linear__mentions__review_sources__ title body
  __linear__mentions__review_sources__branch="$(linear__review_head_branch)"
  @arr __linear__mentions__review_sources__own \
    "$(linear__source "$linear__refs__WHERE_TITLE" "$__linear__mentions__review_sources__title")" \
    "$(linear__source "$linear__refs__WHERE_DESCRIPTION" "$__linear__mentions__review_sources__body")" \
    "$(linear__source "$linear__refs__WHERE_BRANCH" "$__linear__mentions__review_sources__branch")"
  @unlet __linear__mentions__review_sources__ title body
  __linear__mentions__review_sources__committed="$(linear__sources_at "$linear__refs__WHERE_COMMIT" "$4")"
  __linear__mentions__review_sources__commented="$(__linear__mentions__comment_sources "$2" "$linear__refs__WHERE_COMMENT")"
  __linear__mentions__review_sources__threaded="$(__linear__mentions__comment_sources "$3" "$linear__refs__WHERE_THREAD")"

  @concat __linear__mentions__review_sources__sources "$__linear__mentions__review_sources__own" "$__linear__mentions__review_sources__committed"
  @concat __linear__mentions__review_sources__sources "$__linear__mentions__review_sources__sources" "$__linear__mentions__review_sources__commented"

  @concat __linear__mentions__review_sources__out "$__linear__mentions__review_sources__sources" "$__linear__mentions__review_sources__threaded"
  println "$__linear__mentions__review_sources__out"
}

:<<'PUB_FUN'
Prints the issue IDs the code review names in its title, its description, its
head branch name and COMMENTS, as a canonical struct array: the ids of
linear__review_mention_records, with no threads and no commits read.

  linear__review_mentions "$review" "$comments" "OPS"  ->  ["OPS-10","OPS-51"]

Usage: linear__review_mentions "$review" "$comments" "$keys"
PUB_FUN
linear__review_mentions() {
  @arr __linear__review_mentions__none
  __linear__review_mentions__records="$(
    linear__review_mention_records "$1" "$2" "$__linear__review_mentions__none" "$__linear__review_mentions__none" "$3"
  )"

  linear__mentioned_ids "$__linear__review_mentions__records"
}

:<<'FUN'
Prints one source per comment in COMMENTS, each as its author wrote it and
written at WHERE. The prompt comment adds nothing.

Usage: __linear__mentions__comment_sources "$comments" comment
FUN
__linear__mentions__comment_sources() {
  @arr __linear__mentions__comment_sources__arr_1
  @reduce __linear__mentions__comment_sources__out __linear__mentions__add_comment_source "$1" "$__linear__mentions__comment_sources__arr_1" "$2"
  println "$__linear__mentions__comment_sources__out"
}

:<<'FUN'
@reduce callback: the sources so far plus one comment's, as its author wrote
it, written at $3. The prompt comment adds nothing.
FUN
__linear__mentions__add_comment_source() {
  if forge__is_managed_comment "$2" "$__linear__mentions__PROMPT_MARKER"; then
    println "$1"
    return 0
  fi

  __linear__mentions__add_comment_source__body="$(forge__comment_authored_body "$2")"
  __linear__mentions__add_comment_source__source="$(
    linear__source "$3" "$__linear__mentions__add_comment_source__body"
  )"

  @push __linear__mentions__add_comment_source__out "$1" "$__linear__mentions__add_comment_source__source"
  println "$__linear__mentions__add_comment_source__out"
}

:<<'PUB_FUN'
Prints the issues Linear knows about among the mentioned identifiers, and an
empty array when nothing can be asked: no LINEAR_API_KEY, no team, or no
mentions. An identifier Linear will not answer for is left out.

Usage: linear__resolve_mentions "$mentioned" "$keys"
PUB_FUN
linear__resolve_mentions() {
  if ! @defined "${LINEAR_API_KEY:-}" || ! @defined "$2"; then
    @arr __linear__resolve_mentions__out
    println "$__linear__resolve_mentions__out"
    return 0
  fi
  if @len __linear__resolve_mentions__len_2 "$1"; [ "$__linear__resolve_mentions__len_2" -eq 0 ]; then
    @arr __linear__resolve_mentions__out
    println "$__linear__resolve_mentions__out"
    return 0
  fi

  __linear__resolve_mentions__options="$(linear__key_options)"

  linear__get_issues "$1" "$__linear__resolve_mentions__options"
}

:<<'PUB_FUN'
Prints Linear options carrying the key from the environment.

Usage: linear__key_options
PUB_FUN
linear__key_options() {
  @obj __linear__key_options__out '.token' "${LINEAR_API_KEY:-}"
  println "$__linear__key_options__out"
}
