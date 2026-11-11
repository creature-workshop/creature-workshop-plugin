#!/bin/sh

:<<'MODULE'
Forge facade -- the top of the forge "sandwich":

  lib/forge/api.sh        facade  -- forge_* dispatchers + selector (here)
  lib/{forgejo,gitlab}/   adaptor -- <forge>_* implementations
  lib/forge/base.sh       base    -- shared contract + option shapes

A registry of named adaptors with a selection and verb dispatch (ADRs 000003
to 000005). The facade imports the common base and no adaptor: an adaptor is
loaded the first time a call reaches it, so every forge shellops knows is
addressable from one process. Downstream callers never name a backend unless
they mean to:

  - forge_new_*_options (from the base): release / upload / review /
    label / org / run option constructors.
  - forge_<op> (defined below): each dispatches to <forge>_<op> on the
    adaptor the call selects.
  - composites (defined below, after the dispatchers): assembled from the
    forge_<op> dispatchers rather than forwarded, so each has one definition
    that reads the same on every forge. They live here rather than in a
    caller because "the text of a code review" and "the words a comment's
    author wrote" are forge concepts, wanted by everything that reads
    author-written text.

Which adaptor a call reaches has two sources, in order: the .forge key of an
options struct passed as the call's first argument names one for that call, a
promotion on one forge asking another about the same commit; otherwise
SHELLOPS_FORGE names the forge the run is on, gitlab when unset. A call whose
first argument is not a struct, a username or a commit message, always takes
the environment's forge.

Adaptors: gitlab, forgejo, and github. GitHub is not a forge a run is on, so
it is never the environment's selection; it is asked by name, and answers the
ops it implements (releases, uploads, runs). A call for an op it lacks fails
naming the op.

Usage:
  source "$SHELLOPS_DIR/.envrc"
  import "$SHELLOPS_DIR/lib/forge/api.sh"

  options="$(@set "$(forge__new_release_options)" '.tag_name' "v1.2.3" ...)"
  forge__create_release "$options"
MODULE

import \
  "$SHELLOPS_DIR/lib/fingerprint/api.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/markdown/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'CONST'
The backend a run talks to when SHELLOPS_FORGE names none. Named once so the
fingerprint declaration below reports the default this module actually applies
rather than a copy of it that can drift.
CONST
__forge__DEFAULT_FORGE="gitlab"

:<<'PUB_FUN'
Returns the currently selected forge: "gitlab" or "forgejo".

Reads SHELLOPS_FORGE, defaulting to "gitlab". The value is lowercased so
callers can set it loosely (FORGEJO, GitLab, ...).

Usage: forge__selected
PUB_FUN
forge__selected() {
  println "${SHELLOPS_FORGE:-$__forge__DEFAULT_FORGE}" \
    | tr '[:upper:]' '[:lower:]'
}

:<<'PUB_FUN'
Prints the struct boolean for whether the selected forge is <name>.

Usage:
  if @is_true "$(forge__is gitlab)"; then ... fi
PUB_FUN
forge__is() {
  @succeeds __forge__is__out [ "$(forge__selected)" = "$1" ]
  println "$__forge__is__out"
}

:<<'PUB_FUN'
Returns the canonical name of the env var holding the API admin token
for the selected forge. CLIs use this to print a helpful error when the
token is missing.

The name (FORGE_ADMIN_TOKEN) is stable regardless of which forge is active
-- only the secret value behind it differs per environment, so workflow
YAMLs wire one name.

Usage: forge__token_env_name
PUB_FUN
forge__token_env_name() {
  println "FORGE_ADMIN_TOKEN"
}

:<<'PUB_FUN'
Returns the env var holding the bot token used for code-review-context
operations. The name (FORGE_PR_TOKEN) is stable regardless of which forge
is active; only the secret value differs per environment.

Usage: forge__pr_token_env_name
PUB_FUN
forge__pr_token_env_name() {
  println "FORGE_PR_TOKEN"
}

:<<'PUB_FUN'
The API token to authenticate with: FORGE_PR_TOKEN, then FORGE_ADMIN_TOKEN.
Prints nothing when neither is set, leaving the caller to decide whether that
is fatal.

Usage: forge__resolve_token
PUB_FUN
forge__resolve_token() {
  if [ -n "${FORGE_PR_TOKEN:-}" ]; then
    println "$FORGE_PR_TOKEN"
    return 0
  fi

  println "${FORGE_ADMIN_TOKEN:-}"
}

:<<'PUB_FUN'
The API token to authenticate with, failing with the names that would supply one
when there is none. For a caller that cannot do its work unauthenticated.

Usage: forge__require_token
PUB_FUN
forge__require_token() {
  __forge__require_token__token="$(forge__resolve_token)"
  if ! @defined "$__forge__require_token__token"; then
    error "No forge token. Set $(forge__pr_token_env_name) or $(forge__token_env_name)."
    return 1
  fi

  println "$__forge__require_token__token"
}

# Nothing reaches the forge without these three: which forge is being talked
# to, and the two tokens for talking to it.
fingerprint__input "SHELLOPS_FORGE=$__forge__DEFAULT_FORGE"
fingerprint__secret "$(forge__token_env_name)"
fingerprint__secret "$(forge__pr_token_env_name)"

import "$SHELLOPS_DIR/lib/forge/base.sh"

@arr __forge__adaptor_ids gitlab forgejo github

: <<'CONST'
The adaptors shellops ships, by the name a call selects one with; each lives
under lib/<name>/, entered through its api.sh, and defines the <name>_<op>
functions once its contract has loaded.
CONST
__forge__ADAPTOR_IDS="$__forge__adaptor_ids"

: <<'CONST'
The directory the adaptors are loaded from, fixed at load so a caller that
points SHELLOPS_DIR elsewhere afterwards still gets the adaptors this facade came with.
CONST
__forge__LIB="$SHELLOPS_DIR/lib"

:<<'PUB_FUN'
Prints the registered adaptor names, one per line.

Usage: forge__adaptor_ids
PUB_FUN
forge__adaptor_ids() {
  @foreach __forge__print_id "$__forge__ADAPTOR_IDS"
}

__forge__print_id() {
  @unwrap __forge__print_id__out "$1"
  println "$__forge__print_id__out"
}

__forge__id_eq() {
  @unwrap __forge__id_eq__unwrap_1 "$1"
  [ "$__forge__id_eq__unwrap_1" = "$2" ]
}

:<<'PUB_FUN'
Prints true when $1 names a registered adaptor, false otherwise.

Usage: forge__adaptor_registered gitlab
PUB_FUN
forge__adaptor_registered() {
  @find __forge__adaptor_registered__find_2 __forge__id_eq "$__forge__ADAPTOR_IDS" "$1"
  @succeeds __forge__adaptor_registered__out @defined "$__forge__adaptor_registered__find_2"
  println "$__forge__adaptor_registered__out"
}

:<<'PUB_FUN'
Prints true when adaptor $1's functions are in the process, whoever put them
there: this loader, or a caller that imported the adaptor's file itself. Every
adaptor defines <name>_api_base, and nothing else redefines it, so it is the
mark.

Usage: forge__adaptor_loaded gitlab
PUB_FUN
forge__adaptor_loaded() {
  @succeeds __forge__adaptor_loaded__out @defined "$(command -v "${1}_api_base" 2>/dev/null)"
  println "$__forge__adaptor_loaded__out"
}

:<<'PUB_FUN'
Brings adaptor $1's functions into the process, once. A name the registry
does not hold fails listing the names it does.

Usage: forge__load_adaptor forgejo
PUB_FUN
forge__load_adaptor() {
  if ! @is_true "$(forge__adaptor_registered "$1")"; then
    error "Unknown forge '$1'. Registered: $(forge__adaptor_ids | paste -sd ',' - | sed 's/,/, /g')."
    return 1
  fi
  if @is_true "$(forge__adaptor_loaded "$1")"; then
    return 0
  fi

  import "$__forge__LIB/$1/api.sh"
}

:<<'FUN'
Prints the forge a call reaches: the .forge key of an options struct $1, or
the environment's forge when $1 is not a struct or names none.

  __forge__forge_of '{"forge":"github"}'  ->  github
  __forge__forge_of 'fix: closes !12'     ->  gitlab (SHELLOPS_FORGE unset)
FUN
__forge__forge_of() {
  __forge__forge_of__named="$(__forge__forge_of__named_in "$1")"
  if @defined "$__forge__forge_of__named"; then
    println "$__forge__forge_of__named" | tr '[:upper:]' '[:lower:]'
    return 0
  fi

  forge__selected
}

:<<'FUN'
Prints the forge the options $1 name, and nothing when $1 is text rather
than a struct, or a struct that names no forge.
FUN
__forge__forge_of__named_in() {
  if @typeof __forge__forge_of__named_in__typeof_3 "$1" 2>/dev/null; [ "$__forge__forge_of__named_in__typeof_3" = object ]; then
    @get __forge__forge_of__named_in__out "$1" '.forge' ''
    println "$__forge__forge_of__named_in__out"
  fi
}

:<<'FUN'
Runs op $1 on the adaptor the remaining arguments select, loading it first
when its functions are not yet in the process. An adaptor that has no
<forge>_<op> fails naming the op, so a call for what a forge cannot do is a
clear refusal rather than a missing command.

Usage: __forge__dispatch get_review "$options"
FUN
__forge__dispatch() {
  __forge__dispatch__op="$1"
  shift
  __forge__dispatch__forge="$(__forge__forge_of "${1:-}")"
  __forge__dispatch__fn="${__forge__dispatch__forge}_${__forge__dispatch__op}"

  if ! command -v "$__forge__dispatch__fn" >/dev/null 2>&1; then
    forge__load_adaptor "$__forge__dispatch__forge" || return 1
  fi
  if ! command -v "$__forge__dispatch__fn" >/dev/null 2>&1; then
    error "The $__forge__dispatch__forge adaptor does not implement $__forge__dispatch__op."
    return 1
  fi

  "$__forge__dispatch__fn" "$@"
}

# inline-comment-check: allow -- one note over a table of one-line dispatchers, not a doc on the first
: <<'PUB_FUN'
forge_<op> dispatches to <forge>_<op> on the adaptor the call selects.
PUB_FUN
forge__api_base()            { __forge__dispatch api_base "$@"; }
forge__token_env()           { __forge__dispatch token_env "$@"; }
forge__create_release()      { __forge__dispatch create_release "$@"; }
forge__upload_artifact()     { __forge__dispatch upload_artifact "$@"; }
forge__get_review()          { __forge__dispatch get_review "$@"; }
forge__create_review()       { __forge__dispatch create_review "$@"; }
forge__update_review()       { __forge__dispatch update_review "$@"; }
forge__list_comments()       { __forge__dispatch list_comments "$@"; }
forge__create_comment()      { __forge__dispatch create_comment "$@"; }
forge__list_review_comments()    { __forge__dispatch list_review_comments "$@"; }
forge__list_review_thread_comments() { __forge__dispatch list_review_thread_comments "$@"; }
forge__create_review_comment()   { __forge__dispatch create_review_comment "$@"; }
forge__update_review_comment()   { __forge__dispatch update_review_comment "$@"; }
forge__delete_review_comment()   { __forge__dispatch delete_review_comment "$@"; }
forge__list_labels()         { __forge__dispatch list_labels "$@"; }
forge__create_label()        { __forge__dispatch create_label "$@"; }
forge__edit_label()          { __forge__dispatch edit_label "$@"; }
forge__list_org_repos()      { __forge__dispatch list_org_repos "$@"; }
forge__get_raw_file()        { __forge__dispatch get_raw_file "$@"; }
forge__run_status()          { __forge__dispatch run_status "$@"; }
forge__create_commit_status() { __forge__dispatch create_commit_status "$@"; }
forge__current_user()        { __forge__dispatch current_user "$@"; }

forge__merged_reviews_since() { __forge__dispatch merged_reviews_since "$@"; }
forge__default_branch()       { __forge__dispatch default_branch "$@"; }
forge__code_review_refs()     { __forge__dispatch code_review_refs "$@"; }
# shellcheck disable=SC2120  # forwarded "$@" is the dispatcher shape; forge__review_in_context calls it bare
forge__current_review()       { __forge__dispatch current_review "$@"; }
forge__review_labels()        { __forge__dispatch review_labels "$@"; }
forge__reconcile_review_labels() { __forge__dispatch reconcile_review_labels "$@"; }
forge__comment_is_reply()     { __forge__dispatch comment_is_reply "$@"; }
forge__pushed_range()         { __forge__dispatch pushed_range "$@"; }
forge__request_review()       { __forge__dispatch request_review "$@"; }
forge__reviews_awaiting_author() { __forge__dispatch reviews_awaiting_author "$@"; }
forge__mention()              { __forge__dispatch mention "$@"; }
forge__review_ref()           { __forge__dispatch review_ref "$@"; }
forge__review_from_url()      { __forge__dispatch review_from_url "$@"; }
forge__repository()           { __forge__dispatch repository "$@"; }
forge__review_commit_range()         { __forge__dispatch review_commit_range "$@"; }
forge__review_for_branch()    { __forge__dispatch review_for_branch "$@"; }
forge__review_pipeline()      { __forge__dispatch review_pipeline "$@"; }
forge__download_job_artifacts() { __forge__dispatch download_job_artifacts "$@"; }
forge__no_run_push_options()  { __forge__dispatch no_run_push_options "$@"; }
forge__current_run()          { __forge__dispatch current_run "$@"; }
forge__branch_head()          { __forge__dispatch branch_head "$@"; }
forge__running_runs()         { __forge__dispatch running_runs "$@"; }
forge__cancel_run()           { __forge__dispatch cancel_run "$@"; }
forge__open_reviews()         { __forge__dispatch open_reviews "$@"; }
forge__review_approval()      { __forge__dispatch review_approval "$@"; }
forge__landing_run()          { __forge__dispatch landing_run "$@"; }
forge__start_landing_run()    { __forge__dispatch start_landing_run "$@"; }
forge__merge_review()         { __forge__dispatch merge_review "$@"; }
forge__landing_at()           { __forge__dispatch landing_at "$@"; }

:<<'PUB_FUN'
Downloads the artifacts archive job $2 kept and unpacks it into directory $3,
over whatever earlier archives left there; unzip is what opens it.

  $1 forge options   $2 job id   $3 directory
PUB_FUN
forge__unpack_job_artifacts() {
  __forge__unpack_job_artifacts__zip="$3/$2.zip"
  @set __forge__unpack_job_artifacts__set_4 "$1" '.job_id' "$2"
  forge__download_job_artifacts "$__forge__unpack_job_artifacts__set_4" "$__forge__unpack_job_artifacts__zip" || return 1
  unzip -q -o "$__forge__unpack_job_artifacts__zip" -d "$3" || return 1
  rm -f "$__forge__unpack_job_artifacts__zip"
}

:<<'PUB_FUN'
Returns the name of the env var holding the token to ask forge $1 with. A run
is on one forge and may ask another about the same commit, so the name depends
on which forge is being addressed: the forge the run is on answers to
FORGE_ADMIN_TOKEN, one name every workflow wires whichever forge it is on, and
a forge asked by name answers to the name its own adaptor declares.

  forge__token_env_for github   ->  GITHUB_TOKEN
  forge__token_env_for gitlab   ->  FORGE_ADMIN_TOKEN  (with SHELLOPS_FORGE=gitlab)
  forge__token_env_for forgejo  ->  FORGEJO_TOKEN      (with SHELLOPS_FORGE=gitlab)

Usage: forge__token_env_for github
PUB_FUN
forge__token_env_for() {
  if [ "$1" = "$(forge__selected)" ]; then
    forge__token_env_name
    return 0
  fi

  @obj __forge__token_env_for__obj_5 '.forge' "$1"
  forge__token_env "$__forge__token_env_for__obj_5"
}

:<<'PUB_FUN'
Returns the token to ask forge $1 with, read from the env var $2 names or,
when $2 is empty, from the one forge__token_env_for gives. Returns nothing,
noting which name was empty, when that variable is unset: a public repository
answers unauthenticated, so the caller decides whether that is fatal.

Usage: forge__token_for github "$ARG_TOKEN_ENV"
PUB_FUN
forge__token_for() {
  __forge__token_for__env="$2"
  if ! @defined "$__forge__token_for__env"; then
    __forge__token_for__env="$(forge__token_env_for "$1")"
  fi

  __forge__token_for__token="$(eval "printf '%s' \"\${$__forge__token_for__env:-}\"")"
  if ! @defined "$__forge__token_for__token"; then
    log "$__forge__token_for__env is unset; asking $1 unauthenticated"
  fi

  println "$__forge__token_for__token"
}

:<<'PUB_FUN'
Prints the URL of the page a reader opens code review $1 at. A review the
forge returned carries it, under whichever key the backend spells it. An
object {owner, repo, review_number} has it built by the adaptor, the inverse
of forge__review_from_url. Prints nothing when $1 carries neither.

  forge__review_url '{"iid": 7, "webUrl": "https://gl/-/merge_requests/7"}'  ->  https://gl/-/merge_requests/7
  forge__review_url '{"owner": "org", "repo": "tool", "review_number": 7}'   ->  https://gl.example/org/tool/-/merge_requests/7 on a GitLab at gl.example

Usage: forge__review_url "$review"
PUB_FUN
forge__review_url() {
  @get __forge__review_url__given "$1" '.webUrl' '.html_url' '.url' ''
  if @defined "$__forge__review_url__given"; then
    println "$__forge__review_url__given"
  else
    __forge__dispatch review_url "$1"
  fi
}

:<<'PUB_FUN'
Prints the state the code review $1 is in, as one of the forge__REVIEW_STATE
words, whatever fields the backend uses. A review is merged when its state
says merged or its merged flag is true. It is open when its state is open,
opened or locked, which is GitLab's word for a merge in progress. Any other
state is closed. Prints nothing when the review has no state field.

  forge__review_state '{"state": "opened"}'                  ->  open
  forge__review_state '{"state": "closed", "merged": true}'  ->  merged

Usage: forge__review_state "$review"
PUB_FUN
forge__review_state() {
  @get __forge__review_state__state "$1" '.state' ''
  @get __forge__review_state__merged "$1" '.merged' ''
  if [ "$__forge__review_state__state" = "$forge__REVIEW_STATE_MERGED" ] \
    || @is_true "$__forge__review_state__merged"; then
    println "$forge__REVIEW_STATE_MERGED"
    return 0
  fi

  case "$__forge__review_state__state" in
    "") return 0 ;;
    open|opened|locked) println "$forge__REVIEW_STATE_OPEN" ;;
    *) println "$forge__REVIEW_STATE_CLOSED" ;;
  esac
}

:<<'PUB_FUN'
Prints a code review's title and body, one per line.

A review that cannot be read prints nothing rather than failing. A commit can
name a code review that has since been deleted, or one on a host the token
cannot reach, and that is a gap in what is legible rather than a broken run.

Usage: forge__code_review_description "$options" "$number"
PUB_FUN
forge__code_review_description() {
  @set __forge__code_review_description__options "$1" '.review_number' "$2"
  __forge__code_review_description__review="$(
    forge__get_review "$__forge__code_review_description__options" 2>/dev/null
  )" || true

  @defined "$__forge__code_review_description__review" || return 0

  @let "$__forge__code_review_description__review" __forge__code_review_description__ title body
  println "$__forge__code_review_description__title"
  println "$__forge__code_review_description__body"
  @unlet __forge__code_review_description__ title body
}

:<<'PUB_FUN'
Prints a code review's comments, as a struct array of comment objects.

Whole objects rather than bodies, because a body is not all a reader needs:
forge__comment_authored_body has to ask the backend whether the comment is a
reply, which only the object can answer.

A review that cannot be read prints an empty array, for the reason given in
forge__code_review_description.

Usage: forge__code_review_comments "$options" "$number"
PUB_FUN
forge__code_review_comments() {
  @set __forge__code_review_comments__options "$1" '.review_number' "$2"
  __forge__code_review_comments__comments="$(
    forge__list_review_comments "$__forge__code_review_comments__options" 2>/dev/null
  )" || true

  @defined "$__forge__code_review_comments__comments" || { @arr __forge__code_review_comments__out; println "$__forge__code_review_comments__out"; return 0; }

  println "$__forge__code_review_comments__comments"
}

:<<'PUB_FUN'
Prints the comments in the threads on a code review's diff, as a struct array
of comment objects, each anchored to the line it is about.

Kept apart from forge__code_review_comments rather than folded in, because a
reader weighs the two differently: a bare identifier at the top of a review
answers what the change closes, while the same identifier on a line points at
an issue the line relates to.

A review that cannot be read prints an empty array, for the reason given in
forge__code_review_description.

Usage: forge__code_review_thread_comments "$options" "$number"
PUB_FUN
forge__code_review_thread_comments() {
  @set __forge__code_review_thread_comments__options "$1" '.review_number' "$2"
  __forge__code_review_thread_comments__comments="$(
    forge__list_review_thread_comments "$__forge__code_review_thread_comments__options" 2>/dev/null
  )" || true

  @defined "$__forge__code_review_thread_comments__comments" || { @arr __forge__code_review_thread_comments__out; println "$__forge__code_review_thread_comments__out"; return 0; }

  println "$__forge__code_review_thread_comments__comments"
}

:<<'PUB_FUN'
Prints the words a comment's author actually wrote, dropping the quotation a
reply opens with: those are the words of whoever wrote them first, and
crediting them to the replier misleads anything reading a comment for what it
declares.

Whether a comment is a reply is the forge's question; what a quotation looks
like is markdown's, and identical everywhere. Outside a reply the quotation is
deliberate, so it stays.

Usage: forge__comment_authored_body "$comment"
PUB_FUN
forge__comment_authored_body() {
  @get __forge__comment_authored_body__body "$1" '.body' ''

  if [ "$(forge__comment_is_reply "$1")" = true ]; then
    println "$__forge__comment_authored_body__body" | markdown__strip_leading_quote
    return 0
  fi

  println "$__forge__comment_authored_body__body"
}

:<<'PUB_FUN'
Prints the number of the code review this run is for: the one the environment
already carries, or else the one the forge reports for this pipeline. Nothing
outside a code-review pipeline.

Usage: forge__review_in_context
PUB_FUN
forge__review_in_context() {
  __forge__review_in_context__given="${CI_COMMIT_PULL_REQUEST:-}"
  if @defined "$__forge__review_in_context__given"; then
    println "$__forge__review_in_context__given"
    return 0
  fi

  # shellcheck disable=SC2119  # the dispatcher forwards "$@"; there is nothing to pass
  forge__current_review
}

:<<'PUB_FUN'
Prints the token an action comments and labels with: the review bot's, falling
back to the admin token where no bot identity is configured. Nothing when
neither is set.

Usage: forge__comment_token
PUB_FUN
forge__comment_token() {
  println "${FORGE_PR_TOKEN:-${FORGE_ADMIN_TOKEN:-}}"
}

:<<'PUB_FUN'
Hands every code review awaiting its author back to the reviewers who asked for
changes, then prints the records it acted on -- shaped as
forge__reviews_awaiting_author returns them -- so a caller can report what
happened without repeating the lookup.

Usage: forge__hand_back_reviews "$review_options"
PUB_FUN
forge__hand_back_reviews() {
  __forge__hand_back_reviews__found="$(forge__reviews_awaiting_author "$1")" || return 1

  @foreach __forge__hand_back_review "$__forge__hand_back_reviews__found" "$1" || return 1

  println "$__forge__hand_back_reviews__found"
}

:<<'FUN'
Hands one code review back to each reviewer waiting on it. @foreach hands the
review over as JSON, ready to read.

Usage: __forge__hand_back_review "$review" "$options"
FUN
__forge__hand_back_review() {
  @get __forge__hand_back_review__get_6 "$1" '.reviewers'
  @foreach __forge__request_review_from "$__forge__hand_back_review__get_6" "$1" "$2"
}

:<<'FUN'
Requests review on one code review from one reviewer. @foreach hands the
username over still JSON-encoded, so it is unwrapped before it is used.

Usage: __forge__request_review_from '"jerrod"' "$review" "$options"
FUN
__forge__request_review_from() {
  @get __forge__request_review_from__get_7 "$2" '.iid'
  @unwrap __forge__request_review_from__unwrap_8 "$1"
  @set __forge__request_review_from__options "$3" \
    '.review_number' "$__forge__request_review_from__get_7" \
    '.reviewer'  "$__forge__request_review_from__unwrap_8"

  forge__request_review "$__forge__request_review_from__options" >/dev/null
}

:<<'PUB_FUN'
Waits until the forge the options name has finished running the commit .sha,
and prints the outcome as {state, url}: .state is a forge__OUTCOME word,
"none" when the forge ran nothing on it. A forge that does not hold the commit yet has
not finished running it, so a mirror's delay is inside the wait like a
queued run is. The wait is bounded by .timeout_seconds; running out fails the call
and says how far the forge had got.

Usage: outcome="$(forge__wait_for_run "$run_options")"
PUB_FUN
forge__wait_for_run() {
  __forge__wait_for_run__forge="$(__forge__forge_of "$1")"
  @let "$1" __forge__wait_for_run__ sha timeout_seconds interval_seconds grace_seconds
  @defined "$__forge__wait_for_run__timeout_seconds" || __forge__wait_for_run__timeout_seconds=1800
  @defined "$__forge__wait_for_run__interval_seconds" || __forge__wait_for_run__interval_seconds=15
  @defined "$__forge__wait_for_run__grace_seconds" || __forge__wait_for_run__grace_seconds=120
  __forge__wait_for_run__polls="$(forge__base__polls "$__forge__wait_for_run__timeout_seconds" "$__forge__wait_for_run__interval_seconds")"
  __forge__wait_for_run__grace_seconds="$(forge__base__polls "$__forge__wait_for_run__grace_seconds" "$__forge__wait_for_run__interval_seconds")"
  __forge__wait_for_run__poll=0
  __forge__wait_for_run__since_carried=0

  while :; do
    __forge__wait_for_run__status="$(forge__run_status "$1")" || return 1
    __forge__wait_for_run__poll=$(( __forge__wait_for_run__poll + 1 ))
    @let "$__forge__wait_for_run__status" __forge__wait_for_run__ carried state url

    if @is_true "$__forge__wait_for_run__carried"; then
      __forge__wait_for_run__since_carried=$(( __forge__wait_for_run__since_carried + 1 ))
      if @is_true "$(__forge__run_settled "$__forge__wait_for_run__state" "$__forge__wait_for_run__since_carried" "$__forge__wait_for_run__grace_seconds")"; then
        @obj __forge__wait_for_run__out \
          '.state' "$__forge__wait_for_run__state" \
          '.url'   "$__forge__wait_for_run__url"
        println "$__forge__wait_for_run__out"
        @unlet __forge__wait_for_run__ sha timeout_seconds interval_seconds grace_seconds
        @unlet __forge__wait_for_run__ carried state url
        return 0
      fi
    fi

    if [ "$__forge__wait_for_run__poll" -ge "$__forge__wait_for_run__polls" ]; then
      error "Timed out after ${__forge__wait_for_run__timeout_seconds}s waiting for $__forge__wait_for_run__forge to finish its run on $__forge__wait_for_run__sha: $(__forge__how_far "$__forge__wait_for_run__status")"
      return 1
    fi

    sleep "$__forge__wait_for_run__interval_seconds"
  done
}

:<<'FUN'
Prints how far a forge had got with a commit when the wait ran out, from the
last answer $1 its <forge>_run_status gave.

Usage: __forge__how_far "$status"
FUN
__forge__how_far() {
  @let "$1" __forge__how_far__ carried state

  if ! @is_true "$__forge__how_far__carried"; then
    printf 'it does not hold the commit\n'
    return 0
  fi

  case "$__forge__how_far__state" in
    "$forge__OUTCOME_NONE") printf 'it shows no run\n' ;;
    *)                      printf 'its run has not finished\n' ;;
  esac
  @unlet __forge__how_far__ carried state
}

:<<'FUN'
Prints true when a carried commit's run state $1 is the answer, false while
it is still worth another look: a pending run is never settled, a passed or
failed one always is, and no run at all is settled only after $2 looks have
reached the grace of $3, since a forge takes a moment to create a run.

Usage: __forge__run_settled "$state" "$looks_since_carried" "$grace_looks"
FUN
__forge__run_settled() {
  case "$1" in
    "$forge__OUTCOME_SUCCESS"|"$forge__OUTCOME_FAILURE") @true __forge__run_settled__out; println "$__forge__run_settled__out" ;;
    "$forge__OUTCOME_NONE")                             @succeeds __forge__run_settled__out [ "$2" -ge "$3" ]; println "$__forge__run_settled__out" ;;
    *)                                                  @false __forge__run_settled__out; println "$__forge__run_settled__out" ;;
  esac
}
