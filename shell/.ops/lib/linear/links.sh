#!/bin/sh
# shellcheck disable=SC2119  # bare @arr is the structs empty constructor

:<<'MODULE'
Showing Linear references to a reader: the panel a bot posts listing them, and
the URL each identifier links to.

Separate from lib/linear/refs.sh because that module reads references out of
prose and this one writes them back into it. Separate from the actions that post
the panel because what a reference looks like is not a policy about when to say
it.
MODULE

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/markdown/api.sh" \
  "$SHELLOPS_DIR/lib/linear/refs.sh"

:<<'PUB_FUN'
Prints the panel a bot posts for the mention RECORDS, as linear__mention_records
reads them: a markdown list of every issue named, each as a link titled by the
issue behind it where one resolved, under "Closes on merge" when any of its
records closes (linear__mention_closes) and under "Mentioned" otherwise, each
line saying where and how the issue was named. A heading with nothing under it
is left out.

ISSUES is whatever was fetched for the issues, which may be fewer. An
identifier no fetch answered for still links, built from ISSUES' own URLs, so
the list reads the same whether or not one lookup happened to fail, and only a
run that resolved nothing at all leaves identifiers bare.

  **Linear issues referenced**

  Closes on merge:
  - [OPS-12](url) — Auto-close on merge (a closing clause in the description)

  Mentioned:
  - [OPS-51](url) — The follow-up (named in the branch name; named in a comment)

Usage: linear__reference_panel "$records" "$issues"
PUB_FUN
linear__reference_panel() {
  __linear__reference_panel__context="$(__linear__links__panel_context "$1" "$2")"

  __linear__reference_panel__doc="$(__linear__links__panel_heading)"
  __linear__reference_panel__doc="$(
    __linear__links__closes_on_merge_section "$__linear__reference_panel__doc" "$__linear__reference_panel__context"
  )"
  __linear__reference_panel__doc="$(
    __linear__links__mentioned_section "$__linear__reference_panel__doc" "$__linear__reference_panel__context"
  )"

  markdown__render "$__linear__reference_panel__doc"
}

:<<'FUN'
Prints what every section of the panel reads, as {records, issues, prefix}:
the mention RECORDS, the ISSUES Linear answered for, and the URL prefix an
identifier links under.

Usage: __linear__links__panel_context "$records" "$issues"
FUN
__linear__links__panel_context() {
  __linear__links__panel_context__prefix="$(linear__issues_url_prefix "$2")"

  @obj __linear__links__panel_context__out \
    '.records' "$1" \
    '.issues' "$2" \
    '.prefix' "$__linear__links__panel_context__prefix"
  println "$__linear__links__panel_context__out"
}

:<<'FUN'
Prints the panel's document with only its heading in it.
FUN
__linear__links__panel_heading() {
  @arr __linear__links__panel_heading__doc

  markdown__line "$__linear__links__panel_heading__doc" "**Linear issues referenced**"
}

:<<'FUN'
Prints the document DOC with the "Closes on merge" section added: one line
per issue that any of its records closes (linear__mention_closes), or DOC as
it is when none does. CONTEXT is the panel's {records, issues, prefix}.

Usage: __linear__links__closes_on_merge_section "$doc" "$context"
FUN
__linear__links__closes_on_merge_section() {
  @get __linear__links__closes_on_merge_section__records "$2" '.records'
  __linear__links__closes_on_merge_section__ids="$(linear__closing_ids "$__linear__links__closes_on_merge_section__records")"

  __linear__links__append_group "$1" "Closes on merge:" "$__linear__links__closes_on_merge_section__ids" "$2"
}

:<<'FUN'
Prints the document DOC with the "Mentioned" section added: one line per
issue that was named but that no record closes, or DOC as it is when there
is none. CONTEXT is the panel's {records, issues, prefix}.

Usage: __linear__links__mentioned_section "$doc" "$context"
FUN
__linear__links__mentioned_section() {
  @get __linear__links__mentioned_section__records "$2" '.records'
  __linear__links__mentioned_section__closing="$(linear__closing_ids "$__linear__links__mentioned_section__records")"
  __linear__links__mentioned_section__named="$(linear__mentioned_ids "$__linear__links__mentioned_section__records")"
  @difference __linear__links__mentioned_section__ids "$__linear__links__mentioned_section__named" "$__linear__links__mentioned_section__closing"

  __linear__links__append_group "$1" "Mentioned:" "$__linear__links__mentioned_section__ids" "$2"
}

:<<'FUN'
Prints the document DOC with a blank line, the heading HEADING and one line
per id in IDS added, and DOC as it is when IDS is empty. CONTEXT is the
panel's {records, issues, prefix}.

Usage: __linear__links__append_group "$doc" "Mentioned:" "$ids" "$context"
FUN
__linear__links__append_group() {
  if @empty "$3"; then
    println "$1"
    return 0
  fi

  __linear__links__append_group__doc="$(markdown__nl "$1")"
  __linear__links__append_group__doc="$(markdown__line "$__linear__links__append_group__doc" "$2")"

  @reduce __linear__links__append_group__out __linear__links__append_issue_line "$3" "$__linear__links__append_group__doc" "$4"
  println "$__linear__links__append_group__out"
}

:<<'FUN'
@reduce callback: the document $1 with the line for the wrapped id $2 added,
the id as a link titled by its issue, then where and how it was named, read
from the panel's context $3.
FUN
__linear__links__append_issue_line() {
  @unwrap __linear__links__append_issue_line__ref "$2"
  @get __linear__links__append_issue_line__issues "$3" '.issues'
  @get __linear__links__append_issue_line__records "$3" '.records'
  @get __linear__links__append_issue_line__prefix "$3" '.prefix' ''
  __linear__links__append_issue_line__issue="$(
    __linear__links__issue_by_identifier "$__linear__links__append_issue_line__issues" "$__linear__links__append_issue_line__ref"
  )"
  __linear__links__append_issue_line__item="$(
    linear__issue_link \
      "$__linear__links__append_issue_line__ref" \
      "$__linear__links__append_issue_line__issue" \
      "$__linear__links__append_issue_line__prefix"
  )"
  __linear__links__append_issue_line__named="$(
    __linear__links__mention_phrases "$__linear__links__append_issue_line__records" "$__linear__links__append_issue_line__ref"
  )"

  markdown__bullet "$1" "$__linear__links__append_issue_line__item ($__linear__links__append_issue_line__named)"
}

:<<'FUN'
Prints how the issue ID was named, one phrase per record of it in RECORDS,
joined by a semicolon.

  __linear__links__mention_phrases "$records" OPS-51  ->  a closing clause in the description; named in a comment

Usage: __linear__links__mention_phrases "$records" "OPS-51"
FUN
__linear__links__mention_phrases() {
  @filter __linear__links__mention_phrases__mine "$1" silt__text_is .id "$2"
  @map __linear__links__mention_phrases__phrases __linear__links__phrase "$__linear__links__mention_phrases__mine"

  @join __linear__links__mention_phrases__out "$__linear__links__mention_phrases__phrases" "; "
  println "$__linear__links__mention_phrases__out"
}

:<<'FUN'
@map callback: the phrase for the record $1, how it was named and where,
wrapped for the array it joins.

  __linear__links__phrase '{"id": "OPS-1", "where": "thread", "how": "mention"}'  ->  "named in a thread on the diff"
FUN
__linear__links__phrase() {
  @get __linear__links__phrase__get_1 "$1" '.how'
  __linear__links__phrase__how="$(__linear__links__how_phrase "$__linear__links__phrase__get_1")"
  @get __linear__links__phrase__get_2 "$1" '.where'
  __linear__links__phrase__where="$(__linear__links__where_phrase "$__linear__links__phrase__get_2")"

  @wrap __linear__links__phrase__out "$__linear__links__phrase__how $__linear__links__phrase__where"
  println "$__linear__links__phrase__out"
}

:<<'FUN'
Prints the words for how an issue was named: the linear__refs__HOW word $1
as a reader says it.
FUN
__linear__links__how_phrase() {
  case "$1" in
    "$linear__refs__HOW_CLAUSE") println "a closing clause" ;;
    "$linear__refs__HOW_LIST") println "a Closes list" ;;
    "$linear__refs__HOW_REPLY") println "a reply" ;;
    *) println "named" ;;
  esac
}

:<<'FUN'
Prints the words for where an issue was named: the linear__refs__WHERE word
$1 as a reader says it.
FUN
__linear__links__where_phrase() {
  case "$1" in
    "$linear__refs__WHERE_TITLE") println "in the title" ;;
    "$linear__refs__WHERE_DESCRIPTION") println "in the description" ;;
    "$linear__refs__WHERE_BRANCH") println "in the branch name" ;;
    "$linear__refs__WHERE_COMMIT") println "in a commit message" ;;
    "$linear__refs__WHERE_THREAD") println "in a thread on the diff" ;;
    *) println "in a comment" ;;
  esac
}

:<<'PUB_FUN'
Prints the URL prefix identifiers link under, taken from the first of ISSUES
carrying a URL. Nothing when none of them do.

Usage: linear__issues_url_prefix "$issues"
PUB_FUN
linear__issues_url_prefix() {
  @first __linear__issues_url_prefix__issue "$1"
  @get __linear__issues_url_prefix__url "$__linear__issues_url_prefix__issue" '.url'
  @defined "$__linear__issues_url_prefix__url" || return 0

  linear__issue_url_prefix "$__linear__issues_url_prefix__url"
}

:<<'PUB_FUN'
Prints IDENTIFIER as a markdown link followed by ISSUE's title, or as a bare
identifier when neither ISSUE nor PREFIX gives it a URL.

Usage: linear__issue_link "OPS-51" "$issue" "https://linear.app/team/issue"
PUB_FUN
linear__issue_link() {
  __linear__issue_link__url="$(__linear__links__issue_url "$1" "$2" "$3")"
  if ! @defined "$__linear__issue_link__url"; then
    println "$1"
    return 0
  fi

  __linear__issue_link__link="$(markdown__link "$__linear__issue_link__url" "$1")"
  @get __linear__issue_link__title "$2" '.title'
  if ! @defined "$__linear__issue_link__title"; then
    println "$__linear__issue_link__link"
    return 0
  fi

  printf '%s — %s\n' "$__linear__issue_link__link" "$__linear__issue_link__title"
}

:<<'FUN'
Prints the URL an identifier links to: the resolved issue's own, or
PREFIX/IDENTIFIER when nothing resolved it. Nothing at all when there is no
prefix either, which is what leaves an identifier bare.
FUN
__linear__links__issue_url() {
  @get __linear__links__issue_url__url "$2" '.url'
  if @defined "$__linear__links__issue_url__url"; then
    println "$__linear__links__issue_url__url"
    return 0
  fi

  @defined "$3" || return 0
  printf '%s/%s\n' "${3%/}" "$1"
}

: <<'FUN'
The issue among ISSUES that IDENTIFIER names, or nothing.
FUN
__linear__links__issue_by_identifier() {
  @filter __linear__links__issue_by_identifier__matching "$1" silt__text_is .identifier "$2"
  if @len __linear__links__issue_by_identifier__len_3 "$__linear__links__issue_by_identifier__matching"; [ "$__linear__links__issue_by_identifier__len_3" -eq 0 ]; then
    return 0
  fi

  @first __linear__links__issue_by_identifier__out "$__linear__links__issue_by_identifier__matching"
  println "$__linear__links__issue_by_identifier__out"
}
