#!/bin/sh

:<<'FRAGMENT'
The other bodies and variables GitLab calls send: the release link type, the merged-since and branch variables, a review's update body.
FRAGMENT

:<<'FUN'
Prints a link_type option word as GitLab's ReleaseAssetLinkType enum value:
the enum is upper case (OTHER, RUNBOOK, PACKAGE, IMAGE) and rejects the
lower-case word the options carry.

Usage: __gitlab__link_type_enum "other"   # -> OTHER
FUN
__gitlab__link_type_enum() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

: <<'FUN'
Encodes the optional $since timestamp as a GraphQL variable value: the raw ISO
string when present, or JSON null when empty (no prior tag) so the optional Time
arg is omitted rather than sent as an invalid empty string.
FUN
__gitlab__since_var() {
  if ! @defined "$1"; then
    printf 'null'
    return
  fi
  @encode_string __gitlab__since_var__out "$1"
  println "$__gitlab__since_var__out"
}

: <<'FUN'
Encodes the optional branch filter as a GraphQL variable value: a one-element
list when a branch is named, or JSON null when empty, so sourceBranches is
omitted rather than sent as a list containing an empty string (which matches no
branch instead of every branch).
FUN
__gitlab__branches_var() {
  if ! @defined "$1"; then
    printf 'null'
    return
  fi
  @arr __gitlab__branches_var__out "$1"
  println "$__gitlab__branches_var__out"
}

:<<'FUN'
Maps the adaptor-neutral {title, body} onto GitLab's REST field names, dropping
whatever the caller left out so a PUT never blanks a field it was not given.

Usage: __gitlab__merge_request_update_body "$options"
FUN
__gitlab__merge_request_update_body() {
  @let "$1" __gitlab__merge_request_update_body__ title body
  @obj __gitlab__merge_request_update_body__out

  if @defined "$__gitlab__merge_request_update_body__title"; then
    @set __gitlab__merge_request_update_body__out \
        "$__gitlab__merge_request_update_body__out" \
        '.title' \
        "$__gitlab__merge_request_update_body__title"
  fi

  if @defined "$__gitlab__merge_request_update_body__body"; then
    @set __gitlab__merge_request_update_body__out \
        "$__gitlab__merge_request_update_body__out" \
        '.description' \
        "$__gitlab__merge_request_update_body__body"
  fi

  println "$__gitlab__merge_request_update_body__out"
  @unlet __gitlab__merge_request_update_body__ title body
}
