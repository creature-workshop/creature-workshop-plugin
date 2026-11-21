#!/bin/sh

:<<'MODULE'
GraphQL request primitives with error handling and cursor-based pagination.

Built on http__request from http/api.sh. Handles the GraphQL-specific concern
that errors are returned in the response body (HTTP 200) rather than via
status codes.
MODULE

import "$SHELLOPS_DIR/lib/http/api.sh"

# CONST: The variables a request sends when the caller gives none: an empty object.
@obj __graphql__EMPTY_VARS

:<<'PUB_FUN'
Prints the GraphQL document <operation>.graphql from the directory <dir>. A
service's library keeps its documents beside its code, so each passes its
own directory.

Usage: graphql__load "$SHELLOPS_DIR/lib/linear" "get-issue"
PUB_FUN
graphql__load() {
  __graphql__load__filepath="$1/$2.graphql"

  if [ ! -f "$__graphql__load__filepath" ]; then
    error "GraphQL document not found: $__graphql__load__filepath"
    return 1
  fi

  cat "$__graphql__load__filepath"
}

:<<'PUB_FUN'
Executes a GraphQL query and returns the .data portion of the response.

Checks for .errors in the response body — GraphQL returns HTTP 200 even
on query failures, so http__request alone cannot detect them.

Usage:
  graphql__request "$endpoint" "$http_opts" "$query"
  graphql__request "$endpoint" "$http_opts" "$query" "$variables_json"
PUB_FUN
graphql__request() {
  __graphql__request__endpoint="$1"
  __graphql__request__http_opts="$2"
  __graphql__request__query="$3"
  __graphql__request__variables="${4:-$__graphql__EMPTY_VARS}"

  @obj __graphql__request__body \
    '.query' "$__graphql__request__query" \
    '.variables' "$__graphql__request__variables"

  __graphql__request__result="$(
    http__post "$__graphql__request__endpoint" "$__graphql__request__body" "$__graphql__request__http_opts"
  )" || return 1

  if @is_true "$(__graphql__has_errors "$__graphql__request__result")"; then
    __graphql__log_errors "$__graphql__request__result" "$__graphql__request__endpoint"
    return 1
  fi

  @get __graphql__request__out "$__graphql__request__result" '.data'
  println "$__graphql__request__out"
}

:<<'PUB_FUN'
Executes a paginated GraphQL query and returns all nodes concatenated.

The query MUST include a pageInfo { hasNextPage endCursor } selection and
accept a $cursor: String variable. The data_path identifies where the
paginated connection lives within .data (e.g. ".organization.repositories").

Usage:
  graphql__paginate "$endpoint" "$http_opts" "$query" "$variables" "$data_path"
PUB_FUN
graphql__paginate() {
  __graphql__paginate__endpoint="$1"
  __graphql__paginate__http_opts="$2"
  __graphql__paginate__query="$3"
  __graphql__paginate__variables="${4:-$__graphql__EMPTY_VARS}"
  __graphql__paginate__data_path="$5"
  @arr __graphql__paginate__all_nodes
  __graphql__paginate__cursor="null"

  while true; do
    @set __graphql__paginate__vars_with_cursor "$__graphql__paginate__variables" '.cursor' "$__graphql__paginate__cursor"

    __graphql__paginate__data="$(
      graphql__request "$__graphql__paginate__endpoint" \
        "$__graphql__paginate__http_opts" \
        "$__graphql__paginate__query" \
        "$__graphql__paginate__vars_with_cursor"
    )" || return 1

    @get __graphql__paginate__connection "$__graphql__paginate__data" "$__graphql__paginate__data_path"
    @arr __graphql__paginate__arr_1
    @get __graphql__paginate__nodes "$__graphql__paginate__connection" '.nodes' '.edges' "$__graphql__paginate__arr_1"
    @get __graphql__paginate__has_next "$__graphql__paginate__connection" '.pageInfo.hasNextPage'
    @get __graphql__paginate__end_cursor "$__graphql__paginate__connection" '.pageInfo.endCursor'

    @concat __graphql__paginate__all_nodes "$__graphql__paginate__all_nodes" "$__graphql__paginate__nodes"

    if [ "$__graphql__paginate__has_next" != "true" ]; then
      break
    fi

    __graphql__paginate__cursor="$__graphql__paginate__end_cursor"
  done

  echo "$__graphql__paginate__all_nodes"
}

__graphql__has_errors() {
  @arr __graphql__has_errors__arr_2
  @get __graphql__has_errors__errors "$1" '.errors' "$__graphql__has_errors__arr_2"
  @len __graphql__has_errors__len_3 "$__graphql__has_errors__errors"
  @succeeds __graphql__has_errors__out [ "$__graphql__has_errors__len_3" -gt 0 ]
  println "$__graphql__has_errors__out"
}

__graphql__log_errors() {
  @arr __graphql__log_errors__arr_4
  @get __graphql__log_errors__errors "$1" '.errors' "$__graphql__log_errors__arr_4"
  @pluck __graphql__log_errors__pluck_5 "$__graphql__log_errors__errors" '.message'
  @join __graphql__log_errors__messages "$__graphql__log_errors__pluck_5" "; "
  error "GraphQL query to $2 failed: $__graphql__log_errors__messages"
}
