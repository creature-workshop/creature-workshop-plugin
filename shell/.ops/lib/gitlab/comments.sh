#!/bin/sh

:<<'FRAGMENT'
Comments on a GitLab merge request outside the forge contract, and the notes
fetch the contract's two listings share.
FRAGMENT

:<<'FUN'
Prints every note on a merge request, oldest first and flattened, the ones on
the conversation and the ones in threads on the diff together: GitLab serves
them as one list, and which kind each is comes back with it as .position. The
two listing roles each keep their half.

Usage: __gitlab__review_notes "$options"

  options must include .review_number (MR iid) and .token.
FUN
__gitlab__review_notes() {
  __gitlab__review_notes__options="$(__gitlab__normalize_review_options "$1")"
  __gitlab__review_notes__token="$(__gitlab__validate_token "$__gitlab__review_notes__options")" || return 1
  __gitlab__review_notes__project_path="$(__gitlab__project_path "$__gitlab__review_notes__options")" || return 1

  @get __gitlab__review_notes__iid "$__gitlab__review_notes__options" '.review_number'
  if ! @defined "$__gitlab__review_notes__iid"; then
    error "__gitlab__review_notes: missing review_number (MR iid)"
    return 1
  fi

  __gitlab__review_notes__query="$(__gitlab__load_graphql 'list-mr-notes')" || return 1
  @obj __gitlab__review_notes__variables \
    '.projectPath' "$__gitlab__review_notes__project_path" \
    '.iid'         "$(__gitlab__iid_var "$__gitlab__review_notes__iid")"
  __gitlab__review_notes__http_opts="$(__gitlab__http_opts "$__gitlab__review_notes__token")"

  __gitlab__review_notes__notes="$(
    graphql__paginate \
      "$__gitlab__GRAPHQL_ENDPOINT" \
      "$__gitlab__review_notes__http_opts" \
      "$__gitlab__review_notes__query" \
      "$__gitlab__review_notes__variables" \
      '.project.mergeRequest.notes'
  )" || return 1

  @run_awk __gitlab__review_notes__out \
    "$__gitlab__GRAPHQL_DIR/flatten_mr_notes.awk" \
    "$__gitlab__review_notes__notes" \
    --load "$__gitlab__GRAPHQL_DIR/shape.awk" || return 1
  println "$__gitlab__review_notes__out"
}

:<<'FUN'
Returns 0 when a note's type says it belongs to a thread: DiscussionNote on
the conversation, DiffNote on the diff. A standalone note has no type.

Usage: __gitlab__note_type_is_threaded "$type"
FUN
__gitlab__note_type_is_threaded() {
  [ "$1" = "DiscussionNote" ] || [ "$1" = "DiffNote" ]
}

:<<'PUB_FUN'
Creates a note on a GitLab merge request. Same workflow as the issue
variant but resolves the MR GID instead.

Usage: gitlab__create_mr_comment "$options" "$body"

  options must include .review_number (MR iid) and .token.
PUB_FUN
gitlab__create_mr_comment() {
  __gitlab__create_mr_comment__body="$2"

  __gitlab__create_mr_comment__token="$(__gitlab__validate_token "$1")" || return 1
  __gitlab__create_mr_comment__project_path="$(__gitlab__project_path "$1")" || return 1

  @get __gitlab__create_mr_comment__iid "$1" '.review_number'
  if ! @defined "$__gitlab__create_mr_comment__iid"; then
    error "Cannot create MR comment. Missing review_number (MR iid)."
    return 1
  fi

  __gitlab__create_mr_comment__http_opts="$(__gitlab__http_opts "$__gitlab__create_mr_comment__token")"

  __gitlab__create_mr_comment__id_query="$(__gitlab__load_graphql 'get-mr-id')" || return 1
  @obj __gitlab__create_mr_comment__variables \
    '.projectPath' "$__gitlab__create_mr_comment__project_path" \
    '.iid'         "$(__gitlab__iid_var "$__gitlab__create_mr_comment__iid")"

  __gitlab__create_mr_comment__result="$(__gitlab__graphql "$__gitlab__create_mr_comment__id_query" "$__gitlab__create_mr_comment__variables" "$__gitlab__create_mr_comment__http_opts")" || return 1

  @get __gitlab__create_mr_comment__mr_gid "$__gitlab__create_mr_comment__result" '.project.mergeRequest.id'
  if ! @defined "$__gitlab__create_mr_comment__mr_gid"; then
    error "Could not resolve GitLab MR GID for !${__gitlab__create_mr_comment__iid} in ${__gitlab__create_mr_comment__project_path}"
    return 1
  fi

  __gitlab__create_mr_comment__create_query="$(__gitlab__load_graphql 'create-note')" || return 1
  @obj __gitlab__create_mr_comment__create_variables \
    '.noteableId' "$__gitlab__create_mr_comment__mr_gid" \
    '.body'       "$__gitlab__create_mr_comment__body"

  __gitlab__create_mr_comment__create_result="$(__gitlab__graphql "$__gitlab__create_mr_comment__create_query" "$__gitlab__create_mr_comment__create_variables" "$__gitlab__create_mr_comment__http_opts")" || return 1

  __gitlab__check_mutation_errors "$__gitlab__create_mr_comment__create_result" 'createNote' || return 1

  @get __gitlab__create_mr_comment__out "$__gitlab__create_mr_comment__create_result" '.createNote.note'
  println "$__gitlab__create_mr_comment__out"
}
