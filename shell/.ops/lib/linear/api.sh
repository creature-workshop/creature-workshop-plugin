#!/bin/sh
# shellcheck disable=SC2119  # bare @arr is the structs empty constructor

:<<'MODULE'
Linear API client for issue queries, label management, and workflow operations.
Built on graphql/api.sh for query execution.

Operations are the .graphql documents beside this file, loaded at call
time via graphql__load.
MODULE

import \
  "$SHELLOPS_DIR/lib/fingerprint/api.sh" \
  "$SHELLOPS_DIR/lib/graphql/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

__linear__ENDPOINT="https://api.linear.app/graphql"

# CONST: The directory of the Linear operations, the .graphql documents beside this file.
__linear__GRAPHQL_DIR="$SHELLOPS_DIR/lib/linear"

# The token reaches this client as an option, but LINEAR_API_KEY is where it
# comes from: an action reads that variable in order to call the operations
# below, so importing them is what says a run needs it.
fingerprint__secret LINEAR_API_KEY

:<<'PUB_FUN'
Creates default Linear options.

Usage: linear__new_linear_options
PUB_FUN
linear__new_linear_options() {
  @obj __linear__new_linear_options__out \
    '.token' ""
  println "$__linear__new_linear_options__out"
}

:<<'PUB_FUN'
Creates a default attachment object for linear__add_attachment.

Usage:
  att="$(@set "$(linear__new_attachment)" '.title' "repo" '.url' "https://...")"
PUB_FUN
linear__new_attachment() {
  @obj\
    '.title' "" \
    '.url' ""
}

__linear__validate_token() {
  @get __linear__validate_token__token "$1" '.token'
  if ! @defined "$__linear__validate_token__token"; then
    error "No Linear API token set"
    return 1
  fi

  echo "$__linear__validate_token__token"
}

__linear__http_opts() {
  @obj __linear__http_opts__out '.auth' "$1"
  println "$__linear__http_opts__out"
}

__linear__check_success() {
  @get __linear__check_success__success "$1" ".$2.success"
  if [ "$__linear__check_success__success" != "true" ]; then
    error "Linear $2 failed"
    return 1
  fi
}

:<<'PUB_FUN'
Runs the Linear operation <name>, the document <name>.graphql beside this file,
with <variables>, and prints the data it answers with. Fails, saying so, when
the options carry no token or the operation reports an error.

Usage: linear__request plan-team "$(@obj '.key' SHOP)" "$options"
PUB_FUN
linear__request() {
  __linear__request__token="$(__linear__validate_token "$3")" || return 1
  __linear__request__query="$(graphql__load "$__linear__GRAPHQL_DIR" "$1")" || return 1
  graphql__request \
    "$__linear__ENDPOINT" \
    "$(__linear__http_opts "$__linear__request__token")" \
    "$__linear__request__query" \
    "$2"
}

:<<'PUB_FUN'
Runs the paginated Linear operation <name> with <variables>, following the
connection at <data_path> to its last page, and prints every node as one
struct array. The document takes a $cursor variable and selects pageInfo, as
graphql__paginate asks.

Usage: linear__paginate plan-issues "$(@obj '.filter' "$filter")" '.issues' "$options"
PUB_FUN
linear__paginate() {
  __linear__paginate__token="$(__linear__validate_token "$4")" || return 1
  __linear__paginate__query="$(graphql__load "$__linear__GRAPHQL_DIR" "$1")" || return 1
  graphql__paginate \
    "$__linear__ENDPOINT" \
    "$(__linear__http_opts "$__linear__paginate__token")" \
    "$__linear__paginate__query" \
    "$2" \
    "$3"
}

:<<'PUB_FUN'
Fetches a Linear issue by its identifier (e.g. "SHSH-48").

Returns a JSON object with: identifier, url, title, description, priority,
priorityLabel, state, and labels.

Usage: linear__get_issue "$issue_id" "$options"
PUB_FUN
linear__get_issue() {
  __linear__get_issue__token="$(__linear__validate_token "$2")" || return 1
  __linear__get_issue__http_opts="$(__linear__http_opts "$__linear__get_issue__token")"
  __linear__get_issue__query="$(graphql__load "$__linear__GRAPHQL_DIR" "get-issue")" || return 1
  @obj __linear__get_issue__variables '.id' "$1"

  __linear__get_issue__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__get_issue__http_opts" \
      "$__linear__get_issue__query" \
      "$__linear__get_issue__variables"
  )" || return 1

  @get __linear__get_issue__out "$__linear__get_issue__result" '.issue'
  println "$__linear__get_issue__out"
}

:<<'PUB_FUN'
Fetches each of IDENTIFIERS, as a struct array of issues.

An identifier Linear will not answer for is logged and left out rather than
failing the batch: one deleted or mistyped reference among ten should cost that
one reference. The array is therefore no longer than IDENTIFIERS.

Usage: linear__get_issues "$identifiers" "$options"
PUB_FUN
linear__get_issues() {
  @arr __linear__get_issues__arr_1
  @reduce __linear__get_issues__out __linear__collect_issue "$1" "$__linear__get_issues__arr_1" "$2"
  println "$__linear__get_issues__out"
}

__linear__collect_issue() {
  @unwrap __linear__collect_issue__ref "$2"
  __linear__collect_issue__issue="$(
    linear__get_issue "$__linear__collect_issue__ref" "$3" 2>/dev/null || true
  )"

  if ! @defined "$__linear__collect_issue__issue"; then
    log "  Could not fetch ${__linear__collect_issue__ref}, skipping."
    println "$1"
    return 0
  fi

  @push __linear__collect_issue__out "$1" "$__linear__collect_issue__issue"
  println "$__linear__collect_issue__out"
}

:<<'PUB_FUN'
Lists all teams in the workspace, including their workflow states.

Returns a JSON array of team objects with: id, name, key, states.

Usage: linear__list_teams "$options"
PUB_FUN
linear__list_teams() {
  __linear__list_teams__token="$(__linear__validate_token "$1")" || return 1
  __linear__list_teams__http_opts="$(__linear__http_opts "$__linear__list_teams__token")"
  __linear__list_teams__query="$(graphql__load "$__linear__GRAPHQL_DIR" "list-teams")" || return 1

  __linear__list_teams__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__list_teams__http_opts" \
      "$__linear__list_teams__query"
  )" || return 1

  @get __linear__list_teams__out "$__linear__list_teams__result" '.teams.nodes'
  println "$__linear__list_teams__out"
}

:<<'PUB_FUN'
Prints the key of every team in TEAMS, the array linear__list_teams prints,
as a struct array: every prefix an issue identifier can carry.

  linear__team_keys "$teams"  ->  ["OPS","KAITOS"]

Usage: linear__team_keys "$teams"
PUB_FUN
linear__team_keys() {
  @pluck __linear__team_keys__out "$1" '.key'
  println "$__linear__team_keys__out"
}

:<<'PUB_FUN'
Lists untriaged issues scoped to the given team IDs. Paginated.

Excludes issues that are completed, cancelled, started, or already
carry a blizz/* label.

Returns a JSON array of issue objects.

Usage: linear__list_untriaged_issues "$options" "$team_ids_json"
PUB_FUN
linear__list_untriaged_issues() {
  __linear__list_untriaged_issues__token="$(__linear__validate_token "$1")" || return 1
  __linear__list_untriaged_issues__http_opts="$(__linear__http_opts "$__linear__list_untriaged_issues__token")"
  __linear__list_untriaged_issues__query="$(graphql__load "$__linear__GRAPHQL_DIR" "list-untriaged-issues")" || return 1
  @obj __linear__list_untriaged_issues__variables '.teamIds' "$2"

  graphql__paginate \
    "$__linear__ENDPOINT" \
    "$__linear__list_untriaged_issues__http_opts" \
    "$__linear__list_untriaged_issues__query" \
    "$__linear__list_untriaged_issues__variables" \
    '.issues'
}

:<<'PUB_FUN'
Lists the issues the options' .filter selects, with each issue's id,
identifier, title, state, team key and attachment URLs. Paginated.

.filter is an IssueFilter struct in Linear's own shape, sent as it is, so a
caller says what it wants in the filter's words: states by name, a team by
key, an attachment by what its URL contains. Without one, every issue.

  filter='{"state": {"name": {"in": ["In Review"]}}, "attachments": {"url": {"contains": "https://gitlab.example.com"}}}'
  linear__list_issues "$(@obj '.token' "$key" '.filter' "$filter")"
    -> [{"id": "...", "identifier": "OPS-12", "title": "...",
         "state": {"name": "In Review", "type": "started"}, "team": {"key": "OPS"},
         "attachments": {"nodes": [{"url": "https://gitlab.example.com/org/tool/-/merge_requests/7"}]}}]

Usage: linear__list_issues "$options"
PUB_FUN
linear__list_issues() {
  __linear__list_issues__token="$(__linear__validate_token "$1")" || return 1
  __linear__list_issues__http_opts="$(__linear__http_opts "$__linear__list_issues__token")"
  __linear__list_issues__query="$(graphql__load "$__linear__GRAPHQL_DIR" "list-issues")" || return 1
  @obj __linear__list_issues__everything
  @get __linear__list_issues__filter "$1" '.filter' "$__linear__list_issues__everything"
  @obj __linear__list_issues__variables '.filter' "$__linear__list_issues__filter"

  graphql__paginate \
    "$__linear__ENDPOINT" \
    "$__linear__list_issues__http_opts" \
    "$__linear__list_issues__query" \
    "$__linear__list_issues__variables" \
    '.issues'
}

:<<'PUB_FUN'
Returns the current labels attached to an issue.

Returns a JSON array of {id, name} objects.

Usage: linear__get_issue_labels "$issue_id" "$options"
PUB_FUN
linear__get_issue_labels() {
  __linear__get_issue_labels__token="$(__linear__validate_token "$2")" || return 1
  __linear__get_issue_labels__http_opts="$(__linear__http_opts "$__linear__get_issue_labels__token")"
  __linear__get_issue_labels__query="$(graphql__load "$__linear__GRAPHQL_DIR" "get-issue-labels")" || return 1
  @obj __linear__get_issue_labels__variables '.id' "$1"

  __linear__get_issue_labels__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__get_issue_labels__http_opts" \
      "$__linear__get_issue_labels__query" \
      "$__linear__get_issue_labels__variables"
  )" || return 1

  @get __linear__get_issue_labels__out "$__linear__get_issue_labels__result" '.issue.labels.nodes'
  println "$__linear__get_issue_labels__out"
}

:<<'PUB_FUN'
Lists all workspace-level issue labels. Paginated.

Returns a JSON array of {id, name, color} objects.

Usage: linear__list_labels "$options"
PUB_FUN
linear__list_labels() {
  __linear__list_labels__token="$(__linear__validate_token "$1")" || return 1
  __linear__list_labels__http_opts="$(__linear__http_opts "$__linear__list_labels__token")"
  __linear__list_labels__query="$(graphql__load "$__linear__GRAPHQL_DIR" "list-labels")" || return 1

  @obj __linear__list_labels__obj_2
  graphql__paginate \
    "$__linear__ENDPOINT" \
    "$__linear__list_labels__http_opts" \
    "$__linear__list_labels__query" \
    "$__linear__list_labels__obj_2" \
    '.issueLabels'
}

:<<'PUB_FUN'
Creates a comment on a Linear issue.

Usage: linear__add_comment "$issue_id" "$body" "$options"
PUB_FUN
linear__add_comment() {
  __linear__add_comment__token="$(__linear__validate_token "$3")" || return 1
  __linear__add_comment__http_opts="$(__linear__http_opts "$__linear__add_comment__token")"
  __linear__add_comment__query="$(graphql__load "$__linear__GRAPHQL_DIR" "comment-create")" || return 1
  @obj __linear__add_comment__variables '.issueId' "$1" '.body' "$2"

  __linear__add_comment__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__add_comment__http_opts" \
      "$__linear__add_comment__query" \
      "$__linear__add_comment__variables"
  )" || return 1

  __linear__check_success "$__linear__add_comment__result" "commentCreate"
}

:<<'PUB_FUN'
Creates an issue on a Linear team and prints what was created
({id, identifier, url, title}). The issue lands inside a project when the
options carry one as .project, the project's id; with none it lands on the
team alone.

Usage:
  linear__create_issue "$team_id" "$title" "$description" "$options"
  options="$(@set "$(linear__new_linear_options)" '.token' "$key" '.project' "$project_id")"
PUB_FUN
linear__create_issue() {
  __linear__create_issue__token="$(__linear__validate_token "$4")" || return 1
  __linear__create_issue__http_opts="$(__linear__http_opts "$__linear__create_issue__token")"
  __linear__create_issue__query="$(graphql__load "$__linear__GRAPHQL_DIR" "issue-create")" || return 1
  __linear__create_issue__variables="$(__linear__create_issue_variables "$1" "$2" "$3" "$4")"

  __linear__create_issue__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__create_issue__http_opts" \
      "$__linear__create_issue__query" \
      "$__linear__create_issue__variables"
  )" || return 1

  __linear__check_success "$__linear__create_issue__result" "issueCreate" || return 1
  @get __linear__create_issue__out "$__linear__create_issue__result" '.issueCreate.issue'
  println "$__linear__create_issue__out"
}

:<<'FUN'
The variables of an issue-create: the team, the title and the description,
and the project when the options name one.

Usage: __linear__create_issue_variables "$team_id" "$title" "$description" "$options"
FUN
__linear__create_issue_variables() {
  @obj __linear__create_issue_variables__variables \
    '.teamId' "$1" \
    '.title' "$2" \
    '.description' "$3"
  @get __linear__create_issue_variables__project "$4" '.project' ''

  if @defined "$__linear__create_issue_variables__project"; then
    @set __linear__create_issue_variables__variables "$__linear__create_issue_variables__variables" '.projectId' "$__linear__create_issue_variables__project"
  fi

  println "$__linear__create_issue_variables__variables"
}

:<<'PUB_FUN'
Creates or updates an attachment on a Linear issue.

URL is idempotent per issue — re-creating with the same URL updates the
existing attachment instead of duplicating.

Attachment object fields:
  .title     (required) Display title for the attachment card
  .url       (required) Link URL — idempotent key per issue
  .subtitle  (optional) Subtitle text below the title
  .metadata  (optional) JSON object stored as structured metadata

Usage:
  attachment="$(@set '{}' '.title' "repo" '.url' "https://..." '.subtitle' "info" '.metadata' "$meta")"
  linear__add_attachment "$issue_id" "$attachment" "$options"
PUB_FUN
linear__add_attachment() {
  __linear__add_attachment__token="$(__linear__validate_token "$3")" || return 1
  __linear__add_attachment__http_opts="$(__linear__http_opts "$__linear__add_attachment__token")"
  __linear__add_attachment__query="$(graphql__load "$__linear__GRAPHQL_DIR" "attachment-create")" || return 1
  @set __linear__add_attachment__variables "$2" '.issueId' "$1"

  __linear__add_attachment__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__add_attachment__http_opts" \
      "$__linear__add_attachment__query" \
      "$__linear__add_attachment__variables"
  )" || return 1

  __linear__check_success "$__linear__add_attachment__result" "attachmentCreate"
}

:<<'PUB_FUN'
Creates a workspace-level issue label.

Returns the created label object with id and name.

Usage: linear__create_label "$name" "$color" "$options"
PUB_FUN
linear__create_label() {
  __linear__create_label__token="$(__linear__validate_token "$3")" || return 1
  __linear__create_label__http_opts="$(__linear__http_opts "$__linear__create_label__token")"
  __linear__create_label__query="$(graphql__load "$__linear__GRAPHQL_DIR" "label-create")" || return 1
  @obj __linear__create_label__variables '.name' "$1" '.color' "$2"

  __linear__create_label__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__create_label__http_opts" \
      "$__linear__create_label__query" \
      "$__linear__create_label__variables"
  )" || return 1

  __linear__check_success "$__linear__create_label__result" "issueLabelCreate" || return 1
  @get __linear__create_label__out "$__linear__create_label__result" '.issueLabelCreate.issueLabel'
  println "$__linear__create_label__out"
}

:<<'PUB_FUN'
Adds labels to an issue, preserving existing ones.

Fetches the issue's current labels, merges with the provided IDs,
and updates the issue with the deduplicated combined set.

Usage: linear__add_labels "$issue_id" "$label_ids_json" "$options"
PUB_FUN
linear__add_labels() {
  __linear__add_labels__current_labels="$(linear__get_issue_labels "$1" "$3")" || return 1
  @pluck __linear__add_labels__current_ids "$__linear__add_labels__current_labels" '.id'
  @concat __linear__add_labels__concat_3 "$__linear__add_labels__current_ids" "$2"
  @unique __linear__add_labels__combined "$__linear__add_labels__concat_3"

  __linear__add_labels__token="$(__linear__validate_token "$3")" || return 1
  __linear__add_labels__http_opts="$(__linear__http_opts "$__linear__add_labels__token")"
  __linear__add_labels__query="$(graphql__load "$__linear__GRAPHQL_DIR" "issue-update-labels")" || return 1
  @obj __linear__add_labels__variables '.id' "$1" '.labelIds' "$__linear__add_labels__combined"

  __linear__add_labels__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__add_labels__http_opts" \
      "$__linear__add_labels__query" \
      "$__linear__add_labels__variables"
  )" || return 1

  __linear__check_success "$__linear__add_labels__result" "issueUpdate"
}

:<<'PUB_FUN'
Transitions an issue to a new workflow state.

Usage: linear__update_issue_state "$issue_id" "$state_id" "$options"
PUB_FUN
linear__update_issue_state() {
  __linear__update_issue_state__token="$(__linear__validate_token "$3")" || return 1
  __linear__update_issue_state__http_opts="$(__linear__http_opts "$__linear__update_issue_state__token")"
  __linear__update_issue_state__query="$(graphql__load "$__linear__GRAPHQL_DIR" "issue-update-state")" || return 1
  @obj __linear__update_issue_state__variables '.id' "$1" '.stateId' "$2"

  __linear__update_issue_state__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__update_issue_state__http_opts" \
      "$__linear__update_issue_state__query" \
      "$__linear__update_issue_state__variables"
  )" || return 1

  __linear__check_success "$__linear__update_issue_state__result" "issueUpdate"
}

:<<'PUB_FUN'
Finds the "Done" state ID for a team, given the teams JSON from
linear__list_teams and a team key (e.g. "OPS").

Returns the state ID, or fails if no completed state is found.

Usage: linear__find_done_state "$teams_json" "$team_key"
PUB_FUN
linear__find_done_state() {
  @filter __linear__find_done_state__matched_teams "$1" silt__text_is .key "$2"
  @first __linear__find_done_state__team "$__linear__find_done_state__matched_teams"
  @defined "$__linear__find_done_state__team" || return 0

  @get __linear__find_done_state__states "$__linear__find_done_state__team" '.states.nodes'
  @filter __linear__find_done_state__completed "$__linear__find_done_state__states" silt__text_is .type completed
  @filter __linear__find_done_state__matched_states "$__linear__find_done_state__completed" silt__text_is .name Done
  @first __linear__find_done_state__done_state "$__linear__find_done_state__matched_states"
  @get __linear__find_done_state__out "$__linear__find_done_state__done_state" '.id'
  println "$__linear__find_done_state__out"
}

:<<'PUB_FUN'
Moves an issue to a different team, setting it to the given workflow state.

The caller is responsible for looking up the target team's backlog state ID.

Usage: linear__move_issue_to_team "$issue_id" "$team_id" "$state_id" "$options"
PUB_FUN
linear__move_issue_to_team() {
  __linear__move_issue_to_team__token="$(__linear__validate_token "$4")" || return 1
  __linear__move_issue_to_team__http_opts="$(__linear__http_opts "$__linear__move_issue_to_team__token")"
  __linear__move_issue_to_team__query="$(graphql__load "$__linear__GRAPHQL_DIR" "issue-move-team")" || return 1
  @obj __linear__move_issue_to_team__variables '.id' "$1" '.teamId' "$2" '.stateId' "$3"

  __linear__move_issue_to_team__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__move_issue_to_team__http_opts" \
      "$__linear__move_issue_to_team__query" \
      "$__linear__move_issue_to_team__variables"
  )" || return 1

  __linear__check_success "$__linear__move_issue_to_team__result" "issueUpdate"
}

:<<'PUB_FUN'
Prints the one open issue titled exactly $1 on the team keyed $2, with its
id, identifier, url, title and createdAt; nothing when none is open. Open
means in any state but a completed or canceled one.

Usage: linear__find_open_issue_by_title "$title" "$team_key" "$options"
PUB_FUN
linear__find_open_issue_by_title() {
  __linear__find_open_issue_by_title__token="$(__linear__validate_token "$3")" || return 1
  __linear__find_open_issue_by_title__http_opts="$(__linear__http_opts "$__linear__find_open_issue_by_title__token")"
  __linear__find_open_issue_by_title__query="$(graphql__load "$__linear__GRAPHQL_DIR" "find-open-issue-by-title")" || return 1
  @obj __linear__find_open_issue_by_title__variables '.title' "$1" '.teamKey' "$2"

  __linear__find_open_issue_by_title__result="$(
    graphql__request \
      "$__linear__ENDPOINT" \
      "$__linear__find_open_issue_by_title__http_opts" \
      "$__linear__find_open_issue_by_title__query" \
      "$__linear__find_open_issue_by_title__variables"
  )" || return 1

  @arr __linear__find_open_issue_by_title__arr_4
  @get __linear__find_open_issue_by_title__get_5 "$__linear__find_open_issue_by_title__result" '.issues.nodes' "$__linear__find_open_issue_by_title__arr_4"
  @first __linear__find_open_issue_by_title__out "$__linear__find_open_issue_by_title__get_5"
  println "$__linear__find_open_issue_by_title__out"
}
