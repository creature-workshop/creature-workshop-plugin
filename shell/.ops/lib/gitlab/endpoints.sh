#!/bin/sh

:<<'FRAGMENT'
The GitLab endpoints: the API and GraphQL bases, the REST route templates, and the builders that fill a template from an options struct.
FRAGMENT

__gitlab__BASE="${GITLAB_API_BASE:-${CI_SERVER_URL:-https://forge.creature-workshop.com}}"
__gitlab__GRAPHQL_ENDPOINT="${__gitlab__BASE}/api/graphql"
__gitlab__GRAPHQL_DIR="$SHELLOPS_DIR/lib/gitlab"
__gitlab__LABELS_ENDPOINT="/api/v4/projects/:project_id:/labels"
__gitlab__LABEL_ENDPOINT="/api/v4/projects/:project_id:/labels/:label_id:"
__gitlab__RELEASES_ENDPOINT="/api/v4/projects/:project_id:/releases"
__gitlab__RELEASE_ASSETS_LINKS_ENDPOINT="/api/v4/projects/:project_id:/releases/:tag_name:/assets/links"
__gitlab__UPLOADS_ENDPOINT="/api/v4/projects/:project_id:/uploads"
__gitlab__RAW_FILE_ENDPOINT="/api/v4/projects/:project_id:/repository/files/:filepath:/raw"
__gitlab__COMMIT_ENDPOINT="/api/v4/projects/:project_id:/repository/commits/:sha:"
__gitlab__COMMIT_MERGE_REQUESTS_ENDPOINT="/api/v4/projects/:project_id:/repository/commits/:sha:/merge_requests"
__gitlab__MERGE_REQUEST_ENDPOINT="/api/v4/projects/:project_id:/merge_requests/:iid:"
__gitlab__COMMIT_STATUSES_ENDPOINT="/api/v4/projects/:project_id:/statuses/:sha:"
__gitlab__JOB_ARTIFACTS_ENDPOINT="/api/v4/projects/:project_id:/jobs/:job_id:/artifacts"
__gitlab__BRANCH_ENDPOINT="/api/v4/projects/:project_id:/repository/branches/:branch:"
__gitlab__PIPELINES_ENDPOINT="/api/v4/projects/:project_id:/pipelines"
__gitlab__USER_ENDPOINT="/api/v4/user"
__gitlab__PIPELINE_CANCEL_ENDPOINT="/api/v4/projects/:project_id:/pipelines/:pipeline_id:/cancel"
__gitlab__MERGE_REQUESTS_ENDPOINT="/api/v4/projects/:project_id:/merge_requests"
__gitlab__MERGE_REQUEST_APPROVALS_ENDPOINT="/api/v4/projects/:project_id:/merge_requests/:iid:/approvals"
__gitlab__MERGE_REQUEST_PIPELINES_ENDPOINT="/api/v4/projects/:project_id:/merge_requests/:iid:/pipelines"
__gitlab__MERGE_REQUEST_LABEL_EVENTS_ENDPOINT="/api/v4/projects/:project_id:/merge_requests/:iid:/resource_label_events"
__gitlab__MERGE_REQUEST_ENDPOINT="/api/v4/projects/:project_id:/merge_requests/:iid:"
__gitlab__MERGE_REQUEST_MERGE_ENDPOINT="/api/v4/projects/:project_id:/merge_requests/:iid:/merge"

# CONST: The part of a merge request's page URL between the project path and the iid.
__gitlab__MERGE_REQUEST_PAGE="/-/merge_requests/"

:<<'FUN'
The instance a request goes to: the .host the options name, or this run's own
GitLab when they name none.

  __gitlab__instance '{"host":"https://gitlab.com"}'  ->  https://gitlab.com
FUN
__gitlab__instance() {
  @get __gitlab__instance__base "$1" '.host' ''
  if ! @defined "$__gitlab__instance__base"; then
    __gitlab__instance__base="$__gitlab__BASE"
  fi

  println "$__gitlab__instance__base"
}

:<<'FUN'
REST URL builder. Substitutes :placeholder: tokens against the values
read out of $options, under the instance the options' .host names, or this
run's own GitLab when they name none.

  __gitlab__rest_url '{"owner":"a","repo":"b","host":"https://gitlab.com"}' "$__gitlab__LABELS_ENDPOINT"
    ->  https://gitlab.com/api/v4/projects/a%2Fb/labels
FUN
__gitlab__rest_url() {
  __gitlab__rest_url__project_id="$(__gitlab__project_id "$1")" || return 1
  __gitlab__rest_url__base="$(__gitlab__instance "$1")"

  __gitlab__rest_url__url="${__gitlab__rest_url__base}${2}"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":project_id:" "$__gitlab__rest_url__project_id")"

  @let "$1" __gitlab__rest_url__ tag_name release_id label_id filepath_encoded sha job_id branch_encoded pipeline_id review_number

  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":tag_name:" "$__gitlab__rest_url__tag_name")"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":release_id:" "$__gitlab__rest_url__release_id")"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":label_id:" "$__gitlab__rest_url__label_id")"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":filepath:" "$__gitlab__rest_url__filepath_encoded")"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":sha:" "$__gitlab__rest_url__sha")"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":job_id:" "$__gitlab__rest_url__job_id")"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":branch:" "$__gitlab__rest_url__branch_encoded")"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":pipeline_id:" "$__gitlab__rest_url__pipeline_id")"
  __gitlab__rest_url__url="$(string__replace "$__gitlab__rest_url__url" ":iid:" "$__gitlab__rest_url__review_number")"

  echo "$__gitlab__rest_url__url"
  @unlet __gitlab__rest_url__ tag_name release_id label_id filepath_encoded sha job_id branch_encoded pipeline_id review_number
}

:<<'FUN'
Minimal URL-encoder for path segments. Encodes characters that are
unsafe in URL segments according to RFC 3986; in particular `/`.
FUN
__gitlab__url_encode() {
  __gitlab__url_encode__rest="$1"
  __gitlab__url_encode__encoded=""

  # Peel one character per iteration with parameter expansion (POSIX sh
  # has no string indexing).
  while [ -n "$__gitlab__url_encode__rest" ]; do
    __gitlab__url_encode__char="$(printf '%.1s' "$__gitlab__url_encode__rest")"
    __gitlab__url_encode__rest="${__gitlab__url_encode__rest#?}"

    case "$__gitlab__url_encode__char" in
      [a-zA-Z0-9.~_-]) __gitlab__url_encode__encoded="${__gitlab__url_encode__encoded}${__gitlab__url_encode__char}" ;;
      *) __gitlab__url_encode__encoded="${__gitlab__url_encode__encoded}$(printf '%%%02X' "'$__gitlab__url_encode__char")" ;;
    esac
  done

  printf '%s' "$__gitlab__url_encode__encoded"
}
