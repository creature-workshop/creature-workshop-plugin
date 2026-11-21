#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/forge/managed_comment.sh" \
  "$SHELLOPS_DIR/lib/profile/_measure.sh" \
  "$SHELLOPS_DIR/lib/profile/columns.sh" \
  "$SHELLOPS_DIR/lib/string/api.sh"

: <<'MODULE'
The profile report as the review's managed comment: one markdown table
per profiler, the gate's verdict and where the numbers came from,
rewritten on every pipeline and found again by its marker. Its text is
comment.template.md beside this module, or comment.variant.template.md
under the variant, with the tables, the verdict and the shas filled in at
the template's markers.
MODULE

# CONST: The marker of the plain report's managed comment; a variant's adds the assignment.
__profile__comment__MARKER="<!-- shellops:profile-report -->"

: <<'PUB_FUN'
The managed comment's body, the template of the report's shape filled in:
one markdown table per profiler, a row per command and measure with the
base, the head and the difference, then the gate's verdict and where the
numbers came from.

  $1  Base measurements   $2  Head measurements   $3  The base sha
  $4  The breaches, as profile__breaches prints them
PUB_FUN
profile__comment__body() {
  __profile__comment__body__head_sha="$(git rev-parse HEAD 2>/dev/null | cut -c1-7 || true)"
  @keys __profile__comment__body__profilers "$2"
  __profile__comment__body__tables="$(@foreach __profile__comment__markdown_table "$__profile__comment__body__profilers" "$1" "$2")"
  __profile__comment__body__verdict="$(__profile__comment__verdict "$4")"
  __profile__comment__body__base_sha="$(printf '%.7s' "$3")"

  __profile__comment__render \
    "$__profile__comment__body__tables" \
    "$__profile__comment__body__verdict" \
    "$__profile__comment__body__base_sha" \
    "${__profile__comment__body__head_sha:-HEAD}"
}

: <<'FUN'
The comment's text: the template of the report's shape with the tables,
the verdict and the shas put in at its markers, @@TABLES@@, @@VERDICT@@,
@@BASE_SHA@@, @@HEAD_SHA@@ and @@VARIANT@@.

  $1  The tables   $2  The verdict   $3  The base sha, short
  $4  This head's short sha
FUN
__profile__comment__render() {
  __profile__comment__render__template="$(__profile__comment__template)"
  __profile__comment__render__variant="$(profile__variant)"
  __profile__comment__render__text="$(cat "$__profile__comment__render__template")"
  __profile__comment__render__text="$(string__replace "$__profile__comment__render__text" '@@TABLES@@' "$1")"
  __profile__comment__render__text="$(string__replace "$__profile__comment__render__text" '@@VERDICT@@' "$2")"
  __profile__comment__render__text="$(string__replace "$__profile__comment__render__text" '@@BASE_SHA@@' "$3")"
  __profile__comment__render__text="$(string__replace "$__profile__comment__render__text" '@@HEAD_SHA@@' "$4")"
  __profile__comment__render__text="$(string__replace "$__profile__comment__render__text" '@@VARIANT@@' "$__profile__comment__render__variant")"
  println "$__profile__comment__render__text"
}

: <<'FUN'
The template of the report's shape: comment.template.md beside this
module, whose columns are the merge base and this head, or
comment.variant.template.md under the variant, whose columns are both this
head's.
FUN
__profile__comment__template() {
  if @defined "$(profile__variant)"; then
    println "$SHELLOPS_DIR/lib/profile/comment.variant.template.md"
  else
    println "$SHELLOPS_DIR/lib/profile/comment.template.md"
  fi
}

: <<'PUB_FUN'
Rewrites the review's managed profile comment from the measurements. A
pipeline without a review or a token skips quietly, so local runs still
print.

  $1  Base measurements   $2  Head measurements   $3  The base sha
  $4  The breaches, as profile__breaches prints them
PUB_FUN
profile__sync_comment() {
  __profile__sync_comment__review="${FORGE_REVIEW_IID:-${CI_MERGE_REQUEST_IID:-}}"
  if ! @defined "$__profile__sync_comment__review"; then
    log "No code review context; skipping the profile comment."
    return 0
  fi

  __profile__sync_comment__token="${FORGE_PR_TOKEN:-${FORGE_ADMIN_TOKEN:-}}"
  if ! @defined "$__profile__sync_comment__token"; then
    log "No forge token; skipping the profile comment."
    return 0
  fi

  @obj __profile__sync_comment__options \
    '.review_number' "$__profile__sync_comment__review" \
    '.token' "$__profile__sync_comment__token"
  __profile__sync_comment__comments="$(
    forge__list_review_comments "$__profile__sync_comment__options"
  )" || return 1

  forge__sync_managed_comment \
    "$__profile__sync_comment__options" \
    "$__profile__sync_comment__comments" \
    "$(profile__marker)" \
    "$(profile__comment__body "$1" "$2" "$3" "$4")" \
    > /dev/null

  log "Profile comment is current on review $__profile__sync_comment__review."
}

: <<'PUB_FUN'
The marker of the review's managed profile comment: the plain report's,
or one that names the variant, so a variant's report is a comment of its
own beside the plain report's.

  profile__marker  ->  <!-- shellops:profile-report -->
  PROFILE_VARIANT=STRUCTS_BACKEND=silt profile__marker  ->  <!-- shellops:profile-report:STRUCTS_BACKEND=silt -->
PUB_FUN
profile__marker() {
  if @defined "$(profile__variant)"; then
    println "<!-- shellops:profile-report:$(profile__variant) -->"
  else
    println "$__profile__comment__MARKER"
  fi
}

: <<'FUN'
@foreach callback: the markdown table of the wrapped <profiler>, under its
heading.

  $1  The profiler, wrapped   $2  Base   $3  Head
FUN
__profile__comment__markdown_table() {
  @unwrap __profile__comment__markdown_table__name "$1"
  printf '## %s per command\n\n' "$__profile__comment__markdown_table__name"
  println "| command | measure | base | head | delta |"
  println "|---|---|---:|---:|---:|"
  @get __profile__comment__markdown_table__get_1 "$3" "$__profile__comment__markdown_table__name"
  @arr __profile__comment__markdown_table__arr_2
  @get __profile__comment__markdown_table__get_3 "$2" "$__profile__comment__markdown_table__name" "$__profile__comment__markdown_table__arr_2"
  @foreachi __profile__comment__markdown_rows "$__profile__comment__markdown_table__get_1" "$__profile__comment__markdown_table__get_3"
  printf '\n'
}

: <<'FUN'
@foreachi callback: one markdown row per measure of the head row <row> at
<index>, against the base row at the same index.

  $1  Head row   $2  Index   $3  Base rows
FUN
__profile__comment__markdown_rows() {
  @keys __profile__comment__markdown_rows__keys_4 "$1"
  @foreach __profile__comment__markdown_row "$__profile__comment__markdown_rows__keys_4" "$1" "$2" "$3"
}

: <<'FUN'
@foreach callback: one markdown row for the wrapped <measure> of the head
row.

  $1  The measure, wrapped   $2  Head row   $3  Index   $4  Base rows
FUN
__profile__comment__markdown_row() {
  @unwrap __profile__comment__markdown_row__measure "$1"
  if @is_false "$(profile__is_measure "$__profile__comment__markdown_row__measure")"; then
    return 0
  fi
  @get __profile__comment__markdown_row__base "$4" ".[$3].\"$__profile__comment__markdown_row__measure\"" ''
  @get __profile__comment__markdown_row__head "$2" "$__profile__comment__markdown_row__measure"
  @get __profile__comment__markdown_row__get_5 "$2" '.command'
  # shellcheck disable=SC2016  # the backticks are markdown, not a command
  printf '| `ops %s` | %s | %s | %s | %s |\n' \
    "$__profile__comment__markdown_row__get_5" \
    "$__profile__comment__markdown_row__measure" \
    "${__profile__comment__markdown_row__base:--}" \
    "$__profile__comment__markdown_row__head" \
    "$(profile__delta "$__profile__comment__markdown_row__base" "$__profile__comment__markdown_row__head")"
}

: <<'FUN'
The gate's verdict for the comment: one line when the head is within the
merge base and the ceilings, otherwise one bullet per breach.

  $1  The breaches, as profile__breaches prints them
FUN
__profile__comment__verdict() {
  if @len __profile__comment__verdict__len_6 "$1"; [ "$__profile__comment__verdict__len_6" -eq 0 ]; then
    println "Within $(profile__base_name) and \`.ops/config/profiling.yaml\`'s ceilings."
    return 0
  fi

  println "**Over the gate:**"
  @foreach __profile__comment__breach_bullet "$1"
}

: <<'FUN'
@foreach callback: one markdown bullet for a wrapped breach line.
FUN
__profile__comment__breach_bullet() {
  @unwrap __profile__comment__breach_bullet__unwrap_7 "$1"
  printf -- '- %s\n' "$__profile__comment__breach_bullet__unwrap_7"
}
