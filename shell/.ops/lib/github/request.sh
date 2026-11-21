#!/bin/sh

:<<'FRAGMENT'
How a GitHub request is authorised and shaped: the token check, the headers, and the release body.
FRAGMENT

__github__validate_token() {
  @get __github__validate_token__token "$1" '.token'
  if ! @defined "$__github__validate_token__token"; then
    error "No authorization token set"
    return 1
  fi

  echo "$__github__validate_token__token"
}

__github__http_opts() {
  @obj __github__http_opts__out '.auth' "Bearer $1" '.accept' "application/vnd.github+json"
  println "$__github__http_opts__out"
}

:<<'FUN'
The http options for a request that authenticates only when it has a token: an
empty one sends no authorization header at all, which is what a public
repository answers a caller with no credentials on.

Usage: __github__open_http_opts "$token"
FUN
__github__open_http_opts() {
  @obj __github__open_http_opts__obj_1 '.accept' "application/vnd.github+json"
  @patch __github__open_http_opts__out "$__github__open_http_opts__obj_1" \
    '.auth' "$(forge__base__auth_header Bearer "$1")"
  println "$__github__open_http_opts__out"
}

__github__release_body() {
  @pick __github__release_body__fields "$1" tag_name name body prerelease
  @dump __github__release_body__out "$__github__release_body__fields"
  println "$__github__release_body__out"
}

:<<'FUN'
The http options for a request that wants a file's bytes rather than the JSON
that describes it.

Usage: __github__raw_http_opts "$token"
FUN
__github__raw_http_opts() {
  @obj __github__raw_http_opts__out '.auth' "Bearer $1" '.accept' "application/vnd.github.raw+json"
  println "$__github__raw_http_opts__out"
}

:<<'FUN'
Fetches every page of a page/per_page endpoint and prints the records as one
array, stopping at the first page shorter than the page limit. $3 is any extra
query, spliced in beside the paging.

Usage: __github__paginate "$endpoint" "$http_opts" "state=open"
FUN
__github__paginate() {
  __github__paginate__query="${3:-}"
  if @defined "$__github__paginate__query"; then
    __github__paginate__query="&${__github__paginate__query}"
  fi
  __github__paginate__page=1
  @arr __github__paginate__all

  while :; do
    __github__paginate__result="$(http__get "${1}?per_page=${__github__PAGE_LIMIT}&page=${__github__paginate__page}${__github__paginate__query}" "$2")" || return 1
    @concat __github__paginate__all "$__github__paginate__all" "$__github__paginate__result"
    if @len __github__paginate__len_2 "$__github__paginate__result"; [ "$__github__paginate__len_2" -lt "$__github__PAGE_LIMIT" ]; then
      break
    fi
    __github__paginate__page=$((__github__paginate__page + 1))
  done

  println "$__github__paginate__all"
}

:<<'FUN'
The event payload GitHub Actions wrote for this run, or nothing outside one.

Usage: __github__event
FUN
__github__event() {
  @defined "${GITHUB_EVENT_PATH:-}" || return 0
  [ -f "$GITHUB_EVENT_PATH" ] || return 0
  cat "$GITHUB_EVENT_PATH"
}

:<<'FUN'
One pull request's record for github_reviews_awaiting_author, read from its
reviews; nothing when no reviewer is waiting on its author.

Usage: __github__awaiting_record "$pull" "$options" "$http_opts"
FUN
__github__awaiting_record() {
  @get __github__awaiting_record__get_3 "$1" '.number'
  @set __github__awaiting_record__options "$2" '.review_number' "$__github__awaiting_record__get_3"
  __github__awaiting_record__reviews="$(__github__paginate \
    "$(__github__render_endpoint "$__github__PULL_REVIEWS_ENDPOINT" "$__github__awaiting_record__options")" \
    "$3"
  )" || return 1

  @run_awk __github__awaiting_record__out \
    "$SHELLOPS_DIR/lib/github/awaiting_author.awk" \
    "$1" \
    --with "$__github__awaiting_record__reviews" || return 1
  println "$__github__awaiting_record__out"
}
