#!/usr/bin/env bash

:<<'DOC'
GitLab API client for releases, merge requests, issue notes, label CRUD,
and group project discovery.

API protocol policy:
  - GraphQL-first. Use for releases, merge requests, notes, project queries.
  - REST only for the two operations GitLab GraphQL does not cover:
      1. Label CRUD (no general label mutations in GraphQL).
      2. Release asset file uploads (no multipart in GraphQL -- upload
         the file via REST, then register the URL via the GraphQL
         releaseAssetLinkCreate mutation).

Adaptor in the forge "sandwich" (see lib/forge/base.sh): implements the
gitlab_* contract that the lib/forge/api.sh facade dispatches to, and
sources the common base for the shared option constructors.

gitlab_* contract implemented here:
  gitlab_api_base,
  gitlab_create_release, gitlab_upload_artifact,
  gitlab_get_review, gitlab_create_review,
  gitlab_list_comments, gitlab_create_comment,
  gitlab_list_review_comments, gitlab_create_review_comment,
  gitlab_list_labels, gitlab_create_label, gitlab_edit_label,
  gitlab_list_org_repos, gitlab_get_raw_file,
  gitlab_run_status, gitlab_create_commit_status

Notable differences from other forges:
  - Prerelease flag: GitHub and Forgejo/Gitea expose a boolean
    "prerelease" on a release; GitLab has no first-class field, so
    gitlab_create_release ignores it. Callers that need to mark a release as
    preliminary should encode that in the title/body.
  - Label archival: Forgejo/Gitea can archive a label (GitHub has no
    archive concept at all). GitLab supports neither, so gitlab_edit_label
    with an archive body deletes the label instead.
  - Change-request noun: what GitHub and Forgejo/Gitea call a "pull
    request", GitLab calls a "merge request". The
    forge__new_create_review_options and gitlab_get_review names are
    kept for cross-forge parity, but they operate on MR iids.
DOC

import \
  "$SHELLOPS_DIR/lib/forge/base.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/http/api.sh" \
  "$SHELLOPS_DIR/lib/graphql/api.sh" \
  "$SHELLOPS_DIR/lib/string/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/gitlab/review_merge_command.sh" \
  "$SHELLOPS_DIR/lib/gitlab/endpoints.sh" \
  "$SHELLOPS_DIR/lib/gitlab/project.sh" \
  "$SHELLOPS_DIR/lib/gitlab/request.sh" \
  "$SHELLOPS_DIR/lib/gitlab/labels.sh" \
  "$SHELLOPS_DIR/lib/gitlab/options.sh" \
  "$SHELLOPS_DIR/lib/gitlab/payloads.sh" \
  "$SHELLOPS_DIR/lib/gitlab/comments.sh" \
  "$SHELLOPS_DIR/lib/gitlab/assignees.sh" \
  "$SHELLOPS_DIR/lib/gitlab/_landing.sh" \
  "$SHELLOPS_DIR/lib/time/api.sh"

:<<'DOC'
The gitlab forge: the roles it implements are its inner @-functions, re-homed to
gitlab_<role> when the forge facade loads the contract. The helpers live beside
this file, one per concern.
DOC
@forge.gitlab() {
  :<<'FUN'
Resolves the GitLab API base URL from GITLAB_API_BASE (same default as
internal requests use).

Usage: gitlab_api_base
FUN
  @api_base() {
    println "$__gitlab__BASE"
  }

  :<<'FUN'
The environment variable a token for GitLab arrives in when GitLab is asked by
name. The forge a run is on is asked through the stable name the facade holds
instead.

Usage: gitlab_token_env   # -> GITLAB_TOKEN
FUN
  @token_env() {
    printf 'GITLAB_TOKEN\n'
  }

  :<<'FUN'
Implements <forge>_run_status (lib/forge/base.sh). GitLab answers both
questions from the commit itself: a commit it does not hold is a 404, and one
it holds carries its latest pipeline, or none.

Usage: gitlab_run_status "$run_options"
FUN
  @run_status() {
    __gitlab_run_status__endpoint="$(__gitlab__rest_url "$1" "$__gitlab__COMMIT_ENDPOINT")" || return 1
    @get __at1 "$1" '.token' ''
    __gitlab_run_status__auth="$(forge__base__auth_header Bearer "$__at1")"
    @obj __at2
    @patch __gitlab_run_status__http_opts "$__at2" '.auth' "$__gitlab_run_status__auth"

    __gitlab_run_status__commit="$(forge__base__probe "$__gitlab_run_status__endpoint" "$__gitlab_run_status__http_opts")" || return 1
    if ! @defined "$__gitlab_run_status__commit"; then
      forge__base__not_carried
      return 0
    fi

    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/run_status.awk" \
      "$__gitlab_run_status__commit" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" \
      --load "$__gitlab__GRAPHQL_DIR/runs.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
The landing at a commit: the merge request whose merge commit it is, with
the head that was merged, GitLab's own ref for that head, and the run on
the head as GitLab holds it (lib/gitlab/landed.awk). Prints null when the
commit is no merge request's merge commit. Fails when GitLab cannot be
asked.

Usage: gitlab_landing_at "$options"   # options: .sha, .token; owner/repo optional
  ->  {"iid":12,"head":"b3d2...","head_ref":"refs/merge-requests/12/head","run":{"sha":"b3d2...","state":"success"}}
FUN
  @landing_at() {
    __gitlab_landing_at__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_landing_at__http_opts="$(__gitlab__http_opts "$__gitlab_landing_at__token")"
    __gitlab_landing_at__endpoint="$(__gitlab__rest_url "$1" "$__gitlab__COMMIT_MERGE_REQUESTS_ENDPOINT")" || return 1
    __gitlab_landing_at__reviews="$(http__get "$__gitlab_landing_at__endpoint" "$__gitlab_landing_at__http_opts")" || return 1
    @get __at3 "$1" '.sha' ''
    @obj __gitlab_landing_at__read '.reviews' "$__gitlab_landing_at__reviews" '.sha' "$__at3"
    @run_awk __gitlab_landing_at__iid "$__gitlab__GRAPHQL_DIR/landing_at.awk" "$__gitlab_landing_at__read" || return 1
    if @null __at4; [ "$__gitlab_landing_at__iid" = "$__at4" ]; then
      @null __at_out
      println "$__at_out"
      return 0
    fi

    @set __gitlab_landing_at__review_options "$1" '.review_number' "$__gitlab_landing_at__iid"
    __gitlab_landing_at__review_endpoint="$(__gitlab__rest_url "$__gitlab_landing_at__review_options" "$__gitlab__MERGE_REQUEST_ENDPOINT")" || return 1
    __gitlab_landing_at__review="$(http__get "$__gitlab_landing_at__review_endpoint" "$__gitlab_landing_at__http_opts")" || return 1

    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/landed.awk" \
      "$__gitlab_landing_at__review" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" \
      --load "$__gitlab__GRAPHQL_DIR/runs.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
Implements <forge>_create_commit_status (lib/forge/base.sh). GitLab hangs a
named status off a commit through REST; GraphQL offers no equivalent
mutation. It calls a failed run "failed" and names a status under "name",
and a commit it ran nothing on is recorded as "skipped", a state it has of
its own. The answer is the status GitLab recorded.

Usage: gitlab_create_commit_status "$commit_status_options"

  Required: sha, state, token
  Optional: name, url, description
FUN
  @create_commit_status() {
    __gitlab_create_commit_status__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_create_commit_status__endpoint="$(__gitlab__rest_url "$1" "$__gitlab__COMMIT_STATUSES_ENDPOINT")" || return 1
    __gitlab_create_commit_status__http_opts="$(__gitlab__http_opts "$__gitlab_create_commit_status__token")"

    if @get __at5 "$1" '.sha' ''; ! @defined "$__at5"; then
      error "Cannot record a commit status. Missing sha."
      return 1
    fi

    @obj __gitlab_create_commit_status__words \
      ".$forge__OUTCOME_FAILURE" 'failed' \
      ".$forge__OUTCOME_NONE"    'skipped'
    __gitlab_create_commit_status__body="$(forge__base__commit_status_body \
      "$1" \
      "$__gitlab_create_commit_status__words" \
      '.name'
    )" || return 1
    http__post \
      "$__gitlab_create_commit_status__endpoint" \
      "$__gitlab_create_commit_status__body" \
      "$__gitlab_create_commit_status__http_opts"
  }

  :<<'FUN'
Creates a release on GitLab via GraphQL releaseCreate.

Usage: gitlab_create_release "$release_options"

  Required: tag_name, token
  Optional: name, body (-> description), ref

Note: GitLab does not support a "prerelease" boolean. The .prerelease
option in $release_options is silently ignored. Callers that need to
mark a release as preliminary should encode that in title/body.
FUN
  @create_release() {
    __gitlab_create_release__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_create_release__project_path="$(__gitlab__project_path "$1")" || return 1

    @let "$1" __gitlab_create_release__ tag_name name body ref
    if ! @defined "$__gitlab_create_release__tag_name"; then
      error "Cannot create release. Missing tag_name."
      return 1
    fi

    __gitlab_create_release__query="$(__gitlab__load_graphql 'create-release')" || return 1
    @obj __gitlab_create_release__variables \
      '.projectPath' "$__gitlab_create_release__project_path" \
      '.tagName'     "$__gitlab_create_release__tag_name" \
      '.name'        "$__gitlab_create_release__name" \
      '.description' "$__gitlab_create_release__body" \
      '.ref'         "$__gitlab_create_release__ref"
    __gitlab_create_release__http_opts="$(__gitlab__http_opts "$__gitlab_create_release__token")"

    __gitlab_create_release__result="$(__gitlab__graphql "$__gitlab_create_release__query" "$__gitlab_create_release__variables" "$__gitlab_create_release__http_opts")" || return 1

    __gitlab__check_mutation_errors "$__gitlab_create_release__result" 'releaseCreate' || return 1

    # Emit a shape that looks Forgejo-ish so callers (like publish-release)
    # can keep reading `.id`. GitLab releases are keyed by tag_name, so we
    # surface that as both the id and tag_name fields.
    @get __gitlab_create_release__release "$__gitlab_create_release__result" '.releaseCreate.release'
    @set __at_out "$__gitlab_create_release__release" '.id' "$__gitlab_create_release__tag_name"
    println "$__at_out"
    __gitlab_create_release__status=$?
    @unlet __gitlab_create_release__ tag_name name body ref
    return "$__gitlab_create_release__status"
  }

  :<<'FUN'
Uploads a file as a release asset on GitLab. Two-step process: upload the
binary via the REST /uploads endpoint (which returns a URL), then attach
that URL to the release via the releaseAssetLinkCreate GraphQL mutation.

Usage: gitlab_upload_artifact "$upload_options"

  Required: tag_name (NOT release_id), filename, filepath, token
  Optional: link_type (default "other"; also "runbook", "package", "image"),
  given in lower case and sent to GitLab as its ReleaseAssetLinkType enum.
FUN
  @upload_artifact() {
    __gitlab_upload_artifact__token="$(__gitlab__validate_token "$1")" || return 1
    @let "$1" __gitlab_upload_artifact__ filepath filename tag_name link_type
    @defined "$__gitlab_upload_artifact__link_type" || __gitlab_upload_artifact__link_type='other'

    if ! @defined "$__gitlab_upload_artifact__filepath" || ! @defined "$__gitlab_upload_artifact__filename"; then
      error "Incomplete file upload information. name: '$__gitlab_upload_artifact__filename', path: '$__gitlab_upload_artifact__filepath'"
      return 1
    fi
    if ! @defined "$__gitlab_upload_artifact__tag_name"; then
      error "Cannot upload asset. Missing tag_name (GitLab release links are keyed by tag)."
      return 1
    fi

    __gitlab_upload_artifact__upload_url="$(__gitlab__rest_url "$1" "$__gitlab__UPLOADS_ENDPOINT")" || return 1
    __gitlab_upload_artifact__http_opts="$(__gitlab__http_opts "$__gitlab_upload_artifact__token")"

    log "Uploading $__gitlab_upload_artifact__filename to GitLab project uploads..."
    __gitlab_upload_artifact__upload_response="$(http__upload "$__gitlab_upload_artifact__upload_url" "$__gitlab_upload_artifact__filepath" "$__gitlab_upload_artifact__http_opts")" || return 1

    # /uploads returns {markdown, url, alt, full_path}. We want the full URL
    # so the release asset link can be resolved from anywhere.
    @get __gitlab_upload_artifact__relative_url "$__gitlab_upload_artifact__upload_response" '.url'
    if ! @defined "$__gitlab_upload_artifact__relative_url"; then
      @dump __at6 "$__gitlab_upload_artifact__upload_response"
      error "GitLab upload response did not include a .url field: $__at6"
      return 1
    fi

    # /uploads.url is relative to the project. Prepend the base + project path
    # so the resulting asset URL is dereferenceable from any client.
    __gitlab_upload_artifact__project_path="$(__gitlab__project_path "$1")" || return 1
    __gitlab_upload_artifact__asset_url="${__gitlab__BASE}/${__gitlab_upload_artifact__project_path}${__gitlab_upload_artifact__relative_url}"

    __gitlab_upload_artifact__query="$(__gitlab__load_graphql 'create-release-asset-link')" || return 1
    @obj __gitlab_upload_artifact__variables \
      '.projectPath' "$__gitlab_upload_artifact__project_path" \
      '.tagName'     "$__gitlab_upload_artifact__tag_name" \
      '.name'        "$__gitlab_upload_artifact__filename" \
      '.url'         "$__gitlab_upload_artifact__asset_url" \
      '.linkType'    "$(__gitlab__link_type_enum "$__gitlab_upload_artifact__link_type")"

    __gitlab_upload_artifact__result="$(__gitlab__graphql "$__gitlab_upload_artifact__query" "$__gitlab_upload_artifact__variables" "$__gitlab_upload_artifact__http_opts")" || return 1

    __gitlab__check_mutation_errors "$__gitlab_upload_artifact__result" 'releaseAssetLinkCreate' || return 1

    @get __at_out "$__gitlab_upload_artifact__result" '.releaseAssetLinkCreate.link'
    println "$__at_out"
    __gitlab_upload_artifact__status=$?
    @unlet __gitlab_upload_artifact__ filepath filename tag_name link_type
    return "$__gitlab_upload_artifact__status"
  }

  :<<'FUN'
Fetches merge request metadata from GitLab. Returns a shape that matches
the Forgejo pull request response so forge-agnostic callers can stay
unchanged.

Usage: gitlab_get_review '{"review_number":1, "token":"xxx"}'

  review_number is the MR iid. owner/repo fall back to manifest.json.
FUN
  @get_review() {
    __gitlab_get_review__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_get_review__project_path="$(__gitlab__project_path "$1")" || return 1

    @get __gitlab_get_review__iid "$1" '.review_number'
    if ! @defined "$__gitlab_get_review__iid"; then
      error "Cannot fetch code review. Missing review_number (MR iid)."
      return 1
    fi

    __gitlab_get_review__query="$(__gitlab__load_graphql 'get-merge-request')" || return 1
    @obj __gitlab_get_review__variables \
      '.projectPath' "$__gitlab_get_review__project_path" \
      '.iid'         "$(__gitlab__iid_var "$__gitlab_get_review__iid")"
    __gitlab_get_review__http_opts="$(__gitlab__http_opts "$__gitlab_get_review__token")"

    __gitlab_get_review__result="$(__gitlab__graphql "$__gitlab_get_review__query" "$__gitlab_get_review__variables" "$__gitlab_get_review__http_opts")" || return 1

    @get __gitlab_get_review__mr "$__gitlab_get_review__result" '.project.mergeRequest'
    if ! @defined "$__gitlab_get_review__mr"; then
      error "GitLab merge request !${__gitlab_get_review__iid} not found in ${__gitlab_get_review__project_path}"
      return 1
    fi

    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/flatten_merge_request.awk" \
      "$__gitlab_get_review__mr" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
Creates a merge request via GitLab GraphQL.

Usage: gitlab_create_review "$pull_request_options"

  pull_request_options must include .title, .head (sourceBranch),
  .base (targetBranch), and .token.

The .assignees are usernames, as they are on every forge, and gitlab__assign_review
puts them on the merge request once it exists.
FUN
  @create_review() {
    __gitlab_create_review__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_create_review__project_path="$(__gitlab__project_path "$1")" || return 1

    @let "$1" __gitlab_create_review__ title head base body labels assignees
    @defined "$__gitlab_create_review__base" || __gitlab_create_review__base='main'
    @defined "$__gitlab_create_review__labels" || @arr __gitlab_create_review__labels
    @defined "$__gitlab_create_review__assignees" || @arr __gitlab_create_review__assignees

    if ! @defined "$__gitlab_create_review__title" || ! @defined "$__gitlab_create_review__head"; then
      error "Cannot create merge request. Missing title or head (source branch)."
      return 1
    fi

    __gitlab_create_review__query="$(__gitlab__load_graphql 'create-merge-request')" || return 1
    @obj __gitlab_create_review__variables \
      '.projectPath'  "$__gitlab_create_review__project_path" \
      '.title'        "$__gitlab_create_review__title" \
      '.sourceBranch' "$__gitlab_create_review__head" \
      '.targetBranch' "$__gitlab_create_review__base" \
      '.description'  "$__gitlab_create_review__body" \
      '.labels'       "$__gitlab_create_review__labels"
    __gitlab_create_review__http_opts="$(__gitlab__http_opts "$__gitlab_create_review__token")"

    __gitlab_create_review__result="$(__gitlab__graphql "$__gitlab_create_review__query" "$__gitlab_create_review__variables" "$__gitlab_create_review__http_opts")" || return 1

    __gitlab__check_mutation_errors "$__gitlab_create_review__result" 'mergeRequestCreate' || return 1

    @get __gitlab_create_review__mr "$__gitlab_create_review__result" '.mergeRequestCreate.mergeRequest'
    @get __at7 "$__gitlab_create_review__mr" '.iid'
    @set __gitlab_create_review__assign_options "$1" \
      '.review_number' "$__at7"
    gitlab__assign_review "$__gitlab_create_review__assign_options" "$__gitlab_create_review__assignees" || return 1

    println "$__gitlab_create_review__mr"
    __gitlab_create_review__status=$?
    @unlet __gitlab_create_review__ title head base body labels assignees
    return "$__gitlab_create_review__status"
  }

  :<<'FUN'
Updates a merge request's title, description, or both.

Usage: gitlab_update_review "$options"

  options must include .review_number (MR iid) and .token, plus at least one of
  .title and .body.

An empty field means "leave this alone", not "clear it", because
forge__new_create_review_options pre-fills both with "" -- so updating only the
description would otherwise blank the title. Clearing a field is therefore not
expressible here, which no caller has wanted.
FUN
  @update_review() {
    __gitlab_update_review__options="$(__gitlab__normalize_review_options "$1")"
    __gitlab_update_review__token="$(__gitlab__validate_token "$__gitlab_update_review__options")" || return 1

    @get __gitlab_update_review__iid "$__gitlab_update_review__options" '.review_number'
    if ! @defined "$__gitlab_update_review__iid"; then
      error "gitlab_update_review: missing review_number (MR iid)"
      return 1
    fi

    __gitlab_update_review__body="$(__gitlab__merge_request_update_body "$__gitlab_update_review__options")"
    if @keys __at8 "$__gitlab_update_review__body"; @len __at9 "$__at8"; [ "$__at9" -eq 0 ]; then
      error "gitlab_update_review: nothing to update (expected title or body)"
      return 1
    fi

    __gitlab_update_review__project_id="$(__gitlab__project_id "$__gitlab_update_review__options")" || return 1
    __gitlab_update_review__endpoint="$(gitlab_api_base)/api/v4/projects/${__gitlab_update_review__project_id}/merge_requests/${__gitlab_update_review__iid}"
    __gitlab_update_review__http_opts="$(__gitlab__http_opts "$__gitlab_update_review__token")"

    http__put \
      "$__gitlab_update_review__endpoint" \
      "$__gitlab_update_review__body" \
      "$__gitlab_update_review__http_opts"
  }

  : <<'DOC'
Note id contract: every note this adaptor produces carries the gid the GitLab
GraphQL API returned, and every operation that accepts a note id — updateNote,
destroyNote — takes that gid unchanged. Callers must not parse, truncate, or
compare note ids; the id is an opaque token handed back verbatim.

  Example gid (illustrative, not a value to construct):
    gid://gitlab/DiffNote/4607

DiffNote and DiscussionNote are STI subclasses of Note. Their gids spell the
subclass name (gid://gitlab/DiffNote/..., gid://gitlab/DiscussionNote/...) and
the mutations accept all three interchangeably.
DOC

  :<<'FUN'
Lists all notes (comments) on a GitLab issue, handling pagination.

Usage: gitlab_list_comments "$comment_options"

  comment_options must include .issue_number and .token.
FUN
  @list_comments() {
    __gitlab_list_comments__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_list_comments__project_path="$(__gitlab__project_path "$1")" || return 1

    @get __gitlab_list_comments__iid "$1" '.issue_number'
    if ! @defined "$__gitlab_list_comments__iid"; then
      error "Cannot list comments. Missing issue_number (iid)."
      return 1
    fi

    __gitlab_list_comments__query="$(__gitlab__load_graphql 'list-issue-notes')" || return 1
    @obj __gitlab_list_comments__variables \
      '.projectPath' "$__gitlab_list_comments__project_path" \
      '.iid'         "$(__gitlab__iid_var "$__gitlab_list_comments__iid")"
    __gitlab_list_comments__http_opts="$(__gitlab__http_opts "$__gitlab_list_comments__token")"

    graphql__paginate \
      "$__gitlab__GRAPHQL_ENDPOINT" \
      "$__gitlab_list_comments__http_opts" \
      "$__gitlab_list_comments__query" \
      "$__gitlab_list_comments__variables" \
      '.project.issue.notes'
  }

  :<<'FUN'
Creates a note (comment) on a GitLab issue.

The createNote mutation requires the global Noteable GID (e.g.
"gid://gitlab/Issue/123"), not the project-scoped iid. We resolve it
with one extra round-trip.

Usage: gitlab_create_comment "$comment_options" "$body"

  comment_options must include .issue_number and .token.
FUN
  @create_comment() {
    __gitlab_create_comment__body="$2"

    __gitlab_create_comment__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_create_comment__project_path="$(__gitlab__project_path "$1")" || return 1

    @get __gitlab_create_comment__iid "$1" '.issue_number'
    if ! @defined "$__gitlab_create_comment__iid"; then
      error "Cannot create comment. Missing issue_number (iid)."
      return 1
    fi

    __gitlab_create_comment__http_opts="$(__gitlab__http_opts "$__gitlab_create_comment__token")"

    __gitlab_create_comment__id_query="$(__gitlab__load_graphql 'get-issue-id')" || return 1
    @obj __gitlab_create_comment__variables \
      '.projectPath' "$__gitlab_create_comment__project_path" \
      '.iid'         "$(__gitlab__iid_var "$__gitlab_create_comment__iid")"

    __gitlab_create_comment__result="$(__gitlab__graphql "$__gitlab_create_comment__id_query" "$__gitlab_create_comment__variables" "$__gitlab_create_comment__http_opts")" || return 1

    @get __gitlab_create_comment__issue_gid "$__gitlab_create_comment__result" '.project.issue.id'
    if ! @defined "$__gitlab_create_comment__issue_gid"; then
      error "Could not resolve GitLab issue GID for !${__gitlab_create_comment__iid} in ${__gitlab_create_comment__project_path}"
      return 1
    fi

    __gitlab_create_comment__create_query="$(__gitlab__load_graphql 'create-note')" || return 1
    @obj __gitlab_create_comment__create_variables \
      '.noteableId' "$__gitlab_create_comment__issue_gid" \
      '.body'       "$__gitlab_create_comment__body"

    __gitlab_create_comment__create_result="$(__gitlab__graphql "$__gitlab_create_comment__create_query" "$__gitlab_create_comment__create_variables" "$__gitlab_create_comment__http_opts")" || return 1

    __gitlab__check_mutation_errors "$__gitlab_create_comment__create_result" 'createNote' || return 1

    @get __at_out "$__gitlab_create_comment__create_result" '.createNote.note'
    println "$__at_out"
  }

  :<<'FUN'
Lists the notes on a merge request's conversation, oldest first, with each
note carrying the gid the API returned, a .type field for reply detection,
and .discussion, the thread it sits in: {id, first_note: {id, body}}, where
a note whose id is its thread's first_note.id opened the thread. A note
anchored to a line of the diff is not among them; those are
gitlab_list_review_thread_comments.

Usage: gitlab_list_review_comments "$options"

  options must include .review_number (MR iid) and .token.
FUN
  @list_review_comments() {
    __gitlab_list_review_comments__notes="$(__gitlab__review_notes "$1")" || return 1

    @run_awk __at_out "$__gitlab__GRAPHQL_DIR/mr_conversation_notes.awk" "$__gitlab_list_review_comments__notes" || return 1
    println "$__at_out"
  }

  :<<'FUN'
Lists the notes in the threads on a merge request's diff, oldest first, in the
same shape as gitlab_list_review_comments, .discussion included, plus the
.position each is anchored to: {filePath, newLine, oldLine}.

Usage: gitlab_list_review_thread_comments "$options"

  options must include .review_number (MR iid) and .token.
FUN
  @list_review_thread_comments() {
    __gitlab_list_review_thread_comments__notes="$(__gitlab__review_notes "$1")" || return 1

    @run_awk __at_out "$__gitlab__GRAPHQL_DIR/mr_thread_notes.awk" "$__gitlab_list_review_thread_comments__notes" || return 1
    println "$__at_out"
  }

  @create_review_comment() {
    gitlab__create_mr_comment "$(__gitlab__normalize_review_options "$1")" "$2"
  }

  :<<'FUN'
Replaces the body of an existing note on a merge request.

The note is addressed by its gid (.comment_id), so neither the project path
nor the MR iid is sent to the API — the gid is globally unique.

Usage: gitlab_update_review_comment "$options" "$body"

  options must include .comment_id (note gid) and .token.
FUN
  @update_review_comment() {
    __gitlab_update_review_comment__options="$(__gitlab__normalize_review_options "$1")"
    __gitlab_update_review_comment__token="$(__gitlab__validate_token "$__gitlab_update_review_comment__options")" || return 1

    @get __gitlab_update_review_comment__note_id "$__gitlab_update_review_comment__options" '.comment_id'
    if ! @defined "$__gitlab_update_review_comment__note_id"; then
      error "gitlab_update_review_comment: missing comment_id (note gid)"
      return 1
    fi

    __gitlab_update_review_comment__query="$(__gitlab__load_graphql 'update-note')" || return 1
    @obj __gitlab_update_review_comment__variables \
      '.noteId' "$__gitlab_update_review_comment__note_id" \
      '.body'   "$2"
    __gitlab_update_review_comment__http_opts="$(__gitlab__http_opts "$__gitlab_update_review_comment__token")"

    __gitlab_update_review_comment__result="$(
      __gitlab__graphql \
        "$__gitlab_update_review_comment__query" \
        "$__gitlab_update_review_comment__variables" \
        "$__gitlab_update_review_comment__http_opts"
    )" || return 1

    __gitlab__check_mutation_errors "$__gitlab_update_review_comment__result" 'updateNote' || return 1

    @get __at_out "$__gitlab_update_review_comment__result" '.updateNote.note'
    println "$__at_out"
  }

  :<<'FUN'
Removes a note from a merge request.

The note is addressed by its gid (.comment_id), so neither the project path
nor the MR iid is sent to the API — the gid is globally unique.

Usage: gitlab_delete_review_comment "$options"

  options must include .comment_id (note gid) and .token.
FUN
  @delete_review_comment() {
    __gitlab_delete_review_comment__options="$(__gitlab__normalize_review_options "$1")"
    __gitlab_delete_review_comment__token="$(__gitlab__validate_token "$__gitlab_delete_review_comment__options")" || return 1

    @get __gitlab_delete_review_comment__note_id "$__gitlab_delete_review_comment__options" '.comment_id'
    if ! @defined "$__gitlab_delete_review_comment__note_id"; then
      error "gitlab_delete_review_comment: missing comment_id (note gid)"
      return 1
    fi

    __gitlab_delete_review_comment__query="$(__gitlab__load_graphql 'destroy-note')" || return 1
    @obj __gitlab_delete_review_comment__variables \
      '.noteId' "$__gitlab_delete_review_comment__note_id"
    __gitlab_delete_review_comment__http_opts="$(__gitlab__http_opts "$__gitlab_delete_review_comment__token")"

    __gitlab_delete_review_comment__result="$(
      __gitlab__graphql \
        "$__gitlab_delete_review_comment__query" \
        "$__gitlab_delete_review_comment__variables" \
        "$__gitlab_delete_review_comment__http_opts"
    )" || return 1

    __gitlab__check_mutation_errors "$__gitlab_delete_review_comment__result" 'destroyNote'
  }

  :<<'FUN'
Lists all repository labels, handling pagination automatically.

Returns labels normalized to the Forgejo response shape (color without
leading '#') so labels/api.sh labels__diff_labels works unchanged.

Usage: gitlab_list_labels "$label_options"
FUN
  @list_labels() {
    __gitlab_list_labels__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_list_labels__endpoint="$(__gitlab__rest_url "$1" "$__gitlab__LABELS_ENDPOINT")" || return 1
    __gitlab_list_labels__http_opts="$(__gitlab__http_opts "$__gitlab_list_labels__token")"

    __gitlab_list_labels__all_labels="$(__gitlab__rest_paginate "$__gitlab_list_labels__endpoint" "$__gitlab_list_labels__http_opts")" || return 1

    # Reshape to forgejo-compatible records so labels__diff_labels matches without
    # any forge-specific normalization.
    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/flatten_labels.awk" \
      "$__gitlab_list_labels__all_labels" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
Creates a label on the repository.

Usage: gitlab_create_label "$label_options" "$label_data"

  label_data is a JSON object with: name, color, description
  GitLab requires color to be hash-prefixed (#rrggbb); it is added
  automatically if missing.
FUN
  @create_label() {
    __gitlab_create_label__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_create_label__endpoint="$(__gitlab__rest_url "$1" "$__gitlab__LABELS_ENDPOINT")" || return 1
    __gitlab_create_label__http_opts="$(__gitlab__http_opts "$__gitlab_create_label__token")"

    __gitlab_create_label__body="$(__gitlab__normalize_label_body "$2")"
    http__post "$__gitlab_create_label__endpoint" "$__gitlab_create_label__body" "$__gitlab_create_label__http_opts"
  }

  :<<'FUN'
Updates a label on the repository.

GitLab uses PUT (not PATCH) for label updates. When edit_data carries
{"is_archived": true} -- the Forgejo archive sentinel -- GitLab has no
archive; we delete the label instead so the diff outcome matches.

Usage: gitlab_edit_label "$label_options" "$edit_data"

  label_options must include .label_id (numeric label id from GitLab).
  edit_data is a JSON object with any of: name, color, description.
FUN
  @edit_label() {
    __gitlab_edit_label__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_edit_label__endpoint="$(__gitlab__rest_url "$1" "$__gitlab__LABEL_ENDPOINT")" || return 1
    __gitlab_edit_label__http_opts="$(__gitlab__http_opts "$__gitlab_edit_label__token")"

    @get __gitlab_edit_label__is_archived "$2" '.is_archived' 'false'
    if [ "$__gitlab_edit_label__is_archived" = "true" ]; then
      http__delete "$__gitlab_edit_label__endpoint" "$__gitlab_edit_label__http_opts"
      return $?
    fi

    __gitlab_edit_label__body="$(__gitlab__normalize_label_body "$2")"
    http__put "$__gitlab_edit_label__endpoint" "$__gitlab_edit_label__body" "$__gitlab_edit_label__http_opts"
  }

  :<<'FUN'
Lists all non-archived projects in a GitLab group, handling pagination.

Returns projects shaped like the Forgejo response (name, full_name,
archived, html_url, etc.) so callers can stay forge-agnostic.

Usage: gitlab_list_org_repos "$org_options"
FUN
  @list_org_repos() {
    __gitlab_list_org_repos__token="$(__gitlab__validate_token "$1")" || return 1
    @get __gitlab_list_org_repos__org "$1" '.org'
    if ! @defined "$__gitlab_list_org_repos__org"; then
      error "Cannot list group projects. Missing org."
      return 1
    fi

    __gitlab_list_org_repos__query="$(__gitlab__load_graphql 'list-group-projects')" || return 1
    @obj __gitlab_list_org_repos__variables '.groupPath' "$__gitlab_list_org_repos__org"
    __gitlab_list_org_repos__http_opts="$(__gitlab__http_opts "$__gitlab_list_org_repos__token")"

    __gitlab_list_org_repos__all_nodes="$(
      graphql__paginate \
        "$__gitlab__GRAPHQL_ENDPOINT" \
        "$__gitlab_list_org_repos__http_opts" \
        "$__gitlab_list_org_repos__query" \
        "$__gitlab_list_org_repos__variables" \
        '.group.projects'
    )" || return 1

    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/flatten_group_projects.awk" \
      "$__gitlab_list_org_repos__all_nodes" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
The username the options' token authenticates as, on the instance the options'
.host names.

Usage: gitlab_current_user "$options"   # -> blizz
FUN
  @current_user() {
    __gitlab_current_user__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_current_user__endpoint="$(__gitlab__instance "$1")$__gitlab__USER_ENDPOINT"
    __gitlab_current_user__http_opts="$(__gitlab__http_opts "$__gitlab_current_user__token")"

    __gitlab_current_user__user="$(http__get "$__gitlab_current_user__endpoint" "$__gitlab_current_user__http_opts")" || return 1
    @get __at_out "$__gitlab_current_user__user" '.username'
    println "$__at_out"
  }

  :<<'FUN'
Fetches a raw file from a GitLab repository.

Implementation note: GraphQL Repository.blobs technically covers this
(rawTextBlob field), but it b64-encodes binary content in a separate
field and the REST raw endpoint streams the file as-is regardless of
content type. REST keeps the function shape one-call and forge-parallel
with forgejo_get_raw_file.

Usage: gitlab_get_raw_file "$options" "$filepath" [ref]

  options must include .owner and .repo and .token.
  ref defaults to "HEAD" if not provided.
FUN
  @get_raw_file() {
    __gitlab_get_raw_file__ref="${3:-HEAD}"

    __gitlab_get_raw_file__token="$(__gitlab__validate_token "$1")" || return 1

    # GitLab's file path segment must be URL-encoded (slashes become %2F).
    __gitlab_get_raw_file__encoded_path="$(__gitlab__url_encode "$2")"
    @set __gitlab_get_raw_file__opts_with_path "$1" '.filepath_encoded' "$__gitlab_get_raw_file__encoded_path"

    __gitlab_get_raw_file__endpoint="$(__gitlab__rest_url "$__gitlab_get_raw_file__opts_with_path" "$__gitlab__RAW_FILE_ENDPOINT")" || return 1
    __gitlab_get_raw_file__endpoint="${__gitlab_get_raw_file__endpoint}?ref=${__gitlab_get_raw_file__ref}"
    __gitlab_get_raw_file__http_opts="$(__gitlab__http_opts "$__gitlab_get_raw_file__token")"

    http__get "$__gitlab_get_raw_file__endpoint" "$__gitlab_get_raw_file__http_opts"
  }

  :<<'FUN'
Lists the code reviews (GitLab merge requests) merged into a branch at or after
an ISO timestamp, flattened to records shaped:

  [{iid, merged_at, labels:[title...]}]

GraphQL-first: paginate project.mergeRequests via graphql__paginate, then flatten
with flatten_merged_mrs.awk. Token comes from the active forge admin token via the
options blob.

Args:
  $1 since    ISO-8601 timestamp (the last tag's date); only code reviews
              merged at or after it are returned. Empty selects every merged
              code review (no prior tag -- aggregate from genesis).
  $2 branch   Target branch whose merged code reviews to list.

Usage:
  forge__merged_reviews_since "$since" "$branch"
  gitlab_merged_reviews_since "$since" "$branch"
FUN
  @merged_reviews_since() {
    __gitlab_merged_reviews_since__gitlab_merged_crs__since="$1"
    __gitlab_merged_reviews_since__gitlab_merged_crs__branch="$2"

    # Token-only options: leave owner/repo unset so __gitlab__project_path
    # resolves the (subgroup-correct) path from CI_PROJECT_PATH / the git remote
    # rather than the flat manifest identity -- same reasoning as
    # __gitlab__normalize_review_options.
    @obj __at10
    @set __gitlab_merged_reviews_since__gitlab_merged_crs__options "$__at10" '.token' "${FORGE_ADMIN_TOKEN:-}"
    __gitlab_merged_reviews_since__gitlab_merged_crs__token="$(__gitlab__validate_token "$__gitlab_merged_reviews_since__gitlab_merged_crs__options")" || return 1
    __gitlab_merged_reviews_since__gitlab_merged_crs__path="$(__gitlab__project_path "$__gitlab_merged_reviews_since__gitlab_merged_crs__options")" || return 1

    __gitlab_merged_reviews_since__gitlab_merged_crs__query="$(__gitlab__load_graphql 'list-merged-mrs')" || return 1
    @obj __at11
    @set __gitlab_merged_reviews_since__gitlab_merged_crs__variables "$__at11" \
      '.fullPath' "$__gitlab_merged_reviews_since__gitlab_merged_crs__path" \
      '.branch' "$__gitlab_merged_reviews_since__gitlab_merged_crs__branch" \
      '.since' "$(__gitlab__since_var "$__gitlab_merged_reviews_since__gitlab_merged_crs__since")"
    __gitlab_merged_reviews_since__gitlab_merged_crs__http_opts="$(__gitlab__http_opts "$__gitlab_merged_reviews_since__gitlab_merged_crs__token")"

    __gitlab_merged_reviews_since__gitlab_merged_crs__nodes="$(
      graphql__paginate \
        "$__gitlab__GRAPHQL_ENDPOINT" \
        "$__gitlab_merged_reviews_since__gitlab_merged_crs__http_opts" \
        "$__gitlab_merged_reviews_since__gitlab_merged_crs__query" \
        "$__gitlab_merged_reviews_since__gitlab_merged_crs__variables" \
        '.project.mergeRequests'
    )" || return 1

    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/flatten_merged_mrs.awk" \
      "$__gitlab_merged_reviews_since__gitlab_merged_crs__nodes" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" \
      --arg since "$__gitlab_merged_reviews_since__gitlab_merged_crs__since" || return 1
    println "$__at_out"
  }

  :<<'FUN'
The GitLab project's default branch. GitLab CI provides it as CI_DEFAULT_BRANCH;
outside CI, fall back to the repository's default branch from git.

Usage: gitlab_default_branch   # -> main
FUN
  @default_branch() {
    println "${CI_DEFAULT_BRANCH:-$(git__default_branch)}"
  }

  :<<'FUN'
Prints the merge-request iids referenced in the given commit-message text,
one per line. Recognizes GitLab's "See merge request <path>!<iid>" footer,
which GitLab writes into the merge commit of an accepted merge request.

Usage: gitlab_code_review_refs "$commit_text"
FUN
  @code_review_refs() {
    println "$1" \
      | grep -oiE 'merge request [^[:space:]]*![0-9]+' \
      | grep -oE '![0-9]+' \
      | tr -d '!' \
      || true
  }

  :<<'FUN'
The iid of the merge request this pipeline is building, or nothing when it is
building a branch.

GitLab sets CI_MERGE_REQUEST_IID only on merge-request pipelines, so its presence
is what distinguishes the two, and the iid is the useful form of that answer.

Usage:
  review="$(forge__current_review)"    # -> 136, or ""
  review="$(gitlab_current_review)"
FUN
  @current_review() {
    println "${CI_MERGE_REQUEST_IID:-}"
  }

  :<<'FUN'
The labels of the merge request this pipeline is building, as a struct array of
label names. Empty when the merge request carries none, which is why callers
establish context with gitlab_current_review first rather than reading emptiness
as absence.

GitLab supplies them comma-separated in CI_MERGE_REQUEST_LABELS. Names come back
de-duplicated and sorted; labels are consumed as a set, so order carries no
meaning.

Usage:
  forge__review_labels    # -> ["area/cli","type/fix"]
  gitlab_review_labels
FUN
  @review_labels() {
    @split __at12 "${CI_MERGE_REQUEST_LABELS:-}" ","
    @unique __at_out "$__at12"
    println "$__at_out"
  }

  :<<'FUN'
Adds and removes labels on a merge request in one update, leaving every other
label as it is. ADD and REMOVE are struct arrays of label names; an empty one
is left out of the request, and when both are empty nothing is sent.

A name the project has not defined is dropped by GitLab without a word, so a
caller that wants a label to stick has the project define it first (action
forge sync-labels).

Usage: gitlab_reconcile_review_labels "$options" "$add" "$remove"
FUN
  @reconcile_review_labels() {
    __gitlab_reconcile_review_labels__options="$(__gitlab__normalize_review_options "$1")"
    __gitlab_reconcile_review_labels__token="$(__gitlab__validate_token "$__gitlab_reconcile_review_labels__options")" || return 1

    @get __gitlab_reconcile_review_labels__iid "$__gitlab_reconcile_review_labels__options" '.review_number'
    if ! @defined "$__gitlab_reconcile_review_labels__iid"; then
      error "gitlab_reconcile_review_labels: missing review_number (MR iid)"
      return 1
    fi

    __gitlab_reconcile_review_labels__body="$(__gitlab__label_change_body "$2" "$3")"
    if @keys __at13 "$__gitlab_reconcile_review_labels__body"; @len __at14 "$__at13"; [ "$__at14" -eq 0 ]; then
      return 0
    fi

    __gitlab_reconcile_review_labels__project_id="$(__gitlab__project_id "$__gitlab_reconcile_review_labels__options")" || return 1
    __gitlab_reconcile_review_labels__endpoint="$(gitlab_api_base)/api/v4/projects/${__gitlab_reconcile_review_labels__project_id}/merge_requests/${__gitlab_reconcile_review_labels__iid}"
    __gitlab_reconcile_review_labels__http_opts="$(__gitlab__http_opts "$__gitlab_reconcile_review_labels__token")"

    http__put \
      "$__gitlab_reconcile_review_labels__endpoint" \
      "$__gitlab_reconcile_review_labels__body" \
      "$__gitlab_reconcile_review_labels__http_opts"
  }

  :<<'FUN'
Prints true when the comment is a reply to another, false otherwise.

GitLab threads replies, so this is structural rather than a guess: a note
carries type "DiscussionNote" exactly when it belongs to a thread on the
conversation, "DiffNote" when it belongs to one on the diff, and a standalone
note carries no type at all.

The thread's opening note carries the type too, so this reads nearer to
"belongs to a conversation" than "is not the first thing said in one". That is
the useful sense for callers, who ask in order to tell whether a quotation in
the body is the author's own or an echo of what they are answering.

Usage: gitlab_comment_is_reply "$comment"
FUN
  @comment_is_reply() {
    @get __at15 "$1" '.type' ''
    @succeeds __at_out __gitlab__note_type_is_threaded "$__at15"
    println "$__at_out"
  }

  :<<'FUN'
The commit range this pipeline was triggered for, or nothing when there is no
baseline to compare against.

GitLab gives both ends directly: CI_COMMIT_BEFORE_SHA is what the ref pointed at
before the push, all zeros on the first one. CI_COMMIT_SHA is unset outside CI,
where HEAD is the honest reading of "as far as the range goes".

Usage: range="$(gitlab_pushed_range)"   # -> abc123..def456, or ""
FUN
  @pushed_range() {
    forge__base__range "${CI_COMMIT_BEFORE_SHA:-}" "${CI_COMMIT_SHA:-HEAD}"
  }

  :<<'FUN'
Hands a merge request back to a reviewer, clearing their changes-requested
state.

GitLab spells this as the /request_review quick action rather than a field on
the merge request, so the request is a note whose whole body is the action.

Usage: gitlab_request_review "$review_options"

  review_options must include .review_number (MR iid), .reviewer (username), and
  .token.
FUN
  @request_review() {
    @get __gitlab_request_review__reviewer "$1" '.reviewer'
    if ! @defined "$__gitlab_request_review__reviewer"; then
      error "Cannot request review. Missing reviewer username."
      return 1
    fi

    gitlab__create_mr_comment \
      "$(__gitlab__normalize_review_options "$1")" \
      "/request_review @$__gitlab_request_review__reviewer"
  }

  :<<'FUN'
The open merge requests whose reviewers asked for changes and have not been
asked to look again, flattened to records shaped:

  [{iid, url, branch, draft, reviewers:[username...]}]

Every open merge request in the project is considered, whoever wrote it.

Usage:
  forge__reviews_awaiting_author "$review_options"
  gitlab_reviews_awaiting_author "$review_options"

  review_options must include .token; .branch scopes the answer to one source
  branch and selects every open merge request when empty.
FUN
  @reviews_awaiting_author() {
    __gitlab_reviews_awaiting_author__gitlab_awaiting_author__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_reviews_awaiting_author__gitlab_awaiting_author__path="$(__gitlab__project_path "$1")" || return 1

    __gitlab_reviews_awaiting_author__gitlab_awaiting_author__query="$(__gitlab__load_graphql 'list-mrs-awaiting-author')" || return 1
    @get __at16 "$1" '.branch' ''
    @obj __gitlab_reviews_awaiting_author__gitlab_awaiting_author__variables \
      '.fullPath' "$__gitlab_reviews_awaiting_author__gitlab_awaiting_author__path" \
      '.branches' "$(__gitlab__branches_var "$__at16")"

    __gitlab_reviews_awaiting_author__gitlab_awaiting_author__http_opts="$(__gitlab__http_opts "$__gitlab_reviews_awaiting_author__gitlab_awaiting_author__token")"
    __gitlab_reviews_awaiting_author__gitlab_awaiting_author__http_opts="$(forge__base__with_budget "$__gitlab_reviews_awaiting_author__gitlab_awaiting_author__http_opts" "$1")"

    __gitlab_reviews_awaiting_author__gitlab_awaiting_author__nodes="$(
      graphql__paginate \
        "$__gitlab__GRAPHQL_ENDPOINT" \
        "$__gitlab_reviews_awaiting_author__gitlab_awaiting_author__http_opts" \
        "$__gitlab_reviews_awaiting_author__gitlab_awaiting_author__query" \
        "$__gitlab_reviews_awaiting_author__gitlab_awaiting_author__variables" \
        '.project.mergeRequests'
    )" || return 1

    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/flatten_mrs_awaiting_author.awk" \
      "$__gitlab_reviews_awaiting_author__gitlab_awaiting_author__nodes" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
A username as a GitLab mention: the markup that makes GitLab notify that user.

Usage: gitlab_mention "jerrod"   # -> @jerrod
FUN
  @mention() {
    printf '@%s\n' "$1"
  }

  :<<'FUN'
Prints the reference a merge request is written as in prose and commit
messages: its iid behind a bang.

Usage: gitlab_review_ref 12  # -> !12
FUN
  @review_ref() {
    printf '!%s\n' "$1"
  }

  :<<'FUN'
Parses the group path, project, and merge request iid from a merge request
URL on this GitLab, in the form {owner, repo, review_number}. The owner is
the full group path, nested groups included. Prints nothing when the page
is unrecognized.

  gitlab_review_from_url https://gitlab.example.com/org/sub/tool/-/merge_requests/7#note_1
    -> {"owner": "org/sub", "repo": "tool", "review_number": 7}

Usage: gitlab_review_from_url "$url"
FUN
  @review_from_url() {
    forge__base__review_from_url "$1" "$__gitlab__BASE" "$__gitlab__MERGE_REQUEST_PAGE"
  }

  :<<'FUN'
Given an object {owner, repo, review_number}, prints the URL of the merge
request on this GitLab. The owner is the group path.

  gitlab_review_url '{"owner": "org/sub", "repo": "tool", "review_number": 7}'
    -> https://gitlab.example.com/org/sub/tool/-/merge_requests/7

Usage: gitlab_review_url "$options"
FUN
  @review_url() {
    forge__base__review_url "$1" "$__gitlab__BASE" "$__gitlab__MERGE_REQUEST_PAGE"
  }

  :<<'FUN'
Prints the project this adaptor is working in, as {owner, repo}, with the
group path as the owner: the project GitLab names in CI_PROJECT_PATH for its
own pipeline, else the one the origin remote points at, else the manifest's
org and repo.

  gitlab_repository  ->  {"owner": "org/sub", "repo": "tool"}

Usage: gitlab_repository
FUN
  @repository() {
    @obj __gitlab_repository__nothing
    __gitlab_repository__path="$(__gitlab__project_path "$__gitlab_repository__nothing")" || return 1

    forge__base__repository_of "$__gitlab_repository__path"
  }

  :<<'FUN'
The commit range the merge-request pipeline builds, as <base>..<head>, and
nothing outside a merge-request pipeline. GitLab gives both ends directly: the
commit when the pipeline started in CI_MERGE_REQUEST_DIFF_BASE_SHA, which is
set on merge-request pipelines alone, and the commit under review in
CI_COMMIT_SHA.

Usage: range="$(gitlab_review_commit_range)"   # -> abc123..def456, or ""
FUN
  @review_commit_range() {
    forge__base__range "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" "${CI_COMMIT_SHA:-HEAD}"
  }

  :<<'FUN'
Prints the push options that ask GitLab to create no pipeline for the push
they travel with: ci.skip, which GitLab reads off the push and applies to
that push alone.

Usage: gitlab_no_run_push_options   # -> ["ci.skip"]
FUN
  @no_run_push_options() {
    @arr __at_out ci.skip
    println "$__at_out"
  }

  :<<'FUN'
The open merge request whose source branch is BRANCH, with its head pipeline
and that pipeline's jobs: each job's numeric id, name, status, and whether it
left an artifacts archive. Fails when no open merge request comes from the
branch.

  gitlab_review_for_branch '{"branch":"feat/lower","token":"x"}'
  -> {"iid":"12","base":"main","pipeline":{"id":"3092","status":"FAILED"},
      "jobs":[{"id":"20359","name":"shellops/shell/test","status":"FAILED","archive":true}, ...]}

Usage: gitlab_review_for_branch "$options"   # .branch, .token, owner/repo optional
FUN
  @review_for_branch() {
    __gitlab_review_for_branch__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_review_for_branch__project_path="$(__gitlab__project_path "$1")" || return 1
    @get __gitlab_review_for_branch__branch "$1" '.branch'
    if ! @defined "$__gitlab_review_for_branch__branch"; then
      error "gitlab_review_for_branch: missing branch"
      return 1
    fi

    __gitlab_review_for_branch__query="$(__gitlab__load_graphql 'get-branch-review')" || return 1
    @obj __gitlab_review_for_branch__variables \
      '.projectPath' "$__gitlab_review_for_branch__project_path" \
      '.branch'      "$__gitlab_review_for_branch__branch"
    __gitlab_review_for_branch__http_opts="$(__gitlab__http_opts "$__gitlab_review_for_branch__token")"
    __gitlab_review_for_branch__result="$(__gitlab__graphql \
      "$__gitlab_review_for_branch__query" \
      "$__gitlab_review_for_branch__variables" \
      "$__gitlab_review_for_branch__http_opts"
    )" || return 1

    @get __gitlab_review_for_branch__mr "$__gitlab_review_for_branch__result" '.project.mergeRequests.nodes[0]'
    if ! @defined "$__gitlab_review_for_branch__mr"; then
      error "No open GitLab merge request from branch '$__gitlab_review_for_branch__branch' in $__gitlab_review_for_branch__project_path"
      return 1
    fi

    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/flatten_branch_review.awk" \
      "$__gitlab_review_for_branch__mr" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
A merge request by number, open or merged, with its head pipeline and that
pipeline's jobs, in the shape gitlab_review_for_branch answers with. A merged
request's branch is gone but its pipelines are not, which is what lets a
later pipeline read the archives it left. Fails when the project has no such
merge request.

  gitlab_review_pipeline '{"review_number":"12","token":"x"}'
  -> {"iid":"12","base":"main","pipeline":{"id":"3092","status":"SUCCESS"},
      "jobs":[{"id":"20359","name":"shellops/testing/impacted","status":"SUCCESS","archive":true}, ...]}

Usage: gitlab_review_pipeline "$options"   # .review_number, .token, owner/repo optional
FUN
  @review_pipeline() {
    __gitlab_review_pipeline__token="$(__gitlab__validate_token "$1")" || return 1
    __gitlab_review_pipeline__project_path="$(__gitlab__project_path "$1")" || return 1
    @get __gitlab_review_pipeline__number "$1" '.review_number' ''
    if ! @defined "$__gitlab_review_pipeline__number"; then
      error "gitlab_review_pipeline: missing review_number"
      return 1
    fi

    __gitlab_review_pipeline__query="$(__gitlab__load_graphql 'get-review-pipeline')" || return 1
    @obj __gitlab_review_pipeline__variables \
      '.projectPath' "$__gitlab_review_pipeline__project_path" \
      '.iid'         "$(__gitlab__iid_var "$__gitlab_review_pipeline__number")"
    __gitlab_review_pipeline__http_opts="$(__gitlab__http_opts "$__gitlab_review_pipeline__token")"
    __gitlab_review_pipeline__result="$(__gitlab__graphql \
      "$__gitlab_review_pipeline__query" \
      "$__gitlab_review_pipeline__variables" \
      "$__gitlab_review_pipeline__http_opts"
    )" || return 1

    @get __gitlab_review_pipeline__mr "$__gitlab_review_pipeline__result" '.project.mergeRequest'
    if ! @defined "$__gitlab_review_pipeline__mr"; then
      error "GitLab merge request !${__gitlab_review_pipeline__number} not found in ${__gitlab_review_pipeline__project_path}"
      return 1
    fi

    @run_awk __at_out \
      "$__gitlab__GRAPHQL_DIR/flatten_branch_review.awk" \
      "$__gitlab_review_pipeline__mr" \
      --load "$__gitlab__GRAPHQL_DIR/shape.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
Downloads the artifacts archive a job kept, as the zip GitLab serves, to DEST.

Usage: gitlab_download_job_artifacts '{"job_id":"20359","token":"x"}' /tmp/20359.zip
FUN
  @download_job_artifacts() {
    __gitlab_download_job_artifacts__token="$(__gitlab__validate_token "$1")" || return 1
    if @get __at17 "$1" '.job_id' ''; ! @defined "$__at17"; then
      error "gitlab_download_job_artifacts: missing job_id"
      return 1
    fi

    __gitlab_download_job_artifacts__url="$(__gitlab__rest_url "$1" "$__gitlab__JOB_ARTIFACTS_ENDPOINT")" || return 1
    http__download \
      "$__gitlab_download_job_artifacts__url" \
      "$2" \
      "$(__gitlab__http_opts "$__gitlab_download_job_artifacts__token")"
  }

  :<<'FUN'
The run this job belongs to, read off the runner's environment: the pipeline,
the commit it builds, the ref GitLab lists it under, and, in a merge-request
pipeline, the merge request, the commit the request was rebased onto when the
pipeline was created, and whether the pipeline is a landing one.

GitLab lists a merge-request pipeline under refs/merge-requests/<iid>/head,
which CI_MERGE_REQUEST_REF_PATH spells, and a branch or tag pipeline under
the branch or tag. A landing pipeline is one created while the merge request
carried the scheduler's landing mark: GitLab fixes CI_MERGE_REQUEST_LABELS
when it creates a pipeline, so the mark is read as it stood at that moment,
and a pipeline created before the mark is not landing.

  gitlab_current_run
  -> {"pipeline_id":4254,"sha":"63489e55...","ref":"main","review_number":"",
      "base_sha":"","landing":false}

Usage: gitlab_current_run
FUN
  @current_run() {
    @any __at18 __gitlab__is_landing_label "$(gitlab_review_labels)"
    @obj __at_out \
      '.pipeline_id'   "${CI_PIPELINE_ID:-}" \
      '.sha'           "${CI_COMMIT_SHA:-}" \
      '.ref'           "${CI_MERGE_REQUEST_REF_PATH:-${CI_COMMIT_REF_NAME:-}}" \
      '.review_number' "${CI_MERGE_REQUEST_IID:-}" \
      '.base_sha'      "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" \
      '.landing'       "$__at18"
    println "$__at_out"
  }

  :<<'FUN'
The commit at the head of a branch, by the branch's name. Fails when the
project has no such branch.

  gitlab_branch_head '{"token":"x"}' main   -> 0851af33...

Usage: gitlab_branch_head "$options" "$branch"   # owner/repo optional
FUN
  @branch_head() {
    __gitlab_branch_head__token="$(__gitlab__validate_token "$1")" || return 1
    if [ -z "${2:-}" ]; then
      error "gitlab_branch_head: missing branch"
      return 1
    fi

    __gitlab_branch_head__encoded="$(__gitlab__url_encode "$2")"
    @set __gitlab_branch_head__options "$1" '.branch_encoded' "$__gitlab_branch_head__encoded"
    __gitlab_branch_head__endpoint="$(__gitlab__rest_url "$__gitlab_branch_head__options" "$__gitlab__BRANCH_ENDPOINT")" || return 1
    __gitlab_branch_head__http_opts="$(__gitlab__http_opts "$__gitlab_branch_head__token")"

    __gitlab_branch_head__branch="$(http__get "$__gitlab_branch_head__endpoint" "$__gitlab_branch_head__http_opts")" || return 1
    @get __at_out "$__gitlab_branch_head__branch" '.commit.id'
    println "$__at_out"
  }

  :<<'FUN'
The pipelines running right now on a ref at a commit, oldest first, each as
its id. Empty when none runs there.

  gitlab_running_runs '{"token":"x"}' refs/merge-requests/398/head 1f447d08...
  -> [{"id":"4248"},{"id":"4250"}]

Usage: gitlab_running_runs "$options" "$ref" "$sha"   # owner/repo optional
FUN
  @running_runs() {
    __gitlab_running_runs__token="$(__gitlab__validate_token "$1")" || return 1
    if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
      error "gitlab_running_runs: missing ref or sha"
      return 1
    fi

    __gitlab_running_runs__endpoint="$(__gitlab__rest_url "$1" "$__gitlab__PIPELINES_ENDPOINT")" || return 1
    @obj __gitlab_running_runs__filter \
      '.ref'      "$2" \
      '.sha'      "$3" \
      '.status'   running \
      '.order_by' id \
      '.sort'     asc \
      '.per_page' 100
    __gitlab_running_runs__query="$(http__query_string "$__gitlab_running_runs__filter")"
    __gitlab_running_runs__http_opts="$(__gitlab__http_opts "$__gitlab_running_runs__token")"

    __gitlab_running_runs__pipelines="$(http__get "${__gitlab_running_runs__endpoint}?${__gitlab_running_runs__query}" "$__gitlab_running_runs__http_opts")" || return 1
    @run_awk __at_out "$__gitlab__GRAPHQL_DIR/flatten_pipelines.awk" "$__gitlab_running_runs__pipelines" || return 1
    println "$__at_out"
  }

  :<<'FUN'
Cancels a pipeline by id, every job in it included. GitLab answers with the
pipeline as it now stands; nothing of it is printed.

Usage: gitlab_cancel_run "$options" "$pipeline_id"   # owner/repo optional
FUN
  @cancel_run() {
    __gitlab_cancel_run__token="$(__gitlab__validate_token "$1")" || return 1
    if [ -z "${2:-}" ]; then
      error "gitlab_cancel_run: missing pipeline_id"
      return 1
    fi

    @set __gitlab_cancel_run__options "$1" '.pipeline_id' "$2"
    __gitlab_cancel_run__endpoint="$(__gitlab__rest_url "$__gitlab_cancel_run__options" "$__gitlab__PIPELINE_CANCEL_ENDPOINT")" || return 1

    __gitlab_cancel_run__http_opts="$(__gitlab__http_opts "$__gitlab_cancel_run__token")"

    http__post "$__gitlab_cancel_run__endpoint" "" "$__gitlab_cancel_run__http_opts" > /dev/null
  }

  :<<'FUN'
The open merge requests targeting a branch, each as its iid, its head, its
target and the labels it carries.

Usage: gitlab_open_reviews "$options" main   # .token, owner/repo optional
FUN
  @open_reviews() {
    __gitlab__landing__open_reviews "$@"
  }

  :<<'FUN'
Whether one merge request's approval rules are met, and when it became ready,
as epoch seconds.

Usage: gitlab_review_approval "$options"   # .review_number, .token
FUN
  @review_approval() {
    __gitlab__landing__approval "$@"
  }

  :<<'FUN'
One merge request's landing run, as .id, .sha and .status, or null when it
has none: the newest pipeline created while it carried the landing mark.

Usage: gitlab_landing_run "$options"   # .review_number, .token
FUN
  @landing_run() {
    __gitlab__landing__run "$@"
  }

  :<<'FUN'
Creates the landing run on a marked merge request's head and prints it. The
mark must already be on the merge request, since GitLab snapshots the labels
as it creates the pipeline and the rules read them there.

Usage: gitlab_start_landing_run "$options"   # .review_number, .token
FUN
  @start_landing_run() {
    __gitlab__landing__start "$@"
  }

  :<<'FUN'
Merges a merge request at a commit, unsquashed, and prints the commit the
merge left on the target branch. The commit is the head that was tested, so
a push since it was read refuses the merge instead of landing an untested
tree.

Usage: gitlab_merge_review "$options" "$sha"   # .review_number, .token
FUN
  @merge_review() {
    __gitlab__landing__merge "$@"
  }
}
