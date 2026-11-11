#!/usr/bin/env bash

:<<'DOC'
The GitHub adaptor: a @forge.github structural contract over api.github.com,
the whole forge contract. GitHub is asked by name, never selected as the forge
a run is on. The workflow, run and tag functions beside the contract are its
own surface, outside the forge one.
DOC

import \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/http/api.sh" \
  "$SHELLOPS_DIR/lib/string/api.sh" \
  "$SHELLOPS_DIR/lib/github/review_merge_command.sh" \
  "$SHELLOPS_DIR/lib/forge/base.sh" \
  "$SHELLOPS_DIR/lib/github/endpoints.sh" \
  "$SHELLOPS_DIR/lib/github/request.sh" \
  "$SHELLOPS_DIR/lib/github/options.sh" \
  "$SHELLOPS_DIR/lib/github/actions.sh" \
  "$SHELLOPS_DIR/lib/github/tags.sh" \
  "$SHELLOPS_DIR/lib/github/releases.sh" \
  "$SHELLOPS_DIR/lib/github/payloads.sh" \
  "$SHELLOPS_DIR/lib/github/run_status.sh" \
  "$SHELLOPS_DIR/lib/markdown/api.sh"

:<<'DOC'
The github forge: the roles it implements are its inner @-functions, re-homed to
github_<role> when the forge facade loads the contract. The helpers live beside
this file, one per concern.
DOC
@forge.github() {
  :<<'FUN'
The GitHub API base URL, the mark that this adaptor is in the process.

Usage: github_api_base
FUN
  @api_base() {
    println "$__github__BASE"
  }

  :<<'FUN'
The environment variable a token for GitHub arrives in. Every GitHub Actions
run already sets GITHUB_TOKEN, so a workflow that wires a bot's token over it
gives the adaptor its token without naming a second variable.

Usage: github_token_env   # -> GITHUB_TOKEN
FUN
  @token_env() {
    printf 'GITHUB_TOKEN\n'
  }

  :<<'FUN'
Implements <forge>_run_status (lib/forge/base.sh) for GitHub, which is not
selectable as the active forge but is asked by name. Whether GitHub holds the
commit is one request and its Actions runs on it are another, since the runs
list answers an unknown commit with an empty page rather than a refusal.

Usage: github_run_status "$run_options"
FUN
  @run_status() {
    @get __at1 "$1" '.token' ''
    __github_run_status__http_opts="$(__github__open_http_opts "$__at1")"

    __github_run_status__commit_endpoint="$(__github__render_endpoint "$__github__COMMIT_ENDPOINT" "$1")"
    __github_run_status__commit="$(forge__base__probe "$__github_run_status__commit_endpoint" "$__github_run_status__http_opts")" || return 1
    if ! @defined "$__github_run_status__commit"; then
      forge__base__not_carried
      return 0
    fi

    __github_run_status__runs_endpoint="$(__github__render_endpoint "$__github__ACTION_RUNS_ENDPOINT" "$1")"
    __github_run_status__runs="$(http__get "$__github_run_status__runs_endpoint" "$__github_run_status__http_opts")" || return 1

    __github__run_state "$__github_run_status__runs"
  }

  :<<'FUN'
Implements <forge>_create_commit_status (lib/forge/base.sh). GitHub calls a
failed run "failure" and names a status under "context". Its states are
error, failure, pending and success, so a commit it ran nothing on is
recorded as "error", the state for a run it could not evaluate. The answer
is the status GitHub recorded.

Usage: github_create_commit_status "$commit_status_options"

  Required: sha, state, token
  Optional: name, url, description
FUN
  @create_commit_status() {
    __github_create_commit_status__token="$(__github__validate_token "$1")" || return 1
    __github_create_commit_status__http_opts="$(__github__http_opts "$__github_create_commit_status__token")"

    if @get __at2 "$1" '.sha' ''; ! @defined "$__at2"; then
      error "Cannot record a commit status. Missing sha."
      return 1
    fi

    __github_create_commit_status__endpoint="$(__github__render_endpoint "$__github__COMMIT_STATUSES_ENDPOINT" "$1")"
    @obj __github_create_commit_status__words \
      ".$forge__OUTCOME_FAILURE" 'failure' \
      ".$forge__OUTCOME_NONE"    'error'
    __github_create_commit_status__body="$(forge__base__commit_status_body \
      "$1" \
      "$__github_create_commit_status__words" \
      '.context'
    )" || return 1

    http__post \
      "$__github_create_commit_status__endpoint" \
      "$__github_create_commit_status__body" \
      "$__github_create_commit_status__http_opts"
  }

  :<<'FUN'
Fetches a pull request as GitHub describes it.

Usage: github_get_review '{"review_number":7, "token":"xxx"}'
FUN
  @get_review() {
    __github_get_review__options="$(__github__normalize_review_options "$1")"
    __github_get_review__token="$(__github__validate_token "$__github_get_review__options")" || return 1
    __github_get_review__endpoint="$(__github__endpoint "$__github_get_review__options" "$__github__PULL_ENDPOINT" review_number)" || return 1

    http__get "$__github_get_review__endpoint" "$(__github__http_opts "$__github_get_review__token")"
  }

  :<<'FUN'
Opens a pull request, then sets the assignees and labels the options carry on
it, since GitHub takes those on the issue and not on the pull request.

Usage: github_create_review "$review_options"
  review_options must include .title, .head, .base and .token.
FUN
  @create_review() {
    __github_create_review__options="$(__github__normalize_review_options "$1")"
    __github_create_review__token="$(__github__validate_token "$__github_create_review__options")" || return 1
    __github_create_review__http_opts="$(__github__http_opts "$__github_create_review__token")"
    __github_create_review__endpoint="$(__github__render_endpoint "$__github__PULLS_ENDPOINT" "$__github_create_review__options")"

    __github_create_review__pull="$(http__post \
      "$__github_create_review__endpoint" \
      "$(__github__pull_request_body "$__github_create_review__options")" \
      "$__github_create_review__http_opts"
    )" || return 1

    __github_create_review__issue_body="$(__github__issue_update_body "$__github_create_review__options")"
    if @keys __at3 "$__github_create_review__issue_body"; @len __at4 "$__at3"; [ "$__at4" -gt 0 ]; then
      @get __at5 "$__github_create_review__pull" '.number'
      @set __github_create_review__issue "$__github_create_review__options" '.issue_number' "$__at5"
      http__patch \
        "$(__github__render_endpoint "$__github__ISSUE_ENDPOINT" "$__github_create_review__issue")" \
        "$__github_create_review__issue_body" \
        "$__github_create_review__http_opts" > /dev/null || return 1
    fi

    println "$__github_create_review__pull"
  }

  :<<'FUN'
Updates a pull request's title, body, or both; an empty field is left alone.

Usage: github_update_review "$options"
  options must include .review_number and .token, plus .title or .body.
FUN
  @update_review() {
    __github_update_review__options="$(__github__normalize_review_options "$1")"
    __github_update_review__token="$(__github__validate_token "$__github_update_review__options")" || return 1
    __github_update_review__endpoint="$(__github__endpoint "$__github_update_review__options" "$__github__PULL_ENDPOINT" review_number)" || return 1
    __github_update_review__body="$(__github__pull_request_update_body "$__github_update_review__options")"
    if @keys __at6 "$__github_update_review__body"; @len __at7 "$__at6"; [ "$__at7" -eq 0 ]; then
      error "github_update_review: nothing to update (expected title or body)"
      return 1
    fi

    http__patch \
      "$__github_update_review__endpoint" \
      "$__github_update_review__body" \
      "$(__github__http_opts "$__github_update_review__token")"
  }

  :<<'FUN'
Lists every comment on an issue or pull request, oldest first, across pages.

Usage: github_list_comments "$comment_options"
  comment_options must include .issue_number and .token.
FUN
  @list_comments() {
    __github_list_comments__options="$(__github__normalize_review_options "$1")"
    __github_list_comments__token="$(__github__validate_token "$__github_list_comments__options")" || return 1
    __github_list_comments__endpoint="$(__github__endpoint "$__github_list_comments__options" "$__github__ISSUE_COMMENTS_ENDPOINT" issue_number)" || return 1

    __github__paginate "$__github_list_comments__endpoint" "$(__github__http_opts "$__github_list_comments__token")"
  }

  :<<'FUN'
Comments on an issue or pull request.

Usage: github_create_comment "$comment_options" "$body"
  comment_options must include .issue_number and .token.
FUN
  @create_comment() {
    __github_create_comment__options="$(__github__normalize_review_options "$1")"
    __github_create_comment__token="$(__github__validate_token "$__github_create_comment__options")" || return 1
    __github_create_comment__endpoint="$(__github__endpoint "$__github_create_comment__options" "$__github__ISSUE_COMMENTS_ENDPOINT" issue_number)" || return 1

    @obj __at8 '.body' "$2"
    http__post \
      "$__github_create_comment__endpoint" \
      "$__at8" \
      "$(__github__http_opts "$__github_create_comment__token")"
  }

  @list_review_comments() {
    github_list_comments "$1"
  }

  :<<'FUN'
Lists the comments left on lines of a pull request's diff, oldest first,
across pages. GitHub keeps these apart from the conversation, under the pull
request rather than the issue, so github_list_review_comments never sees them.

Usage: github_list_review_thread_comments "$options"
  options must include .review_number and .token.
FUN
  @list_review_thread_comments() {
    __github_list_review_thread_comments__options="$(__github__normalize_review_options "$1")"
    __github_list_review_thread_comments__token="$(__github__validate_token "$__github_list_review_thread_comments__options")" || return 1
    __github_list_review_thread_comments__endpoint="$(__github__endpoint "$__github_list_review_thread_comments__options" "$__github__PULL_COMMENTS_ENDPOINT" review_number)" || return 1

    __github__paginate \
      "$__github_list_review_thread_comments__endpoint" \
      "$(__github__http_opts "$__github_list_review_thread_comments__token")" \
      "sort=created&direction=asc"
  }

  @create_review_comment() {
    github_create_comment "$1" "$2"
  }

  :<<'FUN'
Replaces the body of a comment, addressed by its own id.

Usage: github_update_review_comment "$options" "$body"
  options must include .comment_id and .token.
FUN
  @update_review_comment() {
    __github_update_review_comment__options="$(__github__normalize_review_options "$1")"
    __github_update_review_comment__token="$(__github__validate_token "$__github_update_review_comment__options")" || return 1
    __github_update_review_comment__endpoint="$(__github__endpoint "$__github_update_review_comment__options" "$__github__ISSUE_COMMENT_ENDPOINT" comment_id)" || return 1

    @obj __at9 '.body' "$2"
    http__patch \
      "$__github_update_review_comment__endpoint" \
      "$__at9" \
      "$(__github__http_opts "$__github_update_review_comment__token")"
  }

  :<<'FUN'
Removes a comment, addressed by its own id.

Usage: github_delete_review_comment "$options"
  options must include .comment_id and .token.
FUN
  @delete_review_comment() {
    __github_delete_review_comment__options="$(__github__normalize_review_options "$1")"
    __github_delete_review_comment__token="$(__github__validate_token "$__github_delete_review_comment__options")" || return 1
    __github_delete_review_comment__endpoint="$(__github__endpoint "$__github_delete_review_comment__options" "$__github__ISSUE_COMMENT_ENDPOINT" comment_id)" || return 1

    http__delete "$__github_delete_review_comment__endpoint" "$(__github__http_opts "$__github_delete_review_comment__token")"
  }

  :<<'FUN'
Lists every label on the repository, across pages.

Usage: github_list_labels "$label_options"
FUN
  @list_labels() {
    __github_list_labels__token="$(__github__validate_token "$1")" || return 1
    __github_list_labels__endpoint="$(__github__endpoint "$1" "$__github__LABELS_ENDPOINT" "owner repo")" || return 1

    __github__paginate "$__github_list_labels__endpoint" "$(__github__http_opts "$__github_list_labels__token")"
  }

  :<<'FUN'
Creates a label on the repository.

Usage: github_create_label "$label_options" "$label_data"
  label_data is a JSON object with name, color and description.
FUN
  @create_label() {
    __github_create_label__token="$(__github__validate_token "$1")" || return 1
    __github_create_label__endpoint="$(__github__endpoint "$1" "$__github__LABELS_ENDPOINT" "owner repo")" || return 1

    http__post \
      "$__github_create_label__endpoint" \
      "$(__github__label_body "$2")" \
      "$(__github__http_opts "$__github_create_label__token")"
  }

  :<<'FUN'
Updates the label .label_id names, or deletes it when the edit says
is_archived: GitHub has no archived label, and a label the set no longer
carries is gone from the repository. GitHub addresses a label by its name, so
the id is resolved through the repository's labels first.

Usage: github_edit_label "$label_options" "$edit_data"
  label_options must include .label_id
  edit_data is a JSON object with any of name, color, description, is_archived
FUN
  @edit_label() {
    __github_edit_label__token="$(__github__validate_token "$1")" || return 1
    __github_edit_label__name="$(__github__label_name_of "$1")" || return 1
    @set __github_edit_label__options "$1" '.label_name' "$__github_edit_label__name"
    __github_edit_label__endpoint="$(__github__render_endpoint "$__github__LABEL_ENDPOINT" "$__github_edit_label__options")"
    __github_edit_label__http_opts="$(__github__http_opts "$__github_edit_label__token")"

    if @false __at10; @get __at11 "$2" '.is_archived' "$__at10"; @is_true "$__at11"; then
      http__delete "$__github_edit_label__endpoint" "$__github_edit_label__http_opts"
      return
    fi

    http__patch \
      "$__github_edit_label__endpoint" \
      "$(__github__label_body "$2" new_name)" \
      "$__github_edit_label__http_opts"
  }

  :<<'FUN'
Lists the organization's repositories that are not archived, across pages.

Usage: github_list_org_repos "$org_options"
FUN
  @list_org_repos() {
    __github_list_org_repos__token="$(__github__validate_token "$1")" || return 1
    __github_list_org_repos__endpoint="$(__github__endpoint "$1" "$__github__ORG_REPOS_ENDPOINT" org)" || return 1

    __github_list_org_repos__all="$(__github__paginate "$__github_list_org_repos__endpoint" "$(__github__http_opts "$__github_list_org_repos__token")")" || return 1
    @filter __at_out "$__github_list_org_repos__all" silt__text_is .archived false
    println "$__at_out"
  }

  :<<'FUN'
The username the options' token authenticates as.

Usage: github_current_user "$options"   # -> blizz
FUN
  @current_user() {
    __github_current_user__token="$(__github__validate_token "$1")" || return 1
    __github_current_user__endpoint="$(__github__endpoint "$1" "$__github__USER_ENDPOINT" "")" || return 1

    __github_current_user__user="$(http__get "$__github_current_user__endpoint" "$(__github__http_opts "$__github_current_user__token")")" || return 1
    @get __at_out "$__github_current_user__user" '.login'
    println "$__at_out"
  }

  :<<'FUN'
Prints a file's bytes from the repository's default branch, or from .ref when
the options name one. Fails when the file does not exist.

Usage: github_get_raw_file "$options" "$filepath"
FUN
  @get_raw_file() {
    __github_get_raw_file__token="$(__github__validate_token "$1")" || return 1
    @set __github_get_raw_file__options "$1" '.filepath' "$2"
    __github_get_raw_file__endpoint="$(__github__endpoint "$__github_get_raw_file__options" "$__github__CONTENTS_ENDPOINT" "owner repo filepath")" || return 1
    @get __github_get_raw_file__ref "$1" '.ref' ''
    if @defined "$__github_get_raw_file__ref"; then
      __github_get_raw_file__endpoint="${__github_get_raw_file__endpoint}?ref=$(http__encode "$__github_get_raw_file__ref")"
    fi

    http__get "$__github_get_raw_file__endpoint" "$(__github__raw_http_opts "$__github_get_raw_file__token")"
  }

  :<<'FUN'
The pull requests merged into $2 at or after the ISO timestamp $1, newest
first, each {iid, merged_at, labels: [name...]}; an empty $1 means from
genesis. Reads the closed pull requests newest-updated first and stops at the
first page whose oldest update predates $1, since a merge updates the pull
request.

Usage: github_merged_reviews_since "2026-09-01T00:00:00Z" main
FUN
  @merged_reviews_since() {
    __github_merged_reviews_since__token="$(forge__resolve_token)"
    @obj __github_merged_reviews_since__options '.owner' "$(manifest__get org)" '.repo' "$(manifest__get repo)"
    __github_merged_reviews_since__endpoint="$(__github__render_endpoint "$__github__PULLS_ENDPOINT" "$__github_merged_reviews_since__options")"
    __github_merged_reviews_since__http_opts="$(__github__http_opts "$__github_merged_reviews_since__token")"
    __github_merged_reviews_since__page=1
    @arr __github_merged_reviews_since__all

    while :; do
      __github_merged_reviews_since__result="$(http__get \
        "${__github_merged_reviews_since__endpoint}?state=closed&base=$(http__encode "$2")&sort=updated&direction=desc&per_page=${__github__PAGE_LIMIT}&page=${__github_merged_reviews_since__page}" \
        "$__github_merged_reviews_since__http_opts"
      )" || return 1
      @concat __github_merged_reviews_since__all "$__github_merged_reviews_since__all" "$__github_merged_reviews_since__result"
      if @len __at12 "$__github_merged_reviews_since__result"; [ "$__at12" -lt "$__github__PAGE_LIMIT" ]; then
        break
      fi
      @last __github_merged_reviews_since__oldest "$__github_merged_reviews_since__result"
      if @get __at13 "$__github_merged_reviews_since__oldest" '.updated_at' ''; @defined "$1" && [ "$__at13" \< "$1" ]; then
        break
      fi
      __github_merged_reviews_since__page=$((__github_merged_reviews_since__page + 1))
    done

    @run_awk __at_out "$SHELLOPS_DIR/lib/github/merged_pulls.awk" "$__github_merged_reviews_since__all" --arg since "$1" || return 1
    println "$__at_out"
  }

  :<<'FUN'
The repository's default branch as GitHub reports it: the release line a
promotion lands on. A site of the promotion ladder asks GitHub by name, so the
answer is the host's own rather than the one its checkout happens to carry. A
public repository answers without a token.

Usage: github_default_branch '{"owner":"a","repo":"b","token":"t"}'
FUN
  @default_branch() {
    __github_default_branch__endpoint="$(__github__endpoint "$1" "$__github__REPO_ENDPOINT" "owner repo")" || return 1
    @get __at14 "$1" '.token' ''
    __github_default_branch__repository="$(http__get \
      "$__github_default_branch__endpoint" \
      "$(__github__open_http_opts "$__at14")"
    )" || return 1

    @get __at_out "$__github_default_branch__repository" '.default_branch' ''
    println "$__at_out"
  }

  :<<'FUN'
Prints the pull request numbers the commit-message text refers to, one per
line: the "(#123)" a squash merge appends to its subject, and the "pull
request #123" a merge commit opens with.

Usage: github_code_review_refs "$commit_text"
FUN
  @code_review_refs() {
    println "$1" \
      | grep -oE '\(#[0-9]+\)|pull request #[0-9]+' \
      | grep -oE '[0-9]+' \
      || true
  }

  :<<'FUN'
The number of the pull request this run is building, or nothing when it is
building a branch: GitHub Actions carries it in the event payload at
$GITHUB_EVENT_PATH, under .pull_request for a pull_request event and at the
top level when the payload's subject is the review itself.

Usage: review="$(github_current_review)"   # -> 42, or ""
FUN
  @current_review() {
    __github_current_review__event="$(__github__event)"
    @defined "$__github_current_review__event" || return 0
    @get __at_out "$__github_current_review__event" '.pull_request.number' '.number' ''
    println "$__at_out"
  }

  :<<'FUN'
The labels on the pull request this run is building, as a struct array of
names, read off the event payload; empty when the run is not a pull request's.

Usage: github_review_labels
FUN
  @review_labels() {
    __github_review_labels__event="$(__github__event)"
    if ! @defined "$__github_review_labels__event"; then
      @arr __at_out
      println "$__at_out"
      return 0
    fi
    @arr __github_review_labels__none
    @get __github_review_labels__labels "$__github_review_labels__event" '.pull_request.labels' "$__github_review_labels__none"
    @pluck __at_out "$__github_review_labels__labels" '.name'
    println "$__at_out"
  }

  :<<'FUN'
Adds the labels in $2 to a pull request and removes the ones in $3, both
struct arrays of names, through the issue GitHub keeps them on. Nothing to
change is a no-op.

Usage: github_reconcile_review_labels "$options" '["role/platform"]' '["role/ktlo"]'
FUN
  @reconcile_review_labels() {
    __github_reconcile_review_labels__options="$(__github__normalize_review_options "$1")"
    __github_reconcile_review_labels__token="$(__github__validate_token "$__github_reconcile_review_labels__options")" || return 1
    __github_reconcile_review_labels__endpoint="$(__github__endpoint "$__github_reconcile_review_labels__options" "$__github__ISSUE_LABELS_ENDPOINT" issue_number)" || return 1
    __github_reconcile_review_labels__http_opts="$(__github__http_opts "$__github_reconcile_review_labels__token")"

    if @len __at15 "$2"; [ "$__at15" -gt 0 ]; then
      @obj __at16 '.labels' "$2"
      http__post \
        "$__github_reconcile_review_labels__endpoint" \
        "$__at16" \
        "$__github_reconcile_review_labels__http_opts" > /dev/null || return 1
    fi
    @foreach __github__remove_review_label "$3" "$__github_reconcile_review_labels__options" "$__github_reconcile_review_labels__http_opts"
  }

  :<<'FUN'
Prints true when the comment is a reply to another, false otherwise. GitHub's
issue comments are a flat list with no parent link, so this reads the
convention instead: quoting what you are answering. Someone quoting for
emphasis looks like a reply, which is the safe side for a caller deciding how
much of a comment its author wrote.

Usage: github_comment_is_reply "$comment"
FUN
  @comment_is_reply() {
    @get __at17 "$1" '.body' ''
    println "$__at17" | markdown__has_leading_quote
  }

  :<<'FUN'
The commit range this run was triggered for, or nothing when there is no
baseline: the pushed-from commit lives in the event payload as .before, and
the pushed-to one in GITHUB_SHA.

Usage: range="$(github_pushed_range)"   # -> abc123..def456, or ""
FUN
  @pushed_range() {
    __github_pushed_range__event="$(__github__event)"
    @get __at18 "$__github_pushed_range__event" '.before' ''
    forge__base__range "$__at18" "${GITHUB_SHA:-HEAD}"
  }

  :<<'FUN'
Asks .reviewer to review pull request .review_number again, which takes them
out of github_reviews_awaiting_author.

Usage: github_request_review "$options"
FUN
  @request_review() {
    __github_request_review__options="$(__github__normalize_review_options "$1")"
    @get __github_request_review__reviewer "$__github_request_review__options" '.reviewer' ''
    if ! @defined "$__github_request_review__reviewer"; then
      error "Cannot request review. Missing reviewer username."
      return 1
    fi
    __github_request_review__token="$(__github__validate_token "$__github_request_review__options")" || return 1
    __github_request_review__endpoint="$(__github__endpoint "$__github_request_review__options" "$__github__PULL_REVIEWERS_ENDPOINT" review_number)" || return 1

    @arr __at19 "$__github_request_review__reviewer"
    @obj __at20 '.reviewers' "$__at19"
    http__post \
      "$__github_request_review__endpoint" \
      "$__at20" \
      "$(__github__http_opts "$__github_request_review__token")"
  }

  :<<'FUN'
The open pull requests waiting on their author, each {iid, url, branch,
draft, reviewers: [login...]} listing the reviewers whose latest review asked
for changes and who have not been asked again. An empty .branch selects every
open pull request; .max_time and .retries cap each request.

Usage: github_reviews_awaiting_author "$review_options"
FUN
  @reviews_awaiting_author() {
    __github_reviews_awaiting_author__token="$(__github__validate_token "$1")" || return 1
    __github_reviews_awaiting_author__options="$(__github__normalize_review_options "$1")"
    __github_reviews_awaiting_author__http_opts="$(forge__base__with_budget "$(__github__http_opts "$__github_reviews_awaiting_author__token")" "$1")"
    __github_reviews_awaiting_author__query="state=open"
    @get __github_reviews_awaiting_author__branch "$1" '.branch' ''
    if @defined "$__github_reviews_awaiting_author__branch"; then
      @get __at21 "$__github_reviews_awaiting_author__options" '.owner'
      __github_reviews_awaiting_author__query="state=open&head=$(http__encode "$__at21:$__github_reviews_awaiting_author__branch")"
    fi

    __github_reviews_awaiting_author__pulls="$(__github__paginate \
      "$(__github__render_endpoint "$__github__PULLS_ENDPOINT" "$__github_reviews_awaiting_author__options")" \
      "$__github_reviews_awaiting_author__http_opts" \
      "$__github_reviews_awaiting_author__query"
    )" || return 1

    @arr __github_reviews_awaiting_author__found
    __github_reviews_awaiting_author__i=0
    while @len __at22 "$__github_reviews_awaiting_author__pulls"; [ "$__github_reviews_awaiting_author__i" -lt "$__at22" ]; do
      @get __at23 "$__github_reviews_awaiting_author__pulls" ".[$__github_reviews_awaiting_author__i]"
      __github_reviews_awaiting_author__record="$(__github__awaiting_record \
        "$__at23" \
        "$__github_reviews_awaiting_author__options" \
        "$__github_reviews_awaiting_author__http_opts"
      )" || return 1
      if @defined "$__github_reviews_awaiting_author__record"; then
        @push __github_reviews_awaiting_author__found "$__github_reviews_awaiting_author__found" "$__github_reviews_awaiting_author__record"
      fi
      __github_reviews_awaiting_author__i=$((__github_reviews_awaiting_author__i + 1))
    done

    println "$__github_reviews_awaiting_author__found"
  }

  :<<'FUN'
A username as a GitHub mention, the markup that makes GitHub notify that user.

Usage: github_mention "jerrod"   # -> @jerrod
FUN
  @mention() {
    printf '@%s\n' "$1"
  }

  :<<'FUN'
Prints the reference a pull request is written as in prose and commit
messages: its number behind a hash.

Usage: github_review_ref 12  # -> #12
FUN
  @review_ref() {
    printf '#%s\n' "$1"
  }

  :<<'FUN'
Parses the owner, repository, and pull request number from a pull request
URL on github.com, in the form {owner, repo, review_number}. Prints nothing
when the page is unrecognized.

  github_review_from_url https://github.com/org/tool/pull/7#issuecomment-1
    -> {"owner": "org", "repo": "tool", "review_number": 7}

Usage: github_review_from_url "$url"
FUN
  @review_from_url() {
    forge__base__review_from_url "$1" "$__github__WEB" "$__github__PULL_PAGE"
  }

  :<<'FUN'
Given an object {owner, repo, review_number}, prints the URL of the pull
request on github.com.

  github_review_url '{"owner": "org", "repo": "tool", "review_number": 7}'
    -> https://github.com/org/tool/pull/7

Usage: github_review_url "$options"
FUN
  @review_url() {
    forge__base__review_url "$1" "$__github__WEB" "$__github__PULL_PAGE"
  }

  :<<'FUN'
Prints the repository this adaptor is working in, as {owner, repo}: the one
GitHub Actions names in GITHUB_REPOSITORY, or the manifest's org and repo
when that variable is unset.

Usage: github_repository
FUN
  @repository() {
    __github_repository__path="${GITHUB_REPOSITORY:-}"
    if ! @defined "$__github_repository__path"; then
      __github_repository__path="$(forge__base__manifest_repository)" || return 1
    fi

    forge__base__repository_of "$__github_repository__path"
  }

  :<<'FUN'
The commit range the pull-request run builds, as <base>..<head>, and nothing
outside a pull-request run: a pull_request event carries both ends in the
payload at
$GITHUB_EVENT_PATH, under .pull_request.base.sha and .pull_request.head.sha.

Usage: range="$(github_review_commit_range)"   # -> abc123..def456, or ""
FUN
  @review_commit_range() {
    __github_review_commit_range__event="$(__github__event)"
    @defined "$__github_review_commit_range__event" || return 0

    @get __at24 "$__github_review_commit_range__event" '.pull_request.base.sha' ''
    @get __at25 "$__github_review_commit_range__event" '.pull_request.head.sha' ''
    forge__base__range \
      "$__at24" \
      "$__at25"
  }

  :<<'FUN'
Prints the push options that would ask GitHub to run nothing for a push:
none, since GitHub offers no such option, so a push there runs whatever
the ref's workflows say.

Usage: github_no_run_push_options   # -> []
FUN
  @no_run_push_options() {
    @arr __at_out
    println "$__at_out"
  }

  :<<'FUN'
Creates a release via the GitHub API.

Usage: github_create_release "$release_options"
FUN
  @create_release() {
    __github_create_release__token="$(__github__validate_token "$1")" || return 1
    __github_create_release__http_opts="$(__github__http_opts "$__github_create_release__token")"
    __github_create_release__endpoint="$(__github__release_endpoint "$1")"
    __github_create_release__body="$(__github__release_body "$1")"

    http__post "$__github_create_release__endpoint" "$__github_create_release__body" "$__github_create_release__http_opts"
  }

  :<<'FUN'
Uploads a file as a release asset on GitHub.

Usage: github_upload_artifact "$upload_options"
FUN
  @upload_artifact() {
    @get __github_upload_artifact__filepath "$1" '.filepath'
    @get __github_upload_artifact__filename "$1" '.filename'
    __github_upload_artifact__token="$(__github__validate_token "$1")" || return 1

    if ! @defined "$__github_upload_artifact__filepath" || ! @defined "$__github_upload_artifact__filename"; then
      error "Incomplete file upload information. name: '$__github_upload_artifact__filename', path: '$__github_upload_artifact__filepath'"
      return 1
    fi

    __github_upload_artifact__endpoint="$(__github__upload_endpoint "$1")"
    __github_upload_artifact__http_opts="$(__github__http_opts "$__github_upload_artifact__token")"
    @set __github_upload_artifact__http_opts "$__github_upload_artifact__http_opts" '.upload_mode' 'binary'

    http__upload "$__github_upload_artifact__endpoint" "$__github_upload_artifact__filepath" "$__github_upload_artifact__http_opts"
  }

  :<<'FUN'
The open pull request from a branch, a pull request by number, each with its
latest run's jobs, and a job's artifacts archive: the escape check reads them on the forge a run is on, and
no run is on GitHub.
FUN
  @review_pipeline() {
    error "github_review_pipeline: not implemented on the GitHub backend."
    return 1
  }

  @review_for_branch() {
    error "github_review_for_branch: not implemented on the GitHub backend."
    return 1
  }

  @download_job_artifacts() {
    error "github_download_job_artifacts: not implemented on the GitHub backend."
    return 1
  }

  :<<'FUN'
The run a job belongs to, a branch's head, the runs on a ref at a commit, and
cancelling one: the stale guard reads them on the forge a run is on, and
GitHub does not answer them yet.
FUN
  @current_run() {
    error "github_current_run: not implemented on the GitHub backend."
    return 1
  }

  @branch_head() {
    error "github_branch_head: not implemented on the GitHub backend."
    return 1
  }

  @running_runs() {
    error "github_running_runs: not implemented on the GitHub backend."
    return 1
  }

  @cancel_run() {
    error "github__cancel_run: not implemented on the GitHub backend."
    return 1
  }

  :<<'FUN'
The open merge requests targeting a branch, one's approval as the rules
state it, one merge request's landing run, the run started on a marked head,
and the merge that lands it: landing roles of the forge contract, which
GitHub does not answer yet.
FUN
  @open_reviews() {
    error "github_open_reviews: not implemented on the GitHub backend."
    return 1
  }

  @review_approval() {
    error "github_review_approval: not implemented on the GitHub backend."
    return 1
  }

  @landing_run() {
    error "github_landing_run: not implemented on the GitHub backend."
    return 1
  }

  @start_landing_run() {
    error "github_start_landing_run: not implemented on the GitHub backend."
    return 1
  }

  @merge_review() {
    error "github_merge_review: not implemented on the GitHub backend."
    return 1
  }

  :<<'FUN'
The landing at a commit: check C reads it on the forge the trunk is on, and
GitHub does not answer it yet.
FUN
  @landing_at() {
    error "github_landing_at: not implemented on the GitHub backend."
    return 1
  }
}
