#!/bin/sh

:<<'MODULE'
Reconciles the area/* labels of a merge request with its diff.

The plan maps the review's changed files to the labels of the areas they
touch, through the resolver (testing__areas_for_paths) and the area model
(areas__compute_areas); area/* is a closed namespace owned by the diff, so
the plan adds the touched areas' labels and removes every other area label,
and leaves labels outside area/* alone. Before the plan is made, the apply
creates the label of a touched area the project does not define yet
(lib/labels/_establish.sh). labels__plan documents the area/new fallback.

Only the apply touches the network, through two seams a test can stub:
__labels__apply__fetch_established_labels reads the project's labels and
__labels__apply__send_request writes the reconcile to the merge request.

Usage:
  import "$SHELLOPS_DIR/lib/labels/apply.sh"

  plan="$(labels__plan "$changed" "$added" "$established_labels")"  # add/remove lists
  labels__apply "$changed" "$added"                                # reconcile onto the MR
MODULE

import \
  "$SHELLOPS_DIR/lib/labels/_names.sh" \
  "$SHELLOPS_DIR/lib/labels/_establish.sh" \
  "$SHELLOPS_DIR/lib/testing/resolver.sh" \
  "$SHELLOPS_DIR/lib/areas/api.sh" \
  "$SHELLOPS_DIR/lib/fingerprint/api.sh" \
  "$SHELLOPS_DIR/lib/http/api.sh"

# The write token, as the chain labels__apply falls back through. A CI_JOB_TOKEN
# usually lacks the scope to edit labels, so which name the value came from is
# the difference between a misconfigured job and a rejected one.
fingerprint__secret GITLAB_TOKEN FORGE_PR_TOKEN CI_JOB_TOKEN

: <<'CONST'
The reserved, always-defined fall-back label, so an undefined precise label
never silently drops a touched area from the selection.
CONST
__labels__apply__NEW_LABEL="area/new"

:<<'PUB_FUN'
The full area/* label universe for an areas object: every defined area mapped to
its label, plus the reserved area/new. This is the set the reconcile is allowed
to remove from, so area/new is dropped when no longer due.

  areas  the manifest `areas` object (area name -> {paths, ...})

Usage: labels__universe "$areas"
PUB_FUN
labels__universe() {
  @keys __labels__universe__keys_1 "$1"
  @push __labels__universe__push_2 "$(labels__from_areas "$__labels__universe__keys_1")" "$__labels__apply__NEW_LABEL"
  @unique __labels__universe__out "$__labels__universe__push_2"
  println "$__labels__universe__out"
}

:<<'PUB_FUN'
The reconcile plan for a review: which area/* labels to add and which to remove
so the MR's labels match the diff.

  changed             [<file>, ...]  the review's changed files, repo-relative
  added               [<file>, ...]  the subset git reports as added
  established_labels  the area/* labels already defined on the project; a
                      computed label outside this set falls back to area/new

Returns the add and remove label lists; both empty when the repo declares no
areas, so applying the plan is a no-op. area/new is due when a touched area's
label is not yet established, or an added file maps to no area; an edited or
removed file under no area earns no label.

Usage: labels__plan "$changed" "$added" "$established_labels"
PUB_FUN
labels__plan() {
  __labels__plan__config="$(areas__load_areas_config)"
  if ! @defined "$__labels__plan__config"; then
    @arr __labels__plan__arr_3
    @arr __labels__plan__arr_4
    @obj __labels__plan__out '.add' "$__labels__plan__arr_3" '.remove' "$__labels__plan__arr_4"
    println "$__labels__plan__out"
    return 0
  fi

  __labels__plan__areas="$(areas__compute_areas "$__labels__plan__config")" || return 1
  __labels__plan__names="$(testing__areas_for_paths "$__labels__plan__areas" "$1")"
  __labels__plan__precise="$(labels__from_areas "$__labels__plan__names")"

  # Only labels the project already defines can be applied; the rest fall back to
  # area/new (GitLab drops add_labels for undefined labels).
  @intersect __labels__plan__established "$__labels__plan__precise" "$3"
  @difference __labels__plan__unestablished "$__labels__plan__precise" "$3"

  # Only an added unmapped file earns area/new; an edited or removed one is drift
  # and earns no label.
  __labels__plan__unmapped="$(testing__unmapped_for_paths "$__labels__plan__areas" "$1")"
  @intersect __labels__plan__unmapped_added "$__labels__plan__unmapped" "$2"

  __labels__plan__add="$__labels__plan__established"
  if @len __labels__plan__len_5 "$__labels__plan__unestablished"; @len __labels__plan__len_6 "$__labels__plan__unmapped_added"; [ "$__labels__plan__len_5" -gt 0 ] || [ "$__labels__plan__len_6" -gt 0 ]; then
    @push __labels__plan__push_7 "$__labels__plan__established" "$__labels__apply__NEW_LABEL"
    @unique __labels__plan__add "$__labels__plan__push_7"
  fi

  __labels__plan__universe="$(labels__universe "$__labels__plan__areas")"
  @difference __labels__plan__remove "$__labels__plan__universe" "$__labels__plan__add"

  @obj __labels__plan__out \
    '.add' "$__labels__plan__add" \
    '.remove' "$__labels__plan__remove"
  println "$__labels__plan__out"
}

:<<'PUB_FUN'
Reconciles the area/* labels for a review onto the current merge request via the
GitLab API.

  changed  [<file>, ...]  the review's changed files, repo-relative
  added    [<file>, ...]  the subset git reports as added

Reads its GitLab context from the standard CI environment:
  CI_API_V4_URL          GitLab REST v4 base (e.g. https://host/api/v4)
  CI_PROJECT_ID          numeric project id
  CI_MERGE_REQUEST_IID   MR iid (absent off MR pipelines -> graceful skip)
  GITLAB_TOKEN           write-scoped token; falls back to FORGE_PR_TOKEN,
                         then CI_JOB_TOKEN. A CI_JOB_TOKEN usually lacks the
                         scope to edit labels, so a real PAT/project token is
                         preferred.

Returns 0 (and logs) when there is nothing to do or no MR in context, so the
caller can stay non-blocking. Returns 1 only on a genuine misconfiguration
(missing API base/project/token while there are labels to apply) or an API
failure.

Usage: labels__apply "$changed" "$added"
PUB_FUN
labels__apply() {
  __labels__apply__iid="${CI_MERGE_REQUEST_IID:-}"
  if [ -z "$__labels__apply__iid" ]; then
    log "labels/apply: no merge request in context (CI_MERGE_REQUEST_IID unset); skipping."
    return 0
  fi

  # Cheap manifest check before any network read: a repo with no testing config
  # has nothing to reconcile.
  if @is_false "$(areas__has_areas_config)"; then
    log "labels/apply: no areas config; nothing to reconcile."
    return 0
  fi

  __labels__apply__base="${CI_API_V4_URL:-}"
  __labels__apply__project="${CI_PROJECT_ID:-}"
  __labels__apply__token="${GITLAB_TOKEN:-${FORGE_PR_TOKEN:-${CI_JOB_TOKEN:-}}}"

  # The established area/* labels gate the area/new fallback. Read them when we
  # have creds; without creds treat none as established, so the plan still
  # surfaces whether anything is due (and we error below only if it is).
  if [ -n "$__labels__apply__base" ] && [ -n "$__labels__apply__project" ] && [ -n "$__labels__apply__token" ]; then
    __labels__apply__established="$(__labels__apply__fetch_established_labels \
      "$__labels__apply__base" "$__labels__apply__project" "$__labels__apply__token")"
    __labels__apply__established="$(labels__establish \
      "$1" \
      "$__labels__apply__established" \
      "$__labels__apply__base" "$__labels__apply__project" "$__labels__apply__token")"
  else
    @arr __labels__apply__established
  fi

  __labels__apply__plan="$(labels__plan "$1" "$2" "$__labels__apply__established")" || return 1
  @let "$__labels__apply__plan" __labels__apply__ add remove
  @defined "$__labels__apply__add" || @arr __labels__apply__add
  @defined "$__labels__apply__remove" || @arr __labels__apply__remove

  @join __labels__apply__add_csv "$__labels__apply__add" ","
  @join __labels__apply__remove_csv "$__labels__apply__remove" ","

  if ! @defined "$__labels__apply__add_csv" \
    && ! @defined "$__labels__apply__remove_csv"; then
    log "labels/apply: no area labels touched by this diff; nothing to reconcile."
    return 0
  fi

  if [ -z "$__labels__apply__base" ] || [ -z "$__labels__apply__project" ] || [ -z "$__labels__apply__token" ]; then
    error "labels/apply: cannot apply labels -- need CI_API_V4_URL, CI_PROJECT_ID, and a token (GITLAB_TOKEN/FORGE_PR_TOKEN/CI_JOB_TOKEN)."
    return 1
  fi

  log "labels/apply: reconciling MR !${__labels__apply__iid} (add: [${__labels__apply__add_csv}], remove: [${__labels__apply__remove_csv}])"

  __labels__apply__send_request \
    "$__labels__apply__base" \
    "$__labels__apply__project" \
    "$__labels__apply__iid" \
    "$__labels__apply__token" \
    "$__labels__apply__add_csv" \
    "$__labels__apply__remove_csv" >/dev/null
  __labels__apply__status=$?
  @unlet __labels__apply__ add remove
  return "$__labels__apply__status"
}

:<<'FUN'
Network seam: issues the GitLab "update merge request" REST call that applies
the add/remove label sets. Isolated as its own function so tests can stub it
without a live API.

GitLab's MR update endpoint takes add_labels/remove_labels as comma-separated
name lists and treats them as a set operation against the MR's existing labels,
leaving every other label intact -- exactly the reconcile we want. Empty sets
are omitted from the body so an empty add never reads as "clear all labels".

  $1 api_base   $2 project_id   $3 iid   $4 token   $5 add_csv   $6 remove_csv
FUN
__labels__apply__send_request() {
  __labels__apply__send_request__url="${1}/projects/${2}/merge_requests/${3}"

  @obj __labels__apply__send_request__body
  if [ -n "$5" ]; then
    @set __labels__apply__send_request__body "$__labels__apply__send_request__body" '.add_labels' "$5"
  fi
  if [ -n "$6" ]; then
    @set __labels__apply__send_request__body "$__labels__apply__send_request__body" '.remove_labels' "$6"
  fi

  @obj __labels__apply__send_request__opts \
    '.auth' "Bearer $4" \
    '.content_type' 'application/json'

  http__request "PUT" \
    "$__labels__apply__send_request__url" \
    "$__labels__apply__send_request__body" \
    "$__labels__apply__send_request__opts"
}

: <<'CONST'
How many labels one page of the labels list carries. A page that comes back
shorter is the last one.
CONST
__labels__apply__PAGE_SIZE=100

:<<'FUN'
Network seam: reads the project's defined area/* labels (the "established" set
the plan gates the area/new fallback on). Isolated so the planner stays
unit-testable without a live API.

Reads every page of the labels list, so a project with more labels than one
page holds still reports all of them. A failed or forbidden read of any page
returns an empty array rather than erroring, so a transient label read never
blocks the reconcile: worst case every computed label reads as unestablished
and the diff falls back to area/new (the safe direction).

args:
  $1  The REST base (CI_API_V4_URL)
  $2  The project id
  $3  The token
FUN
__labels__apply__fetch_established_labels() {
  __labels__apply__fetch_established_labels__endpoint="${1}/projects/${2}/labels"
  @obj __labels__apply__fetch_established_labels__opts '.auth' "Bearer $3"

  if ! __labels__apply__fetch_established_labels__labels="$(__labels__apply__read_label_pages \
    "$__labels__apply__fetch_established_labels__endpoint" \
    "$__labels__apply__fetch_established_labels__opts"
  )"; then
    @arr __labels__apply__fetch_established_labels__out
    println "$__labels__apply__fetch_established_labels__out"
    return 0
  fi

  __labels__apply__area_labels "$__labels__apply__fetch_established_labels__labels"
}

:<<'FUN'
Prints the area/* label names in a forge's labels list $1, as a struct
array. A list that is not an array, which is what a refused read answers,
gives the empty array, so a read that failed means that nothing is
established.

  __labels__apply__area_labels '[{"name":"area/cli"},{"name":"type/fix"}]'  ->  ["area/cli"]
FUN
__labels__apply__area_labels() {
  if @typeof __labels__apply__area_labels__kind "$1"; [ "$__labels__apply__area_labels__kind" != array ]; then
    @arr __labels__apply__area_labels__out
    println "$__labels__apply__area_labels__out"
    return 0
  fi

  @pluck __labels__apply__area_labels__names "$1" '.name'
  @filter __labels__apply__area_labels__out "$__labels__apply__area_labels__names" silt__text_starts_with . area/
  println "$__labels__apply__area_labels__out"
}

:<<'FUN'
Prints every label of the labels list as one array, reading page after page
until a page comes back shorter than __labels__apply__PAGE_SIZE. Fails on the
first page the forge refuses, so the caller never sees a partial list.

args:
  $1  The labels endpoint, with no query string
  $2  The http options ({auth})
FUN
__labels__apply__read_label_pages() {
  __labels__apply__read_label_pages__page=1
  @arr __labels__apply__read_label_pages__all

  while true; do
    __labels__apply__read_label_pages__result="$(__labels__apply__read_label_page \
      "$1" \
      "$2" \
      "$__labels__apply__read_label_pages__page"
    )" || return 1
    @concat __labels__apply__read_label_pages__all \
      "$__labels__apply__read_label_pages__all" \
      "$__labels__apply__read_label_pages__result"
    if @len __labels__apply__read_label_pages__len_8 "$__labels__apply__read_label_pages__result"; [ "$__labels__apply__read_label_pages__len_8" -lt "$__labels__apply__PAGE_SIZE" ]; then
      break
    fi
    __labels__apply__read_label_pages__page=$((__labels__apply__read_label_pages__page + 1))
  done

  println "$__labels__apply__read_label_pages__all"
}

:<<'FUN'
Prints one page of the labels list, __labels__apply__PAGE_SIZE labels at most.

args:
  $1  The labels endpoint, with no query string
  $2  The http options ({auth})
  $3  The page number, counted from 1
FUN
__labels__apply__read_label_page() {
  http__request "GET" \
    "${1}?per_page=${__labels__apply__PAGE_SIZE}&page=${3}" \
    "" \
    "$2"
}
