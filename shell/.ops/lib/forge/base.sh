#!/bin/sh

:<<'MODULE'
Common base for the forge adaptors (the bottom of the forge "sandwich"):

  lib/forge/api.sh        facade  -- forge_* dispatchers + selector (top)
  lib/{forgejo,gitlab}/   adaptor -- <forge>_* implementations (middle)
  lib/forge/base.sh       base    -- shared contract + option shapes (here)

This layer knows nothing about which forge is selected. It holds the pieces
that are identical across adaptors so they are written once:

  - The option constructors (forge_new_*_options). These return a JSON blob
    of defaults that callers populate with @set before invoking an
    operation. The shape is a *superset* across forges: a backend ignores
    the keys it has no use for, so a single constructor serves every backend.
    A code review has two of them, because opening one and asking about one
    take different keys: forge__new_create_review_options carries the title,
    branches, body, labels and assignees an open takes, and
    forge__new_review_options the branch, number and reviewer a lookup or a
    hand-back takes.

Adaptor contract -- the roles an adaptor's @forge.<forge> structural contract
declares, re-homed to these namespaced functions when it loads and dispatched
to as forge_<op>:

  <forge>_api_base              <forge>_token_env
  <forge>_create_release        <forge>_upload_artifact
  <forge>_get_review      <forge>_create_review
  <forge>_list_comments         <forge>_create_comment
  <forge>_list_review_comments      <forge>_create_review_comment
  <forge>_list_review_thread_comments
  <forge>_list_labels           <forge>_create_label        <forge>_edit_label
  <forge>_list_org_repos        <forge>_get_raw_file
  <forge>_merged_reviews_since  <forge>_default_branch
  <forge>_code_review_refs      <forge>_current_review
  <forge>_review_labels         <forge>_pushed_range
  <forge>_reviews_awaiting_author
  <forge>_request_review        <forge>_review_merge_command
  <forge>_run_status
  <forge>_review_for_branch     <forge>_review_pipeline
  <forge>_review_from_url       <forge>_review_url
  <forge>_repository
  <forge>_review_commit_range
  <forge>_download_job_artifacts <forge>_no_run_push_options
  <forge>_create_commit_status  <forge>_current_user

Some of them answer with nothing at all where the question has no answer, and
that emptiness is a real answer rather than a failure: exit status is reserved
for failure, so a caller reads them through a bare assignment, which carries the
substitution's status and still aborts under set -e if the lookup genuinely
breaks.

  review="$(forge__current_review)"
  [ -n "$review" ] || ...    # no review, not an error

Returns:
  <forge>_merged_reviews_since "$since" "$branch"
      A JSON array of the code reviews merged into <branch> at or after the ISO
      timestamp <since>, each shaped {iid, merged_at, labels:[title...]}. An
      empty <since> means "from genesis".
  <forge>_list_review_comments
      A code review's conversation oldest first: the comments on the review
      itself, none of them anchored to its diff. The forges disagree on
      default order, so each adaptor asks for this one: which comment came
      first is a question about the review, not the backend.
  <forge>_list_review_thread_comments
      The comments in the threads on a code review's diff, oldest first, each
      anchored to a line, in the same shape the conversation comes in. Kept
      apart from the conversation because a reader weighs the two
      differently, and a backend that files them together partitions.
  <forge>_current_review
      The iid of the code review the CI run is building, and nothing when it is
      building a branch instead.
  <forge>_review_labels
      The labels of that code review as a struct array of label names, empty
      when it carries none. Call it only where <forge>_current_review named one.
  <forge>_default_branch
      The repository's default branch: the release line.
  <forge>_token_env
      The name of the environment variable a token for that forge arrives in,
      when the forge is asked by name rather than being the one the run is on.
      The facade reads it so that no caller spells a token's name for a forge.
  <forge>_code_review_refs "$commit_text"
      The code review numbers (pull/merge request iids) the given commit-message
      text refers to, one per line, per the forge's own reference convention.
  <forge>_pushed_range
      The commit range the run was triggered for, as <before>..<after>, and
      nothing when the runner reports no baseline -- a first push, where the
      pushed-from commit does not exist. What to read instead of a range that
      was never pushed is the caller's policy: a forge knows what its runner
      told it and nothing more.
  <forge>_reviews_awaiting_author "$options"
      The open, unmerged code reviews that are waiting on their author: a
      reviewer asked for changes and has not been asked to look again. Each is
      shaped {iid, url, branch, draft, reviewers:[username...]}, listing only the
      reviewers in that state; a review with none of them is left out. An empty
      .branch selects every open review in the project.
  <forge>_request_review "$options"
      Hands a code review (.review_number) back to a reviewer (.reviewer), which is
      what takes it out of <forge>_reviews_awaiting_author. Each forge spells this
      its own way, so it belongs to the adaptor.
  <forge>_mention "$username"
      The username as a mention in the forge's own markup, the spelling that
      makes the forge notify that user.
  <forge>_no_run_push_options
      The git push options, as a struct array of strings, that ask the forge
      to run nothing for the push they travel with. Empty on a forge that
      offers none, where a push runs whatever the ref's configuration says.
  <forge>_run_status "$options"
      One look at what the forge knows of the commit .sha in the repository
      .owner/.repo, as {carried, state, url}. .carried is false while the
      forge's copy does not hold the commit, and the rest is then empty. Once
      it does, .state is "none" when the forge ran nothing on it, "pending"
      while any run is still going, "failure" as soon as one run has failed
      or been cancelled, and "success" once every run has passed; .url is the
      failed run's page, or else the first run's. A skipped run counts as no
      run at all. An empty .token asks without authenticating, which a public
      repository allows.
  <forge>_review_for_branch "$options"
      The open code review from the branch .branch, with its head pipeline and
      that pipeline's jobs, as {iid, base, pipeline: {id, status} | null,
      jobs: [{id, name, status, archive}]}: .archive says whether the job
      kept an artifacts archive. A branch with no open review is a failure.
  <forge>_review_pipeline "$options"
      The code review .review_number, open or merged, in the same shape. A
      merged review's branch is gone but its pipeline is not, so this is how a
      later pipeline reads the archives it left.
  <forge>_review_from_url "$url"
      Parses the owner, repository, and review ID number from a review URL,
      in the form {owner, repo, review_number}. Prints nothing when the page
      is unrecognized.
  <forge>_review_url "$options"
      Given an object {owner, repo, review_number}, prints the URL of the
      review.
  <forge>_repository
      Prints the repository this adaptor is working in, as {owner, repo},
      the keys the other ops take: the one the forge's CI names for its own
      pipeline, or the manifest's org and repo when no pipeline names one.
      On GitLab the owner is the group path, nested groups included.
  <forge>_review_commit_range
      Prints the commits a code review adds, as the range <base>..<head>:
      from the review's target as it was when the pipeline started, to the
      commit under review. Prints nothing outside a code-review pipeline, or
      when the pipeline gives no base.
  <forge>_download_job_artifacts "$options" "$dest"
      The artifacts archive job .job_id kept, downloaded as the forge serves
      it to the file <dest>.
  <forge>_create_commit_status "$options"
      Records .state, the outcome another forge's run reached, on the commit
      .sha of this forge's own copy, under the name .name and linking .url.
      The three outcomes a run reaches -- "success", "failure", and "none"
      for a commit the forge ran nothing on -- are the three a status
      records, each in the backend's own word for that outcome.
      forge__base__commit_status_body assembles the body each backend posts.

  <forge>_current_user "$options"
      The username the options' .token authenticates as, on the instance
      .host names, so a caller can say who is acting without being told.

Adaptors source this file so their direct callers (e.g. a CLI pinned to one
backend) also get the option constructors.
MODULE

import "$SHELLOPS_DIR/lib/manifest/api.sh"

: <<'PUB_CONST'
The three outcomes a run reaches, in the words the adaptors' run_status
programs answer with. "pending" is a run_status state and never an outcome;
a status records an outcome, so these are also the keys of a backend's word
table. Public because the wait, the status body and the actions that read
an outcome all dispatch on the same words.
PUB_CONST
@enum forge__OUTCOME SUCCESS FAILURE NONE

: <<'PUB_CONST'
The three states forge__review_state reports a code review in, whatever
words the backend uses for them: open while the review can still merge,
merged once it has merged, and closed when it was closed without merging.
PUB_CONST
@enum forge__REVIEW_STATE OPEN MERGED CLOSED

: <<'CONST'
Both forges spell "there was no previous commit" as an all-zero SHA in the
variable they push it through, so the adaptors read it from here.
CONST
__forge__base__NULL_SHA="0000000000000000000000000000000000000000"

:<<'PUB_FUN'
Assembles the range an adaptor read out of its own variables, for adaptors
implementing <forge>_pushed_range. Prints nothing when <before> is absent or the
all-zero SHA, which is the contract's "no baseline".

Usage: forge__base__range "$before" "$after"
PUB_FUN
forge__base__range() {
  if [ -z "$1" ] || [ "$1" = "$__forge__base__NULL_SHA" ]; then
    return 0
  fi

  printf '%s..%s\n' "$1" "$2"
}


:<<'PUB_FUN'
Prints the number at the start of REST, the part of a page URL that follows
the code review's path segment. The number ends at the first slash, hash or
question mark, so a tab such as /diffs or a comment anchor such as #note_1
is left out. Prints nothing when REST does not start with a whole number.
For adaptors that implement <forge>_review_from_url.

  forge__base__page_number "7#note_1"     ->  7
  forge__base__page_number "7/diffs?x=1"  ->  7
  forge__base__page_number "new"          ->  nothing

Usage: forge__base__page_number "$rest"
PUB_FUN
forge__base__page_number() {
  __forge__base__page_number__number="${1%%/*}"
  __forge__base__page_number__number="${__forge__base__page_number__number%%\#*}"
  __forge__base__page_number__number="${__forge__base__page_number__number%%\?*}"
  if @is_int "$__forge__base__page_number__number"; then
    println "$__forge__base__page_number__number"
  fi
}

:<<'PUB_FUN'
Parses the owner, repository, and review ID number from the review URL $1,
in the form {owner, repo, review_number}. $2 is the forge's base URL and $3
is the path segment the forge puts between the repository and the number,
for example /-/merge_requests/ on GitLab. Prints nothing when the page is
unrecognized: a URL on another host, or one that is not a review's page.
The owner is everything before the repository's last path segment, so a
nested group on GitLab is one owner.

Adaptors that implement <forge>_review_from_url call this with their own
base and segment, so the URL is parsed in one place.

  forge__base__review_from_url https://gl.example/org/sub/tool/-/merge_requests/7#note_1 https://gl.example /-/merge_requests/
    -> {"owner": "org/sub", "repo": "tool", "review_number": 7}

Usage: forge__base__review_from_url "$url" "$base" "$segment"
PUB_FUN
forge__base__review_from_url() {
  if ! @is_true "$(__forge__base__is_review_page "$1" "$2" "$3")"; then
    return 0
  fi

  __forge__base__review_from_url__rest="${1#"$2"/}"
  __forge__base__review_from_url__path="${__forge__base__review_from_url__rest%%"$3"*}"
  __forge__base__review_from_url__number="$(
    forge__base__page_number "${__forge__base__review_from_url__rest#*"$3"}"
  )"
  @defined "$__forge__base__review_from_url__number" || return 0

  @obj __forge__base__review_from_url__out \
    '.owner' "${__forge__base__review_from_url__path%/*}" \
    '.repo' "${__forge__base__review_from_url__path##*/}" \
    '.review_number' "$__forge__base__review_from_url__number"
  println "$__forge__base__review_from_url__out"
}

:<<'FUN'
Prints true when the URL $1 has the shape of a review page on the forge
whose base URL is $2 and whose path segment is $3: the base, then an owner
and a repository, then the segment and whatever follows it. False for any
other URL.

  __forge__base__is_review_page https://fj.example/org/tool/pulls/7 https://fj.example /pulls/   ->  true
  __forge__base__is_review_page https://fj.example/org/tool/issues/9 https://fj.example /pulls/  ->  false

Usage: __forge__base__is_review_page "$url" "$base" "$segment"
FUN
__forge__base__is_review_page() {
  case "$1" in
    "$2"/*/*"$3"*) @true __forge__base__is_review_page__out; println "$__forge__base__is_review_page__out" ;;
    *) @false __forge__base__is_review_page__out; println "$__forge__base__is_review_page__out" ;;
  esac
}

:<<'PUB_FUN'
Given an object {owner, repo, review_number} as $1, prints the URL of the
review on the forge whose base URL is $2 and whose path segment between the
repository and the number is $3. This is the inverse of
forge__base__review_from_url. Prints nothing when the object has no
review_number. For adaptors that implement <forge>_review_url.

  forge__base__review_url '{"owner": "org", "repo": "tool", "review_number": 7}' https://fj.example /pulls/
    -> https://fj.example/org/tool/pulls/7

Usage: forge__base__review_url "$options" "$base" "$segment"
PUB_FUN
forge__base__review_url() {
  @let "$1" __forge__base__review_url__ owner repo review_number
  __forge__base__review_url__path="$__forge__base__review_url__owner/$__forge__base__review_url__repo"
  __forge__base__review_url__number="$__forge__base__review_url__review_number"
  @unlet __forge__base__review_url__ owner repo review_number
  if ! @defined "$__forge__base__review_url__number"; then
    return 0
  fi

  printf '%s/%s%s%s\n' \
    "$2" \
    "$__forge__base__review_url__path" \
    "$3" \
    "$__forge__base__review_url__number"
}

:<<'PUB_FUN'
Splits the repository path $1, <owner>/<repo>, into {owner, repo}. The
owner is everything before the last slash, so a nested group on GitLab is
one owner. For adaptors that implement <forge>_repository.

  forge__base__repository_of org/sub/tool  ->  {"owner": "org/sub", "repo": "tool"}

Usage: forge__base__repository_of "$path"
PUB_FUN
forge__base__repository_of() {
  @obj __forge__base__repository_of__out \
    '.owner' "${1%/*}" \
    '.repo' "${1##*/}"
  println "$__forge__base__repository_of__out"
}

:<<'PUB_FUN'
Prints the repository the manifest names, as <org>/<repo>. Adaptors that
implement <forge>_repository fall back to this when the forge's CI does not
name one. Fails when the manifest has no org or repo.

Usage: forge__base__manifest_repository
PUB_FUN
forge__base__manifest_repository() {
  __forge__base__manifest_repository__org="$(manifest__get org)" || return 1
  __forge__base__manifest_repository__repo="$(manifest__get repo)" || return 1

  printf '%s/%s\n' "$__forge__base__manifest_repository__org" "$__forge__base__manifest_repository__repo"
}

:<<'PUB_FUN'
Copies a caller's request budget -- .max_time and .retries -- out of an options
blob and onto the HTTP options an adaptor is about to send.

The http layer escalates timeouts across three attempts, which is right for CI
and wrong for anything a person is waiting on: a caller that must answer inside
a fixed window, or not at all, sets its own ceiling and gets a fast failure
instead of a slow one. A key the options blob leaves empty is not copied, so the
http defaults stand where no ceiling was asked for.

Usage: forge__base__with_budget "$http_opts" "$options"
PUB_FUN
forge__base__with_budget() {
  @let "$2" __forge__base__with_budget__ max_time retries

  @patch __forge__base__with_budget__out "$1" \
    '.max_time' "$__forge__base__with_budget__max_time" \
    '.retries'  "$__forge__base__with_budget__retries"
  println "$__forge__base__with_budget__out"
  __forge__base__with_budget__status=$?
  @unlet __forge__base__with_budget__ max_time retries
  return "$__forge__base__with_budget__status"
}

:<<'PUB_FUN'
Default release options populated with owner/repo from manifest.json.

The .ref key is the commit or branch the release targets.

Usage: forge__new_release_options
PUB_FUN
forge__new_release_options() {
  @obj __forge__new_release_options__out \
    '.owner'      "$(manifest__get org)" \
    '.repo'       "$(manifest__get repo)" \
    '.tag_name'   "" \
    '.name'       "" \
    '.body'       "" \
    '.prerelease' false \
    '.ref'        "" \
    '.token'      ""
  println "$__forge__new_release_options__out"
}

:<<'PUB_FUN'
Default release-asset upload options populated with owner/repo from
manifest.json.

The .tag_name key identifies the release by tag; .link_type is the uploaded
asset's link type.

Usage: forge__new_upload_options
PUB_FUN
forge__new_upload_options() {
  @obj __forge__new_upload_options__out \
    '.owner'      "$(manifest__get org)" \
    '.repo'       "$(manifest__get repo)" \
    '.release_id' "" \
    '.tag_name'   "" \
    '.filename'   "" \
    '.filepath'   "" \
    '.link_type'  "other" \
    '.token'      ""
  println "$__forge__new_upload_options__out"
}

:<<'PUB_FUN'
Default options for opening a code review (Forgejo: pull-request, GitLab:
merge-request), populated with owner/repo from manifest.json.

The .head key is the branch the review comes from and .base the branch it
targets. The .assignees and .labels keys are struct arrays of usernames and
label names.

Usage: forge__new_create_review_options
PUB_FUN
forge__new_create_review_options() {
  @arr __forge__new_create_review_options__arr_1
  @arr __forge__new_create_review_options__arr_2
  @obj __forge__new_create_review_options__out \
    '.owner'     "$(manifest__get org)" \
    '.repo'      "$(manifest__get repo)" \
    '.title'     "" \
    '.head'      "" \
    '.base'      "main" \
    '.body'      "" \
    '.assignees' "$__forge__new_create_review_options__arr_1" \
    '.labels'    "$__forge__new_create_review_options__arr_2" \
    '.token'     ""
  println "$__forge__new_create_review_options__out"
}

:<<'PUB_FUN'
Default label options populated with owner/repo from manifest.json.

Usage: forge__new_label_options
PUB_FUN
forge__new_label_options() {
  @obj __forge__new_label_options__out \
    '.owner' "$(manifest__get org)" \
    '.repo'  "$(manifest__get repo)" \
    '.token' ""
  println "$__forge__new_label_options__out"
}

:<<'PUB_FUN'
Default org options for project discovery.

Usage: forge__new_org_options
PUB_FUN
forge__new_org_options() {
  @obj __forge__new_org_options__out \
    '.org'   "$(manifest__get org)" \
    '.token' ""
  println "$__forge__new_org_options__out"
}

:<<'PUB_FUN'
Default review-state options populated with owner/repo from manifest.json.

The .branch key scopes a lookup to one source branch and selects every open code
review when left empty. The .review_number and .reviewer keys name the code review
to hand back and the reviewer to hand it to. The .max_time and .retries keys cap
the request budget (see forge__base__with_budget).

Usage: forge__new_review_options
PUB_FUN
forge__new_review_options() {
  @obj __forge__new_review_options__out \
    '.owner'     "$(manifest__get org)" \
    '.repo'      "$(manifest__get repo)" \
    '.branch'    "" \
    '.review_number' "" \
    '.reviewer'  "" \
    '.max_time'  "" \
    '.retries'   "" \
    '.token'     ""
  println "$__forge__new_review_options__out"
}

:<<'PUB_FUN'
Desugars the @forge.<id> contract whose plugin file has been imported: its
inner roles become the flat <id>_<role> functions, through the interpreter's
forge binder. Does nothing when the adaptor's functions are already in the
process, so importing a plugin twice is harmless. Fails, saying which, when
the contract lacks a required role.

Usage: forge__load_contract gitlab
PUB_FUN
forge__load_contract() {
  if command -v "${1}_api_base" >/dev/null 2>&1; then
    return 0
  fi

  command -v interpreter__load_forge >/dev/null 2>&1 \
    || import "$SHELLOPS_DIR/interpreter/api.sh"
  interpreter__load_forge "$1" "@forge.$1"
}

:<<'PUB_FUN'
Default options for waiting on a forge's run of a commit, populated with
owner/repo from manifest.json.

The .forge key names the forge to ask, gitlab, forgejo or github, and selects
the active one when empty. The .host key is the server the repository is on.
A forge like GitLab CE can have many instances, each on its own host, and
.host names which one to ask; left empty, the forge is asked at its own base,
the instance this run is on. The .sha key is the commit. Three durations,
each in the seconds its name says: .timeout_seconds caps the wait,
.interval_seconds is the pause between two looks, and .grace_seconds is how
long a commit the forge holds may show no run before that is taken as the
answer, since a forge creates a run a moment after it receives the push and
a commit nothing triggers never gets one.

Usage: forge__new_run_options
PUB_FUN
forge__new_run_options() {
  @obj __forge__new_run_options__out \
    '.forge'    "" \
    '.host'     "" \
    '.owner'    "$(manifest__get org)" \
    '.repo'     "$(manifest__get repo)" \
    '.sha'      "" \
    '.timeout_seconds'  1800 \
    '.interval_seconds' 15 \
    '.grace_seconds'    120 \
    '.token'    ""
  println "$__forge__new_run_options__out"
}

:<<'PUB_FUN'
Default options for recording another forge's run as a commit status,
populated with owner/repo from manifest.json.

The .forge key names the forge the status is recorded on, and selects the
active one when empty -- the status lands where the commit is read, which is
not the forge that ran it. The .sha key is the commit, .name is what the
status is called beside it, .state is "success", "failure" or "none", .url
is the run's page, and .description is the sentence a reader sees under the
name.

Usage: forge__new_commit_status_options
PUB_FUN
forge__new_commit_status_options() {
  @obj __forge__new_commit_status_options__out \
    '.forge'       "" \
    '.owner'       "$(manifest__get org)" \
    '.repo'        "$(manifest__get repo)" \
    '.sha'         "" \
    '.name'        "" \
    '.state'       "" \
    '.url'         "" \
    '.description' "" \
    '.token'       ""
  println "$__forge__new_commit_status_options__out"
}

:<<'PUB_FUN'
Prints how many looks a wait of $1 seconds allows at one look every $2
seconds, rounded up and never fewer than one.

  forge__base__polls 100 15  ->  7
PUB_FUN
forge__base__polls() {
  __forge__base__polls__count=$(( ($1 + $2 - 1) / $2 ))
  if [ "$__forge__base__polls__count" -lt 1 ]; then
    __forge__base__polls__count=1
  fi

  println "$__forge__base__polls__count"
}

:<<'PUB_FUN'
Prints the Authorization header value for scheme $1 and token $2, and nothing
when there is no token, so a request carries no header rather than an empty
credential.

  forge__base__auth_header Bearer abc  ->  Bearer abc
  forge__base__auth_header Bearer ""   ->  (nothing)
PUB_FUN
forge__base__auth_header() {
  if @defined "$2"; then
    printf '%s %s\n' "$1" "$2"
  fi
}

:<<'FUN'
Prints the word a backend spells the run outcome $1 with, given $2, its own
words for the outcomes the forges disagree on, keyed by the forge__OUTCOME
word: .failure for a run that failed, and .none for a commit the forge ran
nothing on. A run that passed is "success" on every backend. An outcome that
is none of the three is refused naming it: only an outcome a run reached
has a word to record.

  __forge__base__commit_status_word none "$(@obj '.failure' failed '.none' skipped)"  ->  skipped
FUN
__forge__base__commit_status_word() {
  @set __forge__base__commit_status_word__spellings "$2" ".$forge__OUTCOME_SUCCESS" "$forge__OUTCOME_SUCCESS"
  @get __forge__base__commit_status_word__word "$__forge__base__commit_status_word__spellings" ".$1" ''

  if ! @defined "$__forge__base__commit_status_word__word"; then
    error "A commit status records an outcome a run reached, not one that is '$1'."
    return 1
  fi

  println "$__forge__base__commit_status_word__word"
}

:<<'PUB_FUN'
Assembles the body an adaptor posts to record a commit status: the options
$1, the words $2 its backend spells the outcomes with (the table
__forge__base__commit_status_word reads), and the key $3 that backend names a
status under. A link or a sentence the caller left out is left out, so a
status carries neither empty.

  forge__base__commit_status_body "$options" "$(@obj '.failure' failed '.none' skipped)" '.name'
  ->  {"state":"failed","name":"forgejo/site","target_url":"https://forgejo/runs/469"}
PUB_FUN
forge__base__commit_status_body() {
  @get __forge__base__commit_status_body__state "$1" '.state' ''
  __forge__base__commit_status_body__word="$(
    __forge__base__commit_status_word "$__forge__base__commit_status_body__state" "$2"
  )" || return 1
  @obj __forge__base__commit_status_body__out '.state' "$__forge__base__commit_status_body__word"

  @get __forge__base__commit_status_body__get_3 "$1" '.name' ''
  @get __forge__base__commit_status_body__get_4 "$1" '.url' ''
  @get __forge__base__commit_status_body__get_5 "$1" '.description' ''
  @patch __forge__base__commit_status_body__out "$__forge__base__commit_status_body__out" \
    "$3"           "$__forge__base__commit_status_body__get_3" \
    '.target_url'  "$__forge__base__commit_status_body__get_4" \
    '.description' "$__forge__base__commit_status_body__get_5"
  println "$__forge__base__commit_status_body__out"
}

:<<'PUB_FUN'
Prints the {carried: false, state: "", url: ""} answer every adaptor's
<forge>_run_status gives while the forge does not hold the commit.

Usage: forge__base__not_carried
PUB_FUN
forge__base__not_carried() {
  @false __forge__base__not_carried__false_6
  @obj __forge__base__not_carried__out \
    '.carried' "$__forge__base__not_carried__false_6" \
    '.state'   "" \
    '.url'     ""
  println "$__forge__base__not_carried__out"
}

:<<'PUB_FUN'
Prints the options $1 as an error message shows them: as JSON, without the
token.

  forge__base__options_without_token '{"owner":"o","token":"s"}'  ->  {"owner": "o"}

Usage: forge__base__options_without_token "$options"
PUB_FUN
forge__base__options_without_token() {
  @without __forge__base__options_without_token__shown "$1" token
  @dump __forge__base__options_without_token__out "$__forge__base__options_without_token__shown"
  println "$__forge__base__options_without_token__out"
}

:<<'PUB_FUN'
A predicate for @filter: answers true in the variable $1 when the member $3
has a value, and false when it is a null or the empty string. A request
body that is filtered by it leaves out the fields the caller did not give,
so an edit never blanks one of them.

  @filter body "$fields" forge__base__member_is_set

args:
  $1  The name of the variable to answer in
  $2  The member's key
  $3  The member's value
PUB_FUN
forge__base__member_is_set() {
  @get __forge__base__member_is_set__text "$3" . ''
  if [ -n "$__forge__base__member_is_set__text" ]; then
    @true "$1"
  else
    @false "$1"
  fi
}

:<<'PUB_FUN'
Fetches $1 with http options $2 for an adaptor's <forge>_run_status and
prints the body. A 404 or 422 prints nothing and succeeds: the forges answer
those for a commit they do not hold, and that absence is the answer, not a
failure. Any other refusal fails with the request's own message.

The status is read after the request rather than inside a substitution of
it, since a substitution runs in a subshell and the status would die there.

Usage: forge__base__probe "$url" "$http_opts"
PUB_FUN
forge__base__probe() {
  __forge__base__probe__out="$(mktemp)"
  __forge__base__probe__err="$(mktemp)"
  if http__get "$1" "$2" \
    > "$__forge__base__probe__out" \
    2> "$__forge__base__probe__err"
  then
    cat "$__forge__base__probe__out"
    rm -f "$__forge__base__probe__out" "$__forge__base__probe__err"
    return 0
  fi

  __forge__base__probe__status="$(http__last_status)"
  __forge__base__probe__stderr="$(cat "$__forge__base__probe__err")"
  rm -f "$__forge__base__probe__out" "$__forge__base__probe__err"
  case "$__forge__base__probe__status" in
    404|422) return 0 ;;
  esac

  println "$__forge__base__probe__stderr" >&2
  return 1
}
