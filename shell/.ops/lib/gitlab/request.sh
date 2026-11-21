#!/bin/sh

:<<'FRAGMENT'
How a GitLab request is authorised and sent: the token check, the headers, the GraphQL documents and their variables, REST pagination, and the mutation error check.
FRAGMENT

__gitlab__validate_token() {
  @get __gitlab__validate_token__token "$1" '.token'
  if ! @defined "$__gitlab__validate_token__token"; then
    error "No authorization token set"
    return 1
  fi

  echo "$__gitlab__validate_token__token"
}

:<<'FUN'
GitLab accepts personal access tokens, deploy tokens, and OAuth tokens
via the "Bearer" Authorization header. Project access tokens work too.
FUN
__gitlab__http_opts() {
  @obj __gitlab__http_opts__out '.auth' "Bearer $1"
  println "$__gitlab__http_opts__out"
}

:<<'FUN'
Wraps an MR/issue iid as an explicit JSON string for GraphQL variables.

GitLab GraphQL declares iid as String!, but @set promotes numeric
strings to JSON numbers (via --argjson), which the server rejects with
"Variable $iid of type String! was provided invalid value". Emitting a
quoted JSON string forces @set to keep it a string.

Usage: @set '{}' '.iid' "$(__gitlab__iid_var "$iid")"
FUN
__gitlab__iid_var() {
  @encode_string __gitlab__iid_var__out "$1"
  println "$__gitlab__iid_var__out"
}

:<<'FUN'
Read a sibling .graphql file, the way graphql__load reads one from the
directory a service's library keeps its documents in.
FUN
__gitlab__load_graphql() {
  __gitlab__load_graphql__filepath="$__gitlab__GRAPHQL_DIR/$1.graphql"

  if [ ! -f "$__gitlab__load_graphql__filepath" ]; then
    error "GitLab GraphQL document not found: $__gitlab__load_graphql__filepath"
    return 1
  fi

  cat "$__gitlab__load_graphql__filepath"
}

:<<'FUN'
Runs a GraphQL operation against the GitLab endpoint with the given auth
opts. Centralizes the request boilerplate shared by every gitlab_* GraphQL
call so the call sites read as one line.
FUN
__gitlab__graphql() {
  graphql__request \
    "$__gitlab__GRAPHQL_ENDPOINT" \
    "$3" \
    "$1" \
    "$2"
}

:<<'FUN'
Fetches every page of a page/per_page REST endpoint and concatenates the
records into a single JSON array, stopping once a page returns fewer than
$limit. The endpoint must not already carry a query string; $4 is any extra
query the endpoint needs (e.g. "sort=asc"), spliced in beside the paging.
FUN
__gitlab__rest_paginate() {
  __gitlab__rest_paginate__endpoint="$1"
  __gitlab__rest_paginate__http_opts="$2"
  __gitlab__rest_paginate__limit="${3:-100}"
  __gitlab__rest_paginate__query="${4:-}"
  ! @defined "$__gitlab__rest_paginate__query" \
    || __gitlab__rest_paginate__query="&${__gitlab__rest_paginate__query}"
  __gitlab__rest_paginate__page=1
  @arr __gitlab__rest_paginate__all

  while true; do
    __gitlab__rest_paginate__result="$(http__get "${__gitlab__rest_paginate__endpoint}?page=${__gitlab__rest_paginate__page}&per_page=${__gitlab__rest_paginate__limit}${__gitlab__rest_paginate__query}" "$__gitlab__rest_paginate__http_opts")" || return 1
    @len __gitlab__rest_paginate__count "$__gitlab__rest_paginate__result"
    @concat __gitlab__rest_paginate__all "$__gitlab__rest_paginate__all" "$__gitlab__rest_paginate__result"

    [ "$__gitlab__rest_paginate__count" -lt "$__gitlab__rest_paginate__limit" ] && break
    __gitlab__rest_paginate__page=$((__gitlab__rest_paginate__page + 1))
  done

  println "$__gitlab__rest_paginate__all"
}

:<<'FUN'
GitLab GraphQL returns user errors as a `.errors` array on the mutation
payload (separate from the top-level GraphQL .errors that graphql__request
already handles). Surface them with the operation name for debugging.
FUN
__gitlab__check_mutation_errors() {
  @arr __gitlab__check_mutation_errors__arr_1
  @get __gitlab__check_mutation_errors__errors "$1" ".${2}.errors" "$__gitlab__check_mutation_errors__arr_1"
  @len __gitlab__check_mutation_errors__count "$__gitlab__check_mutation_errors__errors"

  if [ "$__gitlab__check_mutation_errors__count" -gt 0 ]; then
    @join __gitlab__check_mutation_errors__join_2 "$__gitlab__check_mutation_errors__errors" "; "
    error "GitLab ${2} mutation failed: $__gitlab__check_mutation_errors__join_2"
    return 1
  fi
}
