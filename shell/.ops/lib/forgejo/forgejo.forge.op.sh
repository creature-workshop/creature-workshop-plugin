#!/usr/bin/env bash

:<<'DOC'
Forgejo API client for releases, pull requests, and label management.

Adaptor in the forge "sandwich" (see lib/forge/base.sh): implements the
forgejo_* contract that the lib/forge/api.sh facade dispatches to. Sources
the common base for the shared option constructors (forge_new_*_options).
DOC

import \
  "$SHELLOPS_DIR/lib/forge/base.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/http/api.sh" \
  "$SHELLOPS_DIR/lib/markdown/api.sh" \
  "$SHELLOPS_DIR/lib/string/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/forgejo/review_merge_command.sh" \
  "$SHELLOPS_DIR/lib/forgejo/endpoints.sh" \
  "$SHELLOPS_DIR/lib/forgejo/request.sh" \
  "$SHELLOPS_DIR/lib/forgejo/options.sh" \
  "$SHELLOPS_DIR/lib/forgejo/payloads.sh" \
  "$SHELLOPS_DIR/lib/forgejo/packages.sh" \
  "$SHELLOPS_DIR/lib/forgejo/run_status.sh" \
  "$SHELLOPS_DIR/lib/forgejo/_review_threads.sh"

:<<'DOC'
The forgejo forge: the roles it implements are its inner @-functions, re-homed to
forgejo_<role> when the forge facade loads the contract. The helpers live beside
this file, one per concern.
DOC
@forge.forgejo() {
  :<<'FUN'
Resolves the Forgejo API base URL from FORGEJO_API_BASE (same default as
internal requests use).

Usage: forgejo_api_base
FUN
  @api_base() {
    println "$__forgejo__BASE"
  }

  :<<'FUN'
The environment variable a token for Forgejo arrives in when Forgejo is asked
by name. The forge a run is on is asked through the stable name the facade
holds instead.

Usage: forgejo_token_env   # -> FORGEJO_TOKEN
FUN
  @token_env() {
    printf 'FORGEJO_TOKEN\n'
  }

  :<<'FUN'
Implements <forge>_run_status (lib/forge/base.sh). Whether Forgejo holds the
commit is one request and its runs on it are another, since the runs list
answers an unknown commit with an empty page rather than a refusal.

Usage: forgejo_run_status "$run_options"
FUN
  @run_status() {
    @get __at1 "$1" '.token' ''
    __forgejo_run_status__auth="$(forge__base__auth_header token "$__at1")"
    @obj __at2
    @patch __forgejo_run_status__http_opts "$__at2" '.auth' "$__forgejo_run_status__auth"

    __forgejo_run_status__commit_endpoint="$(__forgejo__render_endpoint "$__forgejo__GIT_COMMIT_ENDPOINT" "$1")"
    __forgejo_run_status__commit="$(forge__base__probe "$__forgejo_run_status__commit_endpoint" "$__forgejo_run_status__http_opts")" || return 1
    if ! @defined "$__forgejo_run_status__commit"; then
      forge__base__not_carried
      return 0
    fi

    __forgejo_run_status__runs_endpoint="$(__forgejo__render_endpoint "$__forgejo__ACTION_RUNS_ENDPOINT" "$1")"
    __forgejo_run_status__runs="$(http__get "$__forgejo_run_status__runs_endpoint" "$__forgejo_run_status__http_opts")" || return 1

    __forgejo__run_state "$__forgejo_run_status__runs"
  }

  :<<'FUN'
Implements <forge>_create_commit_status (lib/forge/base.sh). Forgejo calls a
failed run "failure" and names a status under "context". Its states are
pending, success, error, failure and warning, so a commit it ran nothing on
is recorded as "warning". The answer is the status Forgejo recorded.

Usage: forgejo_create_commit_status "$commit_status_options"

  Required: sha, state, token
  Optional: name, url, description
FUN
  @create_commit_status() {
    __forgejo_create_commit_status__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_create_commit_status__http_opts="$(__forgejo__http_opts "$__forgejo_create_commit_status__token")"

    if @get __at3 "$1" '.sha' ''; ! @defined "$__at3"; then
      error "Cannot record a commit status. Missing sha."
      return 1
    fi

    __forgejo_create_commit_status__endpoint="$(__forgejo__render_endpoint "$__forgejo__COMMIT_STATUSES_ENDPOINT" "$1")"
    @obj __forgejo_create_commit_status__words \
      ".$forge__OUTCOME_FAILURE" 'failure' \
      ".$forge__OUTCOME_NONE"    'warning'
    __forgejo_create_commit_status__body="$(forge__base__commit_status_body \
      "$1" \
      "$__forgejo_create_commit_status__words" \
      '.context'
    )" || return 1

    http__post \
      "$__forgejo_create_commit_status__endpoint" \
      "$__forgejo_create_commit_status__body" \
      "$__forgejo_create_commit_status__http_opts"
  }

  :<<'FUN'
Creates a release via the Forgejo API.

Usage: forgejo_create_release "\$release_options"
FUN
  @create_release() {
    __forgejo_create_release__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_create_release__http_opts="$(__forgejo__http_opts "$__forgejo_create_release__token")"

    __forgejo_create_release__endpoint="$(__forgejo__release_endpoint "$1")"
    if ! @defined "$__forgejo_create_release__endpoint"; then
      __at4="$(forge__base__options_without_token "$1")"
      error "Cannot create release endpoint for options: $__at4"
      return 1
    fi

    __forgejo_create_release__body="$(__forgejo__release_body "$1")"
    if ! @defined "$__forgejo_create_release__body"; then
      __at5="$(forge__base__options_without_token "$1")"
      error "Cannot create release body for options: $__at5"
      return 1
    fi

    http__post "$__forgejo_create_release__endpoint" "$__forgejo_create_release__body" "$__forgejo_create_release__http_opts"
  }

  :<<'FUN'
Uploads a file as a release asset on Forgejo.

Usage: forgejo_upload_artifact "\$upload_options"
FUN
  @upload_artifact() {
    @get __forgejo_upload_artifact__filepath "$1" '.filepath'
    @get __forgejo_upload_artifact__filename "$1" '.filename'
    if ! @defined "$__forgejo_upload_artifact__filepath" || ! @defined "$__forgejo_upload_artifact__filename"; then
      error "Incomplete file upload information. name: '$__forgejo_upload_artifact__filename', path: '$__forgejo_upload_artifact__filepath'"
      return 1
    fi

    __forgejo_upload_artifact__token="$(__forgejo__validate_token "$1")" || return 1

    __forgejo_upload_artifact__endpoint="$(__forgejo__upload_endpoint "$1")"
    if ! @defined "$__forgejo_upload_artifact__endpoint"; then
      __at6="$(forge__base__options_without_token "$1")"
      error "Cannot create upload endpoint for options: $__at6"
      return 1
    fi

    __forgejo_upload_artifact__http_opts="$(__forgejo__http_opts "$__forgejo_upload_artifact__token")"
    @set __forgejo_upload_artifact__http_opts "$__forgejo_upload_artifact__http_opts" '.form_field' 'attachment'

    http__upload "$__forgejo_upload_artifact__endpoint" "$__forgejo_upload_artifact__filepath" "$__forgejo_upload_artifact__http_opts"
  }

  :<<'FUN'
Fetches pull request metadata from the Forgejo API.

Usage: forgejo_get_review '{"review_number":1, "token":"xxx"}'

  owner and repo fall back to manifest.json if not provided.
FUN
  @get_review() {
    __forgejo_get_review__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_get_review__http_opts="$(__forgejo__http_opts "$__forgejo_get_review__token")"

    __forgejo_get_review__endpoint="$(__forgejo__pull_request_endpoint "$1")"
    if ! @defined "$__forgejo_get_review__endpoint"; then
      __at7="$(forge__base__options_without_token "$1")"
      error "Cannot create pull request endpoint for options: $__at7"
      return 1
    fi

    http__get "$__forgejo_get_review__endpoint" "$__forgejo_get_review__http_opts"
  }

  :<<'FUN'
Creates a pull request via the Forgejo API.

Usage: forgejo_create_review "$pull_request_options"

  pull_request_options must include .title, .head, .base, and .token.
FUN
  @create_review() {
    __forgejo_create_review__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_create_review__endpoint="$(__forgejo__pull_requests_endpoint "$1")" || return 1
    __forgejo_create_review__body="$(__forgejo__pull_request_body "$1")"
    __forgejo_create_review__http_opts="$(__forgejo__http_opts "$__forgejo_create_review__token")"

    http__post "$__forgejo_create_review__endpoint" "$__forgejo_create_review__body" "$__forgejo_create_review__http_opts"
  }

  :<<'FUN'
Updates a pull request's title, description, or both.

Usage: forgejo_update_review "$options"

  options must include .review_number and .token, plus at least one of .title and
  .body.

An empty field means "leave this alone", not "clear it", matching
forgejo_create_review's own body filter and keeping a description-only
update from blanking the title that forge__new_create_review_options pre-filled
with "".
FUN
  @update_review() {
    __forgejo_update_review__options="$(__forgejo__normalize_review_options "$1")"
    __forgejo_update_review__token="$(__forgejo__validate_token "$__forgejo_update_review__options")" || return 1

    __forgejo_update_review__endpoint="$(__forgejo__pull_request_endpoint \
      "$__forgejo_update_review__options")" || return 1

    __forgejo_update_review__body="$(
      __forgejo__pull_request_update_body "$__forgejo_update_review__options"
    )"
    if @keys __at8 "$__forgejo_update_review__body"; @len __at9 "$__at8"; [ "$__at9" -eq 0 ]; then
      error "forgejo_update_review: nothing to update (expected title or body)"
      return 1
    fi

    __forgejo_update_review__http_opts="$(__forgejo__http_opts "$__forgejo_update_review__token")"

    http__patch \
      "$__forgejo_update_review__endpoint" \
      "$__forgejo_update_review__body" \
      "$__forgejo_update_review__http_opts"
  }

  :<<'FUN'
Lists all comments on a Forgejo issue/PR, handling pagination.

PRs are issues in Forgejo's API, so review_number and issue_number are
interchangeable.

Usage: forgejo_list_comments "$comment_options"

  comment_options must include .issue_number and .token
FUN
  @list_comments() {
    __forgejo_list_comments__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_list_comments__endpoint="$(__forgejo__comments_endpoint "$1")" || return 1
    __forgejo_list_comments__http_opts="$(__forgejo__http_opts "$__forgejo_list_comments__token")"

    __forgejo__paginate "$__forgejo_list_comments__endpoint" "$__forgejo_list_comments__http_opts"
  }

  :<<'FUN'
Creates a comment on a Forgejo issue/PR.

Usage: forgejo_create_comment "$comment_options" "$body"

  comment_options must include .issue_number and .token
FUN
  @create_comment() {
    __forgejo_create_comment__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_create_comment__endpoint="$(__forgejo__comments_endpoint "$1")" || return 1
    __forgejo_create_comment__http_opts="$(__forgejo__http_opts "$__forgejo_create_comment__token")"
    @obj __forgejo_create_comment__payload '.body' "$2"

    http__post "$__forgejo_create_comment__endpoint" "$__forgejo_create_comment__payload" "$__forgejo_create_comment__http_opts"
  }

  @list_review_comments() {
    forgejo_list_comments "$(__forgejo__normalize_review_options "$1")"
  }

  :<<'FUN'
Lists the comments every review of a pull request left on lines of its diff,
oldest first, each shaped as Forgejo's PullReviewComment: .body, .path and
.position among its fields. The conversation on the pull request itself is
forgejo_list_review_comments.

Usage: forgejo_list_review_thread_comments "$options"

  options must include .review_number and .token
FUN
  @list_review_thread_comments() {
    __forgejo_list_review_thread_comments__options="$(__forgejo__normalize_review_options "$1")"
    __forgejo_list_review_thread_comments__token="$(__forgejo__validate_token "$__forgejo_list_review_thread_comments__options")" || return 1
    __forgejo_list_review_thread_comments__endpoint="$(__forgejo__pull_reviews_endpoint "$__forgejo_list_review_thread_comments__options")" || return 1
    __forgejo_list_review_thread_comments__http_opts="$(__forgejo__http_opts "$__forgejo_list_review_thread_comments__token")"

    __forgejo_list_review_thread_comments__reviews="$(
      __forgejo__paginate \
        "$__forgejo_list_review_thread_comments__endpoint" \
        "$__forgejo_list_review_thread_comments__http_opts"
    )" || return 1
    @arr __at10
    @reduce __forgejo_list_review_thread_comments__comments __forgejo__add_review_comments \
      "$__forgejo_list_review_thread_comments__reviews" \
      "$__at10" \
      "$__forgejo_list_review_thread_comments__options" \
      "$__forgejo_list_review_thread_comments__http_opts" \
      || return 1

    @sort_by __at_out "$__forgejo_list_review_thread_comments__comments" '.created_at'
    println "$__at_out"
  }

  @create_review_comment() {
    forgejo_create_comment "$(__forgejo__normalize_review_options "$1")" "$2"
  }

  :<<'FUN'
Replaces the body of an existing comment on a pull request.

Usage: forgejo_update_review_comment "$options" "$body"

  options must include .comment_id and .token. Forgejo addresses a comment by
  its own id, so no pull-request number is needed.
FUN
  @update_review_comment() {
    __forgejo_update_review_comment__options="$(__forgejo__normalize_review_options "$1")"
    __forgejo_update_review_comment__token="$(__forgejo__validate_token "$__forgejo_update_review_comment__options")" || return 1

    if @get __at11 "$__forgejo_update_review_comment__options" '.comment_id'; ! @defined "$__at11"; then
      error "forgejo_update_review_comment: missing comment_id"
      return 1
    fi

    __forgejo_update_review_comment__endpoint="$(__forgejo__render_endpoint \
      "$__forgejo__ISSUE_COMMENT_ENDPOINT" "$__forgejo_update_review_comment__options")"
    __forgejo_update_review_comment__http_opts="$(__forgejo__http_opts "$__forgejo_update_review_comment__token")"

    @obj __at12
    @set __at13 "$__at12" '.body' "$2"
    http__patch \
      "$__forgejo_update_review_comment__endpoint" \
      "$__at13" \
      "$__forgejo_update_review_comment__http_opts"
  }

  :<<'FUN'
Removes a comment from a pull request.

Usage: forgejo_delete_review_comment "$options"

  options must include .comment_id and .token. Forgejo addresses a comment by
  its own id, so no pull-request number is needed.
FUN
  @delete_review_comment() {
    __forgejo_delete_review_comment__options="$(__forgejo__normalize_review_options "$1")"
    __forgejo_delete_review_comment__token="$(__forgejo__validate_token "$__forgejo_delete_review_comment__options")" || return 1

    if @get __at14 "$__forgejo_delete_review_comment__options" '.comment_id'; ! @defined "$__at14"; then
      error "forgejo_delete_review_comment: missing comment_id"
      return 1
    fi

    __forgejo_delete_review_comment__endpoint="$(__forgejo__render_endpoint \
      "$__forgejo__ISSUE_COMMENT_ENDPOINT" "$__forgejo_delete_review_comment__options")"
    __forgejo_delete_review_comment__http_opts="$(__forgejo__http_opts "$__forgejo_delete_review_comment__token")"

    http__delete \
      "$__forgejo_delete_review_comment__endpoint" \
      "$__forgejo_delete_review_comment__http_opts"
  }

  :<<'FUN'
Lists all repository labels, handling pagination automatically.

Usage: forgejo_list_labels "$label_options"
FUN
  @list_labels() {
    __forgejo_list_labels__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_list_labels__endpoint="$(__forgejo__labels_endpoint "$1")" || return 1
    __forgejo_list_labels__http_opts="$(__forgejo__http_opts "$__forgejo_list_labels__token")"

    __forgejo_list_labels__page=1
    __forgejo_list_labels__limit=50
    @arr __forgejo_list_labels__all_labels

    while true; do
      __forgejo_list_labels__query="page=${__forgejo_list_labels__page}&limit=${__forgejo_list_labels__limit}"
      __forgejo_list_labels__result="$(http__get "${__forgejo_list_labels__endpoint}?${__forgejo_list_labels__query}" "$__forgejo_list_labels__http_opts")" || return 1

      @len __forgejo_list_labels__count "$__forgejo_list_labels__result"
      @concat __forgejo_list_labels__all_labels "$__forgejo_list_labels__all_labels" "$__forgejo_list_labels__result"

      if [ "$__forgejo_list_labels__count" -lt "$__forgejo_list_labels__limit" ]; then
        break
      fi
      __forgejo_list_labels__page=$((__forgejo_list_labels__page + 1))
    done

    echo "$__forgejo_list_labels__all_labels"
  }

  :<<'FUN'
Creates a label on the repository.

Usage: forgejo_create_label "$label_options" "$label_data"

  label_data is a JSON object with: name, color, description
FUN
  @create_label() {
    __forgejo_create_label__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_create_label__endpoint="$(__forgejo__labels_endpoint "$1")" || return 1
    __forgejo_create_label__http_opts="$(__forgejo__http_opts "$__forgejo_create_label__token")"
    @pick __forgejo_create_label__fields "$2" name color description
    @dump __forgejo_create_label__body "$__forgejo_create_label__fields"

    http__post "$__forgejo_create_label__endpoint" "$__forgejo_create_label__body" "$__forgejo_create_label__http_opts"
  }

  :<<'FUN'
Updates a label on the repository.

Usage: forgejo_edit_label "$label_options" "$edit_data"

  label_options must include .label_id
  edit_data is a JSON object with any of: name, color, description, is_archived
FUN
  @edit_label() {
    __forgejo_edit_label__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_edit_label__endpoint="$(__forgejo__label_endpoint "$1")" || return 1
    __forgejo_edit_label__http_opts="$(__forgejo__http_opts "$__forgejo_edit_label__token")"

    http__patch "$__forgejo_edit_label__endpoint" "$2" "$__forgejo_edit_label__http_opts"
  }

  :<<'FUN'
Lists all non-archived repositories in the organization, handling pagination.

Usage: forgejo_list_org_repos "$org_options"
FUN
  @list_org_repos() {
    __forgejo_list_org_repos__page=1
    __forgejo_list_org_repos__limit=50
    @arr __forgejo_list_org_repos__all_repos

    __forgejo_list_org_repos__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_list_org_repos__endpoint="$(__forgejo__org_repos_endpoint "$1")" || return 1
    __forgejo_list_org_repos__http_opts="$(__forgejo__http_opts "$__forgejo_list_org_repos__token")"

    while true; do
      __forgejo_list_org_repos__result="$(
        http__get "${__forgejo_list_org_repos__endpoint}?page=${__forgejo_list_org_repos__page}&limit=${__forgejo_list_org_repos__limit}" "$__forgejo_list_org_repos__http_opts"
      )" || return 1

      @filter __forgejo_list_org_repos__filtered "$__forgejo_list_org_repos__result" silt__text_is .archived false
      @concat __forgejo_list_org_repos__all_repos "$__forgejo_list_org_repos__all_repos" "$__forgejo_list_org_repos__filtered"
      @len __forgejo_list_org_repos__count "$__forgejo_list_org_repos__result"

      if [ "$__forgejo_list_org_repos__count" -lt "$__forgejo_list_org_repos__limit" ]; then
        break
      fi
      __forgejo_list_org_repos__page=$((__forgejo_list_org_repos__page + 1))
    done

    echo "$__forgejo_list_org_repos__all_repos"
  }

  :<<'FUN'
The username the options' token authenticates as, on the instance the options'
.host names.

Usage: forgejo_current_user "$options"   # -> blizz
FUN
  @current_user() {
    __forgejo_current_user__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_current_user__endpoint="$(__forgejo__render_endpoint "$__forgejo__USER_ENDPOINT" "$1")"
    __forgejo_current_user__http_opts="$(__forgejo__http_opts "$__forgejo_current_user__token")"

    __forgejo_current_user__user="$(http__get "$__forgejo_current_user__endpoint" "$__forgejo_current_user__http_opts")" || return 1
    @get __at_out "$__forgejo_current_user__user" '.login'
    println "$__at_out"
  }

  :<<'FUN'
Fetches a raw file from a repository. Returns the file content or fails
if the file does not exist.

Usage: forgejo_get_raw_file "$options" "$filepath"

  options must include .owner and .repo
FUN
  @get_raw_file() {
    __forgejo_get_raw_file__token="$(__forgejo__validate_token "$1")" || return 1
    __forgejo_get_raw_file__endpoint="$(__forgejo__raw_file_endpoint "$1" "$2")" || return 1
    __forgejo_get_raw_file__http_opts="$(__forgejo__http_opts "$__forgejo_get_raw_file__token")"

    http__get "$__forgejo_get_raw_file__endpoint" "$__forgejo_get_raw_file__http_opts"
  }

  @merged_reviews_since() {
    error "forge__merged_reviews_since is not implemented for Forgejo"
    return 1
  }

  : <<'FUN'
The Forgejo repository's default branch, resolved from git (Forgejo CI exposes no
dedicated default-branch variable).

Usage: forgejo_default_branch   # -> main
FUN
  @default_branch() {
    git__default_branch
  }

  :<<'FUN'
Prints the pull-request numbers referenced in the given commit-message text,
one per line. Recognizes the "(#123)" suffix Forgejo appends to squash and
merge commit subjects.

Usage: forgejo_code_review_refs "$commit_text"
FUN
  @code_review_refs() {
    println "$1" \
      | grep -oE '\(#[0-9]+\)' \
      | tr -d '(#)' \
      || true
  }

  : <<'FUN'
The number of the pull request this run is building, or nothing when it is
building a branch.

Forgejo Actions mirrors GitHub, which carries the number in the event payload at
$GITHUB_EVENT_PATH rather than in a variable of its own: a pull_request event
names it under .pull_request, and a payload whose subject is the review itself
names it at the top level.

Usage: review="$(forgejo_current_review)"   # -> 42, or ""
FUN
  @current_review() {
    @defined "${GITHUB_EVENT_PATH:-}" || return 0
    [ -f "$GITHUB_EVENT_PATH" ] || return 0

    __forgejo_current_review__event="$(cat "$GITHUB_EVENT_PATH")"
    @get __at_out "$__forgejo_current_review__event" '.pull_request.number' '.number' ''
    println "$__at_out"
  }

  @review_labels() {
    error "forge__review_labels is not implemented for Forgejo"
    return 1
  }

  : <<'FUN'
Label changes on a pull request are not implemented for Forgejo, whose update
takes label ids rather than names.
FUN
  @reconcile_review_labels() {
    error "forge__reconcile_review_labels is not implemented for Forgejo"
    return 1
  }

  :<<'FUN'
Prints true when the comment is a reply to another, false otherwise.

Forgejo's comments are a flat list with no parent link, so a reply leaves no
structural trace and this has to read the convention instead: quoting what you
are answering. That makes the answer a good guess rather than a fact, and it is
wrong in the one direction you would expect -- someone quoting for emphasis
looks like they are replying.

Erring that way is the safe side. A caller uses this to decide how much of a
comment its author actually wrote, and mistaking emphasis for a reply drops a
quotation the author did not write either way.

Usage: forgejo_comment_is_reply "$comment"
FUN
  @comment_is_reply() {
    @get __at15 "$1" '.body' ''
    println "$__at15" | markdown__has_leading_quote
  }

  : <<'FUN'
The commit range this run was triggered for, or nothing when there is no
baseline to compare against.

Forgejo Actions mirrors GitHub's variables, which is where these names come
from. GITHUB_EVENT_BEFORE is the weak half: GitHub itself carries the pushed-from
commit in the event payload at $GITHUB_EVENT_PATH rather than a variable of that
name. Reviving the Forgejo path means confirming which of the two its runner
actually sets.

Usage: range="$(forgejo_pushed_range)"   # -> abc123..def456, or ""
FUN
  @pushed_range() {
    forge__base__range "${GITHUB_EVENT_BEFORE:-}" "${GITHUB_SHA:-HEAD}"
  }

  @request_review() {
    error "forgejo_request_review: not implemented on the Forgejo backend."
    return 1
  }

  : <<'FUN'
Review hand-back is unimplemented here: Forgejo's review-state semantics are
unverified against a live host, so these fail rather than guess.
FUN
  @reviews_awaiting_author() {
    error "forgejo_reviews_awaiting_author: not implemented on the Forgejo backend."
    return 1
  }

  :<<'FUN'
A username as a Forgejo mention: the markup that makes Forgejo notify that
user. Plain markup, not review-state API, so it is not stubbed with the two
above.

Usage: forgejo_mention "jerrod"   # -> @jerrod
FUN
  @mention() {
    printf '@%s\n' "$1"
  }

  :<<'FUN'
Prints the reference a pull request is written as in prose and commit
messages: its number behind a hash.

Usage: forgejo_review_ref 12  # -> #12
FUN
  @review_ref() {
    printf '#%s\n' "$1"
  }

  :<<'FUN'
Parses the owner, repository, and pull request number from a pull request
URL on this Forgejo, in the form {owner, repo, review_number}. Prints
nothing when the page is unrecognized.

  forgejo_review_from_url https://forge.example.com/org/tool/pulls/7#issuecomment-1
    -> {"owner": "org", "repo": "tool", "review_number": 7}

Usage: forgejo_review_from_url "$url"
FUN
  @review_from_url() {
    forge__base__review_from_url "$1" "$__forgejo__BASE" "$__forgejo__PULL_PAGE"
  }

  :<<'FUN'
Given an object {owner, repo, review_number}, prints the URL of the pull
request on this Forgejo.

  forgejo_review_url '{"owner": "org", "repo": "tool", "review_number": 7}'
    -> https://forge.example.com/org/tool/pulls/7

Usage: forgejo_review_url "$options"
FUN
  @review_url() {
    forge__base__review_url "$1" "$__forgejo__BASE" "$__forgejo__PULL_PAGE"
  }

  :<<'FUN'
Prints the repository this adaptor is working in, as {owner, repo}: the one
Forgejo Actions names in GITHUB_REPOSITORY, the variable it mirrors from
GitHub, or the manifest's org and repo when that variable is unset.

Usage: forgejo_repository
FUN
  @repository() {
    __forgejo_repository__path="${GITHUB_REPOSITORY:-}"
    if ! @defined "$__forgejo_repository__path"; then
      __forgejo_repository__path="$(forge__base__manifest_repository)" || return 1
    fi

    forge__base__repository_of "$__forgejo_repository__path"
  }

  :<<'FUN'
The commit range the pull-request run builds, as <base>..<head>, and nothing
outside a pull-request run. Forgejo Actions mirrors GitHub: a pull_request
event carries
both ends in the payload at $GITHUB_EVENT_PATH, under .pull_request.base.sha
and .pull_request.head.sha.

Usage: range="$(forgejo_review_commit_range)"   # -> abc123..def456, or ""
FUN
  @review_commit_range() {
    @defined "${GITHUB_EVENT_PATH:-}" || return 0
    [ -f "$GITHUB_EVENT_PATH" ] || return 0

    __forgejo_review_commit_range__event="$(cat "$GITHUB_EVENT_PATH")"
    @get __at16 "$__forgejo_review_commit_range__event" '.pull_request.base.sha' ''
    @get __at17 "$__forgejo_review_commit_range__event" '.pull_request.head.sha' ''
    forge__base__range \
      "$__at16" \
      "$__at17"
  }

  :<<'FUN'
Prints the push options that would ask Forgejo to run nothing for a push:
none, since Forgejo offers no such option, so a push there runs whatever
the ref's workflows say.

Usage: forgejo_no_run_push_options   # -> []
FUN
  @no_run_push_options() {
    @arr __at_out
    println "$__at_out"
  }

  :<<'FUN'
The open pull request from a branch, a pull request by number, each with its
latest run's jobs, and a job's artifacts archive: the escape check reads them on the forge a run is on, and
Forgejo does not read them yet.
FUN
  @review_pipeline() {
    error "forgejo_review_pipeline: not implemented on the Forgejo backend."
    return 1
  }

  @review_for_branch() {
    error "forgejo_review_for_branch: not implemented on the Forgejo backend."
    return 1
  }

  @download_job_artifacts() {
    error "forgejo_download_job_artifacts: not implemented on the Forgejo backend."
    return 1
  }

  :<<'FUN'
The run a job belongs to, a branch's head, the runs on a ref at a commit, and
cancelling one: the stale guard reads them on the forge a run is on, and
Forgejo does not answer them yet.
FUN
  @current_run() {
    error "forgejo_current_run: not implemented on the Forgejo backend."
    return 1
  }

  @branch_head() {
    error "forgejo_branch_head: not implemented on the Forgejo backend."
    return 1
  }

  @running_runs() {
    error "forgejo_running_runs: not implemented on the Forgejo backend."
    return 1
  }

  @cancel_run() {
    error "forgejo_cancel_run: not implemented on the Forgejo backend."
    return 1
  }

  :<<'FUN'
The open merge requests targeting a branch, one's approval as the rules
state it, one merge request's landing run, the run started on a marked head,
and the merge that lands it: landing roles of the forge contract, which
Forgejo does not answer yet.
FUN
  @open_reviews() {
    error "forgejo_open_reviews: not implemented on the Forgejo backend."
    return 1
  }

  @review_approval() {
    error "forgejo_review_approval: not implemented on the Forgejo backend."
    return 1
  }

  @landing_run() {
    error "forgejo_landing_run: not implemented on the Forgejo backend."
    return 1
  }

  @start_landing_run() {
    error "forgejo_start_landing_run: not implemented on the Forgejo backend."
    return 1
  }

  @merge_review() {
    error "forgejo_merge_review: not implemented on the Forgejo backend."
    return 1
  }

  :<<'FUN'
The landing at a commit: check C reads it on the forge the trunk is on, and
Forgejo does not answer it yet.
FUN
  @landing_at() {
    error "forgejo_landing_at: not implemented on the Forgejo backend."
    return 1
  }
}
