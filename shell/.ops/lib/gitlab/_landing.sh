#!/bin/sh

: <<'FRAGMENT'
The landing roles of the forge contract, answered from GitLab: the open merge
requests targeting a branch, whether one's approval rules are met and since
when, which of its pipelines is its landing run, the run started on a marked
head, and the merge it ends with.

Each is one question asked of the forge, answered as the forge states it. The
approval is the rules' own verdict, never a count of names (ADR.6@global),
which pipeline is a landing run is the mark's own history
(lib/gitlab/landing_run.awk), and nothing here reads a label to decide
anything.
FRAGMENT

: <<'FUN'
Prints the open merge requests targeting <branch>, every page read: each as
.iid, .head, .target and .labels as the merge request carries them. Fails
when the forge could not be asked.

  __gitlab__landing__open_reviews "$options" main
  -> [{"iid":555,"head":"b3d27cf9","target":"main","labels":["type/feature"]}]

args:
  $1  Forge options (.token; .owner and .repo optional)
  $2  The branch the merge requests target
FUN
__gitlab__landing__open_reviews() {
  __gitlab__landing__open_reviews__endpoint="$(__gitlab__rest_url "$1" "$__gitlab__MERGE_REQUESTS_ENDPOINT")" || return 1
  __gitlab__landing__open_reviews__http_opts="$(__gitlab__landing__http_opts "$1")" || return 1
  @obj __gitlab__landing__open_reviews__obj_1 '.state' opened '.target_branch' "$2"
  __gitlab__landing__open_reviews__query="$(http__query_string "$__gitlab__landing__open_reviews__obj_1")"
  __gitlab__landing__open_reviews__open="$(__gitlab__rest_paginate \
    "$__gitlab__landing__open_reviews__endpoint" \
    "$__gitlab__landing__open_reviews__http_opts" \
    100 \
    "$__gitlab__landing__open_reviews__query"
  )" || return 1

  @run_awk __gitlab__landing__open_reviews__out \
    "$__gitlab__GRAPHQL_DIR/open_reviews.awk" \
    "$__gitlab__landing__open_reviews__open" \
    --load "$__gitlab__GRAPHQL_DIR/shape.awk" || return 1
  println "$__gitlab__landing__open_reviews__out"
}

: <<'FUN'
Prints whether the merge request's approval rules are met and when it became
ready, as epoch seconds, 0 for a merge request nobody has approved. Fails
when the forge could not be asked.

  __gitlab__landing__approval "$options"  ->  {"approved":true,"approved_at":1790292997}

args:
  $1  Forge options (.review_number, .token)
FUN
__gitlab__landing__approval() {
  __gitlab__landing__approval__payload="$(__gitlab__landing__get "$1" "$__gitlab__MERGE_REQUEST_APPROVALS_ENDPOINT")" || return 1
  @run_awk __gitlab__landing__approval__read \
    "$__gitlab__GRAPHQL_DIR/approval.awk" \
    "$__gitlab__landing__approval__payload" \
    --load "$__gitlab__GRAPHQL_DIR/shape.awk" \
    || return 1
  @get __gitlab__landing__approval__at "$__gitlab__landing__approval__read" '.approved_at' ''

  if ! @defined "$__gitlab__landing__approval__at"; then
    @set __gitlab__landing__approval__out "$__gitlab__landing__approval__read" '.approved_at' 0
    println "$__gitlab__landing__approval__out"
    return 0
  fi

  @set __gitlab__landing__approval__out "$__gitlab__landing__approval__read" '.approved_at' "$(time__epoch_of "$__gitlab__landing__approval__at")"
  println "$__gitlab__landing__approval__out"
}

: <<'FUN'
Prints the merge request's landing run, as .id, .sha and .status, and null
when it has none: the newest pipeline created while it carried the landing
mark (lib/gitlab/landing_run.awk). Fails when the forge could not be asked, or
when a run carries a status the adaptor does not know.

  __gitlab__landing__run "$options"  ->  {"id":"7012","sha":"b3d27cf9","status":"running"}

args:
  $1  Forge options (.review_number, .token)
FUN
__gitlab__landing__run() {
  __gitlab__landing__run__pipelines="$(__gitlab__landing__list "$1" "$__gitlab__MERGE_REQUEST_PIPELINES_ENDPOINT")" || return 1
  __gitlab__landing__run__events="$(__gitlab__landing__list "$1" "$__gitlab__MERGE_REQUEST_LABEL_EVENTS_ENDPOINT")" || return 1
  @obj __gitlab__landing__run__read \
    '.pipelines' "$__gitlab__landing__run__pipelines" \
    '.events' "$__gitlab__landing__run__events" \
    '.label' "$__gitlab__LANDING_LABEL"

  @run_awk __gitlab__landing__run__out \
    "$__gitlab__GRAPHQL_DIR/landing_run.awk" \
    "$__gitlab__landing__run__read" \
    --load "$__gitlab__GRAPHQL_DIR/runs.awk" \
    || return 1
  println "$__gitlab__landing__run__out"
}

: <<'FUN'
Creates the landing run on the marked merge request's head and prints it, as
.id, .sha and .status. The mark must already be on: GitLab snapshots the
labels as it creates the pipeline, and the rules read them there, so a run
created before the mark is a governance run for good. Fails when the forge
refuses.

  __gitlab__landing__start "$options"  ->  {"id":"7036","sha":"b3d27cf9","status":"running"}

args:
  $1  Forge options (.review_number, .token)
FUN
__gitlab__landing__start() {
  __gitlab__landing__start__endpoint="$(__gitlab__landing__endpoint "$1" "$__gitlab__MERGE_REQUEST_PIPELINES_ENDPOINT")" || return 1
  __gitlab__landing__start__http_opts="$(__gitlab__landing__http_opts "$1")" || return 1
  @obj __gitlab__landing__start__obj_2
  __gitlab__landing__start__pipeline="$(http__post \
    "$__gitlab__landing__start__endpoint" \
    "$__gitlab__landing__start__obj_2" \
    "$__gitlab__landing__start__http_opts"
  )" || return 1

  @run_awk __gitlab__landing__start__out \
    "$__gitlab__GRAPHQL_DIR/started_run.awk" \
    "$__gitlab__landing__start__pipeline" \
    --load "$__gitlab__GRAPHQL_DIR/runs.awk" || return 1
  println "$__gitlab__landing__start__out"
}

: <<'FUN'
Merges the merge request at <sha>, unsquashed, and prints the commit the
merge left on the target branch. The merge carries the head that was tested,
so a push since the head was read refuses the merge rather than landing an
untested tree. Squash comes off first because it is the merge request's own
attribute on GitLab and a merge call that says otherwise is ignored. Fails
when the forge refuses either.

  __gitlab__landing__merge "$options" b3d27cf9  ->  7d681d79...

args:
  $1  Forge options (.review_number, .token)
  $2  The head the merge lands
FUN
__gitlab__landing__merge() {
  __gitlab__landing__merge__http_opts="$(__gitlab__landing__http_opts "$1")" || return 1
  __gitlab__landing__merge__review="$(__gitlab__landing__endpoint "$1" "$__gitlab__MERGE_REQUEST_ENDPOINT")" || return 1
  __gitlab__landing__merge__endpoint="$(__gitlab__landing__endpoint "$1" "$__gitlab__MERGE_REQUEST_MERGE_ENDPOINT")" || return 1

  @obj __gitlab__landing__merge__obj_3 '.squash' false
  http__put \
    "$__gitlab__landing__merge__review" \
    "$__gitlab__landing__merge__obj_3" \
    "$__gitlab__landing__merge__http_opts" \
    > /dev/null || return 1

  @obj __gitlab__landing__merge__obj_4 '.sha' "$2" '.squash' false
  __gitlab__landing__merge__merged="$(http__put \
    "$__gitlab__landing__merge__endpoint" \
    "$__gitlab__landing__merge__obj_4" \
    "$__gitlab__landing__merge__http_opts"
  )" || return 1

  @get __gitlab__landing__merge__out "$__gitlab__landing__merge__merged" '.merge_commit_sha' ''
  println "$__gitlab__landing__merge__out"
}

: <<'FUN'
Prints the REST URL of <endpoint> for the merge request the options name.
Fails when the options name no merge request, or the project cannot be
resolved.
FUN
__gitlab__landing__endpoint() {
  if @get __gitlab__landing__endpoint__get_5 "$1" '.review_number' ''; ! @defined "$__gitlab__landing__endpoint__get_5"; then
    error "gitlab landing: missing review_number (MR iid)"
    return 1
  fi

  __gitlab__rest_url "$1" "$2"
}

: <<'FUN'
Prints the authorization the options' token carries. Fails when they carry
none.
FUN
__gitlab__landing__http_opts() {
  __gitlab__landing__http_opts__token="$(__gitlab__validate_token "$1")" || return 1

  __gitlab__http_opts "$__gitlab__landing__http_opts__token"
}

: <<'FUN'
Prints what the merge request's <endpoint> answers. Fails when the forge
could not be asked.
FUN
__gitlab__landing__get() {
  __gitlab__landing__get__endpoint="$(__gitlab__landing__endpoint "$1" "$2")" || return 1
  __gitlab__landing__get__http_opts="$(__gitlab__landing__http_opts "$1")" || return 1

  http__get "$__gitlab__landing__get__endpoint" "$__gitlab__landing__get__http_opts"
}

: <<'FUN'
Prints every page of the merge request's <endpoint> as one array. Fails when
the forge could not be asked.
FUN
__gitlab__landing__list() {
  __gitlab__landing__list__endpoint="$(__gitlab__landing__endpoint "$1" "$2")" || return 1
  __gitlab__landing__list__http_opts="$(__gitlab__landing__http_opts "$1")" || return 1

  __gitlab__rest_paginate "$__gitlab__landing__list__endpoint" "$__gitlab__landing__list__http_opts" 100
}
