#!/bin/sh

:<<'FRAGMENT'
The Forgejo endpoints: the API base, the route templates, and the renderer that fills a template from an options struct.
FRAGMENT

: <<'CONST'
The instance's canonical URL, which the run links an adaptor returns carry.
FORGEJO_API_BASE names another instance, and a site names the host it runs on.
CONST
__forgejo__BASE="${FORGEJO_API_BASE:-https://staging.creature-workshop.com}"

# CONST: The part of a pull request's page URL between the repository and the number.
__forgejo__PULL_PAGE="/pulls/"

# CONST: The releases of a repository.
__forgejo__RELEASE_ENDPOINT="/api/v1/repos/:owner:/:repo:/releases"

# CONST: The assets of a release, where a file is uploaded under its name.
__forgejo__UPLOAD_ENDPOINT="/api/v1/repos/:owner:/:repo:/releases/:release_id:/assets?name=:filename:"

# CONST: The pull requests of a repository.
__forgejo__PULL_REQUESTS_ENDPOINT="/api/v1/repos/:owner:/:repo:/pulls"

# CONST: One pull request, by number.
__forgejo__PULL_REQUEST_ENDPOINT="/api/v1/repos/:owner:/:repo:/pulls/:review_number:"

# CONST: The labels of a repository.
__forgejo__LABELS_ENDPOINT="/api/v1/repos/:owner:/:repo:/labels"

# CONST: One label, by id.
__forgejo__LABEL_ENDPOINT="/api/v1/repos/:owner:/:repo:/labels/:label_id:"

# CONST: The comments of an issue or pull request.
__forgejo__ISSUE_COMMENTS_ENDPOINT="/api/v1/repos/:owner:/:repo:/issues/:issue_number:/comments"

# CONST: Comments are addressed repo-wide, not under their issue, once you have the id.
__forgejo__ISSUE_COMMENT_ENDPOINT="/api/v1/repos/:owner:/:repo:/issues/comments/:comment_id:"

# CONST: How many records one page of a paged list carries.
__forgejo__COMMENT_PAGE_LIMIT=50

# CONST: The reviews of a pull request, each a pass a reviewer submitted.
__forgejo__PULL_REVIEWS_ENDPOINT="/api/v1/repos/:owner:/:repo:/pulls/:review_number:/reviews"

# CONST: The comments one review left on lines of the diff.
__forgejo__PULL_REVIEW_COMMENTS_ENDPOINT="/api/v1/repos/:owner:/:repo:/pulls/:review_number:/reviews/:review_id:/comments"

# CONST: The repositories of an organization.
__forgejo__ORG_REPOS_ENDPOINT="/api/v1/orgs/:org:/repos"

# CONST: A file's content, raw, by path.
__forgejo__RAW_FILE_ENDPOINT="/api/v1/repos/:owner:/:repo:/raw/:filepath:"

# CONST: One commit, by sha.
__forgejo__GIT_COMMIT_ENDPOINT="/api/v1/repos/:owner:/:repo:/git/commits/:sha:"

# CONST: The user the token belongs to.
__forgejo__USER_ENDPOINT="/api/v1/user"

# CONST: The statuses recorded on a commit.
__forgejo__COMMIT_STATUSES_ENDPOINT="/api/v1/repos/:owner:/:repo:/statuses/:sha:"

: <<'CONST'
Forgejo Actions record no commit status, so a commit's runs are read from the
runs list filtered to it. The page is sized past the largest workflow set a
repository here runs on one push.
CONST
__forgejo__ACTION_RUNS_ENDPOINT="/api/v1/repos/:owner:/:repo:/actions/runs?head_sha=:sha:&limit=100"

: <<'CONST'
A generic package lives under its owner, not a repository, so the mirror of a
project need not exist for its files to be published here.
CONST
__forgejo__GENERIC_PACKAGE_FILE_ENDPOINT="/api/packages/:owner:/generic/:package:/:version:/:filename:"

:<<'FUN'
Renders an endpoint template against an options struct. Every :marker: in
the template is filled from the options key of the same name, read with
@get; owner and repo fall back to the manifest's identity. The URL is built
under the instance the options' .host names, or this run's own instance
when they name none. The template drives the scan, so an endpoint builder
is one render call after its own validation.

  __forgejo__render_endpoint "$__forgejo__LABELS_ENDPOINT" '{"owner":"a","repo":"b","host":"https://forgejo.example"}'
    ->  https://forgejo.example/api/v1/repos/a/b/labels
FUN
__forgejo__render_endpoint() {
  @get __forgejo__render_endpoint__base "$2" '.host' ''
  if ! @defined "$__forgejo__render_endpoint__base"; then
    __forgejo__render_endpoint__base="$__forgejo__BASE"
  fi
  __forgejo__render_endpoint__url="${__forgejo__render_endpoint__base}${1}"
  __forgejo__render_endpoint__rest="$1"

  while :; do
    case "$__forgejo__render_endpoint__rest" in
      *:*:*)
        __forgejo__render_endpoint__key="${__forgejo__render_endpoint__rest#*:}"
        __forgejo__render_endpoint__key="${__forgejo__render_endpoint__key%%:*}"
        __forgejo__render_endpoint__rest="${__forgejo__render_endpoint__rest#*:"${__forgejo__render_endpoint__key}":}"
        ;;
      *)
        println "$__forgejo__render_endpoint__url"
        return 0
        ;;
    esac

    case "$__forgejo__render_endpoint__key" in
      owner) @get __forgejo__render_endpoint__get_1 "$2" '.owner' "$(manifest__get org)"; __forgejo__render_endpoint__value="$__forgejo__render_endpoint__get_1" ;;
      repo)  @get __forgejo__render_endpoint__get_2 "$2" '.repo' "$(manifest__get repo)"; __forgejo__render_endpoint__value="$__forgejo__render_endpoint__get_2" ;;
      *)     @get __forgejo__render_endpoint__get_3 "$2" ".$__forgejo__render_endpoint__key" ''; __forgejo__render_endpoint__value="$__forgejo__render_endpoint__get_3" ;;
    esac

    __forgejo__render_endpoint__url="$(string__replace "$__forgejo__render_endpoint__url" ":$__forgejo__render_endpoint__key:" "$__forgejo__render_endpoint__value")"
  done
}

__forgejo__release_endpoint() {
  @let "$1" __forgejo__release_endpoint__ owner repo
  if ! @defined "$__forgejo__release_endpoint__owner"; then
    __forgejo__release_endpoint__dump_4="$(forge__base__options_without_token "$1")"
    error "Cannot format release endpoint. No owner is defined: $__forgejo__release_endpoint__dump_4"
    return 1
  fi

  if ! @defined "$__forgejo__release_endpoint__repo"; then
    __forgejo__release_endpoint__dump_5="$(forge__base__options_without_token "$1")"
    error "Cannot format release endpoint. No repo is defined: $__forgejo__release_endpoint__dump_5"
    return 1
  fi

  @unlet __forgejo__release_endpoint__ owner repo
  __forgejo__render_endpoint "$__forgejo__RELEASE_ENDPOINT" "$1"
}

__forgejo__package_file_endpoint() {
  __forgejo__render_endpoint "$__forgejo__GENERIC_PACKAGE_FILE_ENDPOINT" "$1"
}

__forgejo__upload_endpoint() {
  __forgejo__render_endpoint "$__forgejo__UPLOAD_ENDPOINT" "$1"
}

__forgejo__pull_requests_endpoint() {
  @let "$1" __forgejo__pull_requests_endpoint__ owner repo
  @defined "$__forgejo__pull_requests_endpoint__owner" \
    || __forgejo__pull_requests_endpoint__owner="$(manifest__get org)"
  @defined "$__forgejo__pull_requests_endpoint__repo" \
    || __forgejo__pull_requests_endpoint__repo="$(manifest__get repo)"

  if ! @defined "$__forgejo__pull_requests_endpoint__owner" || ! @defined "$__forgejo__pull_requests_endpoint__repo"; then
    __forgejo__pull_requests_endpoint__dump_6="$(forge__base__options_without_token "$1")"
    error "Cannot create pull requests endpoint. Missing owner or repo: $__forgejo__pull_requests_endpoint__dump_6"
    return 1
  fi

  @unlet __forgejo__pull_requests_endpoint__ owner repo
  __forgejo__render_endpoint "$__forgejo__PULL_REQUESTS_ENDPOINT" "$1"
}

__forgejo__pull_request_endpoint() {
  if @get __forgejo__pull_request_endpoint__get_7 "$1" '.review_number'; ! @defined "$__forgejo__pull_request_endpoint__get_7"; then
    error "Cannot create PR endpoint. Pull request number is undefined"
    return 1
  fi

  __forgejo__render_endpoint "$__forgejo__PULL_REQUEST_ENDPOINT" "$1"
}

__forgejo__pull_reviews_endpoint() {
  if @get __forgejo__pull_reviews_endpoint__get_8 "$1" '.review_number'; ! @defined "$__forgejo__pull_reviews_endpoint__get_8"; then
    error "Cannot create pull reviews endpoint. Pull request number is undefined"
    return 1
  fi

  __forgejo__render_endpoint "$__forgejo__PULL_REVIEWS_ENDPOINT" "$1"
}

__forgejo__comments_endpoint() {
  if @get __forgejo__comments_endpoint__get_9 "$1" '.issue_number'; ! @defined "$__forgejo__comments_endpoint__get_9"; then
    error "Cannot create comments endpoint. Issue number is undefined"
    return 1
  fi

  __forgejo__render_endpoint "$__forgejo__ISSUE_COMMENTS_ENDPOINT" "$1"
}

__forgejo__labels_endpoint() {
  @let "$1" __forgejo__labels_endpoint__ owner repo
  if ! @defined "$__forgejo__labels_endpoint__owner" || ! @defined "$__forgejo__labels_endpoint__repo"; then
    __forgejo__labels_endpoint__dump_10="$(forge__base__options_without_token "$1")"
    error "Cannot format labels endpoint. Missing owner or repo: $__forgejo__labels_endpoint__dump_10"
    return 1
  fi

  @unlet __forgejo__labels_endpoint__ owner repo
  __forgejo__render_endpoint "$__forgejo__LABELS_ENDPOINT" "$1"
}

__forgejo__label_endpoint() {
  @let "$1" __forgejo__label_endpoint__ owner repo label_id
  if ! @defined "$__forgejo__label_endpoint__owner" || ! @defined "$__forgejo__label_endpoint__repo" || ! @defined "$__forgejo__label_endpoint__label_id"; then
    __forgejo__label_endpoint__dump_11="$(forge__base__options_without_token "$1")"
    error "Cannot format label endpoint. Missing owner, repo, or label_id: $__forgejo__label_endpoint__dump_11"
    return 1
  fi

  @unlet __forgejo__label_endpoint__ owner repo label_id
  __forgejo__render_endpoint "$__forgejo__LABEL_ENDPOINT" "$1"
}

__forgejo__org_repos_endpoint() {
  if @get __forgejo__org_repos_endpoint__get_12 "$1" '.org'; ! @defined "$__forgejo__org_repos_endpoint__get_12"; then
    error "Cannot format org repos endpoint. Missing org."
    return 1
  fi

  __forgejo__render_endpoint "$__forgejo__ORG_REPOS_ENDPOINT" "$1"
}

__forgejo__raw_file_endpoint() {
  @let "$1" __forgejo__raw_file_endpoint__ owner repo
  if ! @defined "$__forgejo__raw_file_endpoint__owner" || ! @defined "$__forgejo__raw_file_endpoint__repo"; then
    error "Cannot format raw file endpoint. Missing owner or repo."
    return 1
  fi

  @unlet __forgejo__raw_file_endpoint__ owner repo
  @set __forgejo__raw_file_endpoint__set_13 "$1" '.filepath' "$2"
  __forgejo__render_endpoint "$__forgejo__RAW_FILE_ENDPOINT" "$__forgejo__raw_file_endpoint__set_13"
}
