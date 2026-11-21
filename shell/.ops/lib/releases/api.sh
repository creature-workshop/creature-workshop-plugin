#!/bin/sh

import "$SHELLOPS_DIR/lib/forge/api.sh"
import "$SHELLOPS_DIR/lib/markdown/api.sh"

:<<'MODULE'
API for generating release notes from git history and code-review metadata.
Reads .forgejo/releases.json to determine grouping and formatting.
Falls back to shellops's default config if the consumer doesn't provide one.
MODULE

__releases__CONFIG_FILE="$PROJ/.forgejo/releases.json"
__releases__DEFAULT_CONFIG="$SHELLOPS_DIR/schema/releases.default.json"

releases__load_release_config() {
  if [ -f "$__releases__CONFIG_FILE" ]; then
    cat "$__releases__CONFIG_FILE"
  else
    warn "No releases.json found at $__releases__CONFIG_FILE — using default"
    cat "$__releases__DEFAULT_CONFIG"
  fi
}

:<<'PUB_FUN'
Reads each review in <review_numbers> off the forge.

Usage: releases__fetch_review_metadata "\$review_numbers" "\$token"

  review_numbers: struct array of review numbers, as releases__reviews_named prints them
  token: forge API token

  Returns a JSON array of {review_number, title, author, labels} objects.
PUB_FUN
releases__fetch_review_metadata() {
  @map __releases__fetch_review_metadata__out releases__fetch_review "$1" "$2"
  println "$__releases__fetch_review_metadata__out"
}

:<<'PUB_FUN'
Reads one review off the forge as {review_number, title, author, labels};
null for a review number that is empty or null. <review_number> may arrive
as a struct array's element, still JSON-quoted, or as bare text.

Usage: releases__fetch_review <review_number> <token>
PUB_FUN
releases__fetch_review() {
  @unwrap __releases__fetch_review__review_number "$1"
  __releases__fetch_review__token="$2"

  if ! @defined "$__releases__fetch_review__review_number"; then
    echo "null"
    return
  fi

  @obj __releases__fetch_review__obj_1 \
    '.review_number' "$__releases__fetch_review__review_number" \
    '.token' "$__releases__fetch_review__token"
  __releases__fetch_review__review="$(forge__get_review "$__releases__fetch_review__obj_1")"

  @let "$__releases__fetch_review__review" __releases__fetch_review__ title labels
  @get __releases__fetch_review__author "$__releases__fetch_review__review" '.user.login'
  @pluck __releases__fetch_review__labels "$__releases__fetch_review__labels" '.name'

  @obj __releases__fetch_review__out \
    '.review_number' "$__releases__fetch_review__review_number" \
    '.title' "$__releases__fetch_review__title" \
    '.author' "$__releases__fetch_review__author" \
    '.labels' "$__releases__fetch_review__labels"
  println "$__releases__fetch_review__out"
  __releases__fetch_review__status=$?
  @unlet __releases__fetch_review__ title labels
  return "$__releases__fetch_review__status"
}

:<<'PUB_FUN'
Groups review entries by the priority-ordered groups defined in releases.json.

Usage: releases__group_prs "\$prs_json"

  First matching group wins (top-to-bottom priority).
  Labels that placed the review into a group are stripped from inline display.
  PRs with skip labels are excluded entirely.

  Returns a JSON object keyed by group header, each value an array of entries:
    {
      "Impact": [{"title":"...","review_number":"1","author":"...","labels":[...],"inline_labels":[...]}],
      "Development": [],
      ...
    }
PUB_FUN
releases__group_prs() {
  __releases__group_prs__config="$(releases__load_release_config)"
  @let "$__releases__group_prs__config" __releases__group_prs__ groups skip default_group

  __releases__group_prs__grouped="$(releases__create_empty_groups "$__releases__group_prs__groups" "$__releases__group_prs__default_group")"
  @reduce __releases__group_prs__out __releases__classify_pr \
    "$1" \
    "$__releases__group_prs__grouped" \
    "$__releases__group_prs__groups" "$__releases__group_prs__skip" "$__releases__group_prs__default_group"
  println "$__releases__group_prs__out"
  __releases__group_prs__status=$?
  @unlet __releases__group_prs__ groups skip default_group
  return "$__releases__group_prs__status"
}

__releases__classify_pr() {
  __releases__classify_pr__grouped="$1"
  __releases__classify_pr__pr="$2"
  __releases__classify_pr__groups="$3"
  __releases__classify_pr__skip_labels="$4"
  __releases__classify_pr__default_group="$5"

  @get __releases__classify_pr__pr_labels "$__releases__classify_pr__pr" '.labels'

  if @is_true "$(releases__should_skip_pr "$__releases__classify_pr__pr_labels" "$__releases__classify_pr__skip_labels")"; then
    echo "$__releases__classify_pr__grouped"
    return
  fi

  __releases__classify_pr__match="$(releases__find_matching_group "$__releases__classify_pr__pr_labels" "$__releases__classify_pr__groups")"
  @let "$__releases__classify_pr__match" __releases__classify_pr__ header labels
  __releases__classify_pr__matched_header="$__releases__classify_pr__header"
  __releases__classify_pr__matched_labels="$__releases__classify_pr__labels"
  @unlet __releases__classify_pr__ header labels

  if ! @defined "$__releases__classify_pr__matched_header"; then
    __releases__classify_pr__matched_header="$__releases__classify_pr__default_group"
    @arr __releases__classify_pr__matched_labels
  fi

  __releases__classify_pr__inline_labels="$(
    releases__get_inline_labels "$__releases__classify_pr__pr_labels" "$__releases__classify_pr__matched_labels" "$__releases__classify_pr__skip_labels"
  )"

  @set __releases__classify_pr__pr "$__releases__classify_pr__pr" '.inline_labels' "$__releases__classify_pr__inline_labels"

  @push __releases__classify_pr__out "$__releases__classify_pr__grouped" "$__releases__classify_pr__matched_header" "$__releases__classify_pr__pr"
  println "$__releases__classify_pr__out"
}

releases__create_empty_groups() {
  @obj __releases__create_empty_groups__obj_2
  @reduce __releases__create_empty_groups__buckets __releases__add_empty_bucket "$1" "$__releases__create_empty_groups__obj_2"
  @arr __releases__create_empty_groups__arr_3
  @set __releases__create_empty_groups__out "$__releases__create_empty_groups__buckets" "$2" "$__releases__create_empty_groups__arr_3"
  println "$__releases__create_empty_groups__out"
}

__releases__add_empty_bucket() {
  @get __releases__add_empty_bucket__header "$2" '.header'
  @arr __releases__add_empty_bucket__arr_4
  @set __releases__add_empty_bucket__out "$1" "$__releases__add_empty_bucket__header" "$__releases__add_empty_bucket__arr_4"
  println "$__releases__add_empty_bucket__out"
}

releases__find_matching_group() {
  @find __releases__find_matching_group__out __releases__has_matching_labels "$2" "$1"
  println "$__releases__find_matching_group__out"
}

__releases__has_matching_labels() {
  @get __releases__has_matching_labels__group_labels "$1" '.labels'
  @intersect __releases__has_matching_labels__intersect_5 "$2" "$__releases__has_matching_labels__group_labels"
  @len __releases__has_matching_labels__len_6 "$__releases__has_matching_labels__intersect_5"
  [ "$__releases__has_matching_labels__len_6" -gt 0 ]
}

:<<'PUB_FUN'
Returns the PR's labels minus those used for grouping or skipping.
These are displayed inline in the release note bullet point.

Usage: releases__get_inline_labels "\$pr_labels" "\$matched_labels" "\$skip_labels"

  Given pr_labels=["breaking","godot","skip-changelog"],
        matched_labels=["breaking"], skip_labels=["skip-changelog"]
  Returns: ["godot"]
PUB_FUN
releases__get_inline_labels() {
  @concat __releases__get_inline_labels__exclude "$2" "$3"
  @difference __releases__get_inline_labels__out "$1" "$__releases__get_inline_labels__exclude"
  println "$__releases__get_inline_labels__out"
}

:<<'PUB_FUN'
Prints the struct boolean for whether a PR's labels <pr_labels> share an
element with <skip_labels>.

Usage: if @is_true "$(releases__should_skip_pr "$pr_labels" "$skip_labels")"; then ... fi
PUB_FUN
releases__should_skip_pr() {
  @intersect __releases__should_skip_pr__intersect_7 "$1" "$2"
  @len __releases__should_skip_pr__len_8 "$__releases__should_skip_pr__intersect_7"
  @succeeds __releases__should_skip_pr__out [ "$__releases__should_skip_pr__len_8" -gt 0 ]
  println "$__releases__should_skip_pr__out"
}

:<<'PUB_FUN'
Builds a markdown document (JSON array of lines) from grouped review entries.

Usage: releases__build_release_doc "\$grouped_json" "\$date_string"

  grouped_json: output of releases__group_prs
  date_string: formatted release date

  Returns a JSON array suitable for markdown__render.
PUB_FUN
releases__build_release_doc() {
  __releases__build_release_doc__grouped="$1"
  __releases__build_release_doc__date_string="$2"

  __releases__build_release_doc__config="$(releases__load_release_config)"
  @get __releases__build_release_doc__groups "$__releases__build_release_doc__config" '.groups'

  @arr __releases__build_release_doc__doc
  __releases__build_release_doc__doc="$(markdown__line "$__releases__build_release_doc__doc" "Released on $__releases__build_release_doc__date_string")"
  __releases__build_release_doc__doc="$(markdown__nl "$__releases__build_release_doc__doc")"

  @reduce __releases__build_release_doc__out __releases__render_group "$__releases__build_release_doc__groups" "$__releases__build_release_doc__doc" "$__releases__build_release_doc__grouped"
  println "$__releases__build_release_doc__out"
}

__releases__render_group() {
  __releases__render_group__doc="$1"
  __releases__render_group__group="$2"
  __releases__render_group__grouped="$3"

  @get __releases__render_group__header "$__releases__render_group__group" '.header'
  @get __releases__render_group__entries "$__releases__render_group__grouped" "$__releases__render_group__header"

  if @len __releases__render_group__len_9 "$__releases__render_group__entries"; [ "$__releases__render_group__len_9" -eq 0 ]; then
    echo "$__releases__render_group__doc"
    return
  fi

  __releases__render_group__doc="$(markdown__h2 "$__releases__render_group__doc" "$__releases__render_group__header")"
  @reduce __releases__render_group__doc __releases__render_bullet "$__releases__render_group__entries" "$__releases__render_group__doc"
  markdown__nl "$__releases__render_group__doc"
}

__releases__render_bullet() {
  markdown__bullet "$1" "$(releases__format_bullet "$2")"
}

:<<'PUB_FUN'
Prints one review as its release-notes bullet: the inline labels, the title,
the review reference spelled the way the forge on the run writes it, and the
author.

  releases__format_bullet '{"title":"Fix crash","review_number":"42","author":"dev","inline_labels":["godot"]}'
    ->  `godot` Fix crash (!42) @dev      on GitLab
    ->  `godot` Fix crash (#42) @dev      on Forgejo or GitHub

Usage: releases__format_bullet <entry>
PUB_FUN
releases__format_bullet() {
  __releases__format_bullet__entry="$1"

  @let "$__releases__format_bullet__entry" __releases__format_bullet__ title review_number author inline_labels

  # Each label as inline code: the labels joined by the backticks between
  # two of them, and one backtick at each end.
  # shellcheck disable=SC2016  # the backticks are text, not a command
  @join __releases__format_bullet__prefix "$__releases__format_bullet__inline_labels" '` `'
  __releases__format_bullet__prefix="${__releases__format_bullet__prefix:+\`$__releases__format_bullet__prefix\`}"
  __releases__format_bullet__ref="$(forge__review_ref "$__releases__format_bullet__review_number")"
  echo "${__releases__format_bullet__prefix:+$__releases__format_bullet__prefix }${__releases__format_bullet__title} (${__releases__format_bullet__ref}) @${__releases__format_bullet__author}"
  @unlet __releases__format_bullet__ title review_number author inline_labels
}
