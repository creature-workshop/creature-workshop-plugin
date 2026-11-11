#!/bin/sh

:<<'FRAGMENT'
How a Forgejo request is authorised: the token check and the headers.
FRAGMENT

__forgejo__validate_token() {
  @get __forgejo__validate_token__token "$1" '.token'
  if ! @defined "$__forgejo__validate_token__token"; then
    error "No authorization token set"
    return 1
  fi

  echo "$__forgejo__validate_token__token"
}

__forgejo__http_opts() {
  @obj __forgejo__http_opts__out '.auth' "token $1"
  println "$__forgejo__http_opts__out"
}

:<<'FUN'
Fetches every page of a page/limit endpoint and prints the records as one
array, stopping at the first page shorter than the page limit.

Usage: __forgejo__paginate "$endpoint" "$http_opts"
FUN
__forgejo__paginate() {
  __forgejo__paginate__page=1
  @arr __forgejo__paginate__all

  while :; do
    __forgejo__paginate__result="$(http__get "${1}?page=${__forgejo__paginate__page}&limit=${__forgejo__COMMENT_PAGE_LIMIT}" "$2")" || return 1
    @concat __forgejo__paginate__all "$__forgejo__paginate__all" "$__forgejo__paginate__result"
    if @len __forgejo__paginate__len_1 "$__forgejo__paginate__result"; [ "$__forgejo__paginate__len_1" -lt "$__forgejo__COMMENT_PAGE_LIMIT" ]; then
      break
    fi
    __forgejo__paginate__page=$((__forgejo__paginate__page + 1))
  done

  println "$__forgejo__paginate__all"
}
