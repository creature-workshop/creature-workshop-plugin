#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/markdown/api.sh" \
  "$SHELLOPS_DIR/lib/releases/api.sh" \
  "$SHELLOPS_DIR/lib/time/api.sh"

: <<'MODULE'
The release notes for a span of history: every code review a commit in the
span names, read off the forge, grouped as releases.json says, rendered as
markdown. A tag's forge release carries them (cli/publish-release), and so
does the merge request that promotes a version (cli/promote), so a reviewer
reads what ships before it does.

A review is named the way the forge on the run writes it into history, and
the forge's own reader (forge__code_review_refs) knows that spelling: the
"See merge request <path>!<n>" footer GitLab writes on the merge commit of
an accepted merge request, the "(#<n>)" a squash appends to its subject on
Forgejo and GitHub. The span is read whole, merge commits and bodies
included, since on GitLab the merge commit is the one commit that names the
review.
MODULE

: <<'PUB_FUN'
Prints the release notes for the commits after <from> up to <to>, dated
today, or "No changes." when no commit lies between them. <token> reads the
code reviews off the forge.

  releases__release_notes_between 0.65.0 origin/main "$token"
    ->  Released on September 16th, 2026 ...
        ## Impact
        - ...

Usage: releases__release_notes_between <from> <to> <token>
PUB_FUN
releases__release_notes_between() {
  __releases__release_notes_between__text="$(git__commit_text "$1..$2")"
  if ! @defined "$__releases__release_notes_between__text"; then
    printf 'No changes.\n'
    return 0
  fi

  __releases__release_notes_between__numbers="$(releases__reviews_named "$__releases__release_notes_between__text")"
  __releases__release_notes_between__reviews="$(releases__fetch_review_metadata "$__releases__release_notes_between__numbers" "$3")"
  __releases__release_notes_between__grouped="$(releases__group_prs "$__releases__release_notes_between__reviews")"
  __releases__release_notes_between__doc="$(releases__build_release_doc "$__releases__release_notes_between__grouped" "$(releases__release_notes_date)")"
  markdown__render "$__releases__release_notes_between__doc"
}

: <<'PUB_FUN'
Prints the reviews the commit text <text> names, as a struct array of review
numbers, each once, in the order the text first names them; the empty array
when it names none.

  releases__reviews_named "$(git__commit_text 0.65.0..0.66.0)"  ->  ["15", "12"]

Usage: releases__reviews_named <text>
PUB_FUN
releases__reviews_named() {
  __releases__reviews_named__listed="$(forge__code_review_refs "$1" \
    | awk -f "$SHELLOPS_DIR/lib/releases/first_of_each.awk"
  )"
  if ! @defined "$__releases__reviews_named__listed"; then
    @arr __releases__reviews_named__out
    println "$__releases__reviews_named__out"
    return 0
  fi

  @split __releases__reviews_named__out "$__releases__reviews_named__listed"
  println "$__releases__reviews_named__out"
}

: <<'PUB_FUN'
Prints the day and time the notes are dated, in the reader's words.

  releases__release_notes_date  ->  September 16th, 2026 11:02 PM MDT
PUB_FUN
releases__release_notes_date() {
  __releases__release_notes_date__date="$(time__get_date)"

  @let "$__releases__release_notes_date__date" __releases__release_notes_date__ year month day day_suffix hours_12 minutes ampm timezone
  printf '%s %s%s, %s %s:%s %s %s\n' \
    "$__releases__release_notes_date__month" \
    "$__releases__release_notes_date__day" \
    "$__releases__release_notes_date__day_suffix" \
    "$__releases__release_notes_date__year" \
    "$__releases__release_notes_date__hours_12" \
    "$__releases__release_notes_date__minutes" \
    "$__releases__release_notes_date__ampm" \
    "$__releases__release_notes_date__timezone"
  @unlet __releases__release_notes_date__ year month day day_suffix hours_12 minutes ampm timezone
}
