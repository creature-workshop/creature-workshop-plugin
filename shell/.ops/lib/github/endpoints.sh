#!/bin/sh

:<<'FRAGMENT'
The GitHub endpoints: the API bases, the route templates, and the builders that fill a template from an options struct.
FRAGMENT

# CONST: The API's origin.
__github__BASE="https://api.github.com"

# CONST: Where GitHub serves its pages, apart from the API; a pull request's page is under it.
__github__WEB="https://github.com"

# CONST: The part of a pull request's page URL between the repository and the number.
__github__PULL_PAGE="/pull/"

# CONST: The origin release assets are uploaded to.
__github__UPLOAD_BASE="https://uploads.github.com"

# CONST: The releases of a repository.
__github__RELEASE_ENDPOINT="/repos/:owner:/:repo:/releases"

# CONST: The assets of a release, where a file is uploaded under its name.
__github__UPLOAD_ENDPOINT="/repos/:owner:/:repo:/releases/:release_id:/assets?name=:filename:"

# CONST: Where a workflow is dispatched.
__github__DISPATCH_ENDPOINT="/repos/:owner:/:repo:/actions/workflows/:workflow:/dispatches"

# CONST: The runs of a workflow.
__github__WORKFLOW_RUNS_ENDPOINT="/repos/:owner:/:repo:/actions/workflows/:workflow:/runs"

# CONST: One workflow run, by id.
__github__RUN_ENDPOINT="/repos/:owner:/:repo:/actions/runs/:run_id:"

# CONST: The git ref of a tag.
__github__TAG_REF_ENDPOINT="/repos/:owner:/:repo:/git/ref/tags/:tag:"

# CONST: The release a tag carries.
__github__RELEASE_BY_TAG_ENDPOINT="/repos/:owner:/:repo:/releases/tags/:tag:"

# CONST: One repository.
__github__REPO_ENDPOINT="/repos/:owner:/:repo:"

# CONST: One commit, by sha.
__github__COMMIT_ENDPOINT="/repos/:owner:/:repo:/commits/:sha:"

# CONST: The statuses recorded on a commit.
__github__COMMIT_STATUSES_ENDPOINT="/repos/:owner:/:repo:/statuses/:sha:"

: <<'CONST'
A commit's Actions runs are read from the runs list filtered to it, which a
fine-grained token's Actions read covers on a private repository. The page is
sized past the largest workflow set a repository here runs on one push.
CONST
__github__ACTION_RUNS_ENDPOINT="/repos/:owner:/:repo:/actions/runs?head_sha=:sha:&per_page=100"

# CONST: The pull requests of a repository.
__github__PULLS_ENDPOINT="/repos/:owner:/:repo:/pulls"

# CONST: One pull request, by number.
__github__PULL_ENDPOINT="/repos/:owner:/:repo:/pulls/:review_number:"

# CONST: The reviews of a pull request.
__github__PULL_REVIEWS_ENDPOINT="/repos/:owner:/:repo:/pulls/:review_number:/reviews"

# CONST: The reviewers requested on a pull request.
__github__PULL_REVIEWERS_ENDPOINT="/repos/:owner:/:repo:/pulls/:review_number:/requested_reviewers"

# CONST: A pull request is an issue for comments, labels and assignees.
__github__ISSUE_ENDPOINT="/repos/:owner:/:repo:/issues/:issue_number:"

# CONST: The comments of an issue or pull request.
__github__ISSUE_COMMENTS_ENDPOINT="/repos/:owner:/:repo:/issues/:issue_number:/comments"

# CONST: The comments left on lines of a pull request's diff.
__github__PULL_COMMENTS_ENDPOINT="/repos/:owner:/:repo:/pulls/:review_number:/comments"

# CONST: One comment, by id, addressed repo-wide.
__github__ISSUE_COMMENT_ENDPOINT="/repos/:owner:/:repo:/issues/comments/:comment_id:"

# CONST: The labels on an issue or pull request.
__github__ISSUE_LABELS_ENDPOINT="/repos/:owner:/:repo:/issues/:issue_number:/labels"

# CONST: One label on an issue or pull request, by name.
__github__ISSUE_LABEL_ENDPOINT="/repos/:owner:/:repo:/issues/:issue_number:/labels/:label_name:"

# CONST: The labels of a repository.
__github__LABELS_ENDPOINT="/repos/:owner:/:repo:/labels"

# CONST: GitHub addresses a label by its name, not an id.
__github__LABEL_ENDPOINT="/repos/:owner:/:repo:/labels/:label_name:"

# CONST: The repositories of an organization.
__github__ORG_REPOS_ENDPOINT="/orgs/:org:/repos"

# CONST: The user the token belongs to.
__github__USER_ENDPOINT="/user"

# CONST: A file's content, by path.
__github__CONTENTS_ENDPOINT="/repos/:owner:/:repo:/contents/:filepath:"

# CONST: How many items one page of a list carries.
__github__PAGE_LIMIT=100

# CONST: One newline, for joining a struct array into lines.
__github__NL="
"

:<<'FUN'
Substitutes one :marker: in an endpoint template with the value read from
the options object at the same key.
FUN
__github__fill() {
  @get __github__fill__get_1 "$3" ".$2"
  string__replace "$1" ":$2:" "$__github__fill__get_1"
}

__github__release_endpoint() {
  __github__release_endpoint__endpoint="${__github__BASE}${__github__RELEASE_ENDPOINT}"
  __github__release_endpoint__endpoint="$(__github__fill "$__github__release_endpoint__endpoint" owner "$1")"
  __github__fill "$__github__release_endpoint__endpoint" repo "$1"
}

__github__upload_endpoint() {
  __github__upload_endpoint__endpoint="${__github__UPLOAD_BASE}${__github__UPLOAD_ENDPOINT}"
  __github__upload_endpoint__endpoint="$(__github__fill "$__github__upload_endpoint__endpoint" owner "$1")"
  __github__upload_endpoint__endpoint="$(__github__fill "$__github__upload_endpoint__endpoint" repo "$1")"
  __github__upload_endpoint__endpoint="$(__github__fill "$__github__upload_endpoint__endpoint" release_id "$1")"
  __github__fill "$__github__upload_endpoint__endpoint" filename "$1"
}

__github__dispatch_endpoint() {
  __github__dispatch_endpoint__endpoint="${__github__BASE}${__github__DISPATCH_ENDPOINT}"
  __github__dispatch_endpoint__endpoint="$(__github__fill "$__github__dispatch_endpoint__endpoint" owner "$1")"
  __github__dispatch_endpoint__endpoint="$(__github__fill "$__github__dispatch_endpoint__endpoint" repo "$1")"
  __github__fill "$__github__dispatch_endpoint__endpoint" workflow "$1"
}

__github__run_endpoint() {
  __github__run_endpoint__endpoint="${__github__BASE}${__github__RUN_ENDPOINT}"
  __github__run_endpoint__endpoint="$(__github__fill "$__github__run_endpoint__endpoint" owner "$1")"
  __github__run_endpoint__endpoint="$(__github__fill "$__github__run_endpoint__endpoint" repo "$1")"
  __github__fill "$__github__run_endpoint__endpoint" run_id "$1"
}

__github__tag_ref_endpoint() {
  __github__tag_ref_endpoint__endpoint="${__github__BASE}${__github__TAG_REF_ENDPOINT}"
  __github__tag_ref_endpoint__endpoint="$(__github__fill "$__github__tag_ref_endpoint__endpoint" owner "$1")"
  __github__tag_ref_endpoint__endpoint="$(__github__fill "$__github__tag_ref_endpoint__endpoint" repo "$1")"
  __github__fill "$__github__tag_ref_endpoint__endpoint" tag "$1"
}

__github__release_by_tag_endpoint() {
  __github__render_endpoint "$__github__RELEASE_BY_TAG_ENDPOINT" "$1"
}

:<<'FUN'
Renders an endpoint template against an options struct: every :marker: in the
template is filled from the same-named options key, owner and repo falling back
to the manifest identity. A marker whose value carries a slash, a label name
such as role/platform, is percent-encoded so it stays one path segment.

  __github__render_endpoint "/repos/:owner:/:repo:/pulls/:review_number:" '{"owner":"a","repo":"b","review_number":"7"}'
    ->  https://api.github.com/repos/a/b/pulls/7
FUN
__github__render_endpoint() {
  __github__render_endpoint__url="${__github__BASE}${1}"
  __github__render_endpoint__rest="$1"

  while :; do
    case "$__github__render_endpoint__rest" in
      *:*:*)
        __github__render_endpoint__key="${__github__render_endpoint__rest#*:}"
        __github__render_endpoint__key="${__github__render_endpoint__key%%:*}"
        __github__render_endpoint__rest="${__github__render_endpoint__rest#*:"${__github__render_endpoint__key}":}"
        ;;
      *)
        println "$__github__render_endpoint__url"
        return 0
        ;;
    esac

    case "$__github__render_endpoint__key" in
      owner) @get __github__render_endpoint__get_2 "$2" '.owner' "$(manifest__get org)"; __github__render_endpoint__value="$__github__render_endpoint__get_2" ;;
      repo)  @get __github__render_endpoint__get_3 "$2" '.repo' "$(manifest__get repo)"; __github__render_endpoint__value="$__github__render_endpoint__get_3" ;;
      label_name|filepath) @get __github__render_endpoint__get_4 "$2" ".$__github__render_endpoint__key" ''; __github__render_endpoint__value="$(http__encode "$__github__render_endpoint__get_4")" ;;
      *)     @get __github__render_endpoint__get_5 "$2" ".$__github__render_endpoint__key" ''; __github__render_endpoint__value="$__github__render_endpoint__get_5" ;;
    esac

    __github__render_endpoint__url="$(string__replace "$__github__render_endpoint__url" ":$__github__render_endpoint__key:" "$__github__render_endpoint__value")"
  done
}

:<<'FUN'
Renders template $2 against options $1 after checking that every key named in
$3 (space-separated) is set on them, failing with the options otherwise.

Usage: __github__endpoint "$options" "$__github__PULL_ENDPOINT" "review_number"
FUN
__github__endpoint() {
  for __github__endpoint__key in $3; do
    if @get __github__endpoint__get_6 "$1" ".$__github__endpoint__key" ''; ! @defined "$__github__endpoint__get_6"; then
      __github__endpoint__dump_7="$(forge__base__options_without_token "$1")"
      error "Cannot build the endpoint: no $__github__endpoint__key in $__github__endpoint__dump_7"
      return 1
    fi
  done

  __github__render_endpoint "$2" "$1"
}
