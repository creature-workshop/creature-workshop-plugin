#!/bin/sh

:<<'FRAGMENT'
The bodies Forgejo calls send.
FRAGMENT

:<<'FUN'
The body that creates a release: its tag, name, body and whether it is a
prerelease, out of the release options $1.
FUN
__forgejo__release_body() {
  @pick __forgejo__release_body__fields "$1" tag_name name body prerelease
  @dump __forgejo__release_body__out "$__forgejo__release_body__fields"
  println "$__forgejo__release_body__out"
}

:<<'FUN'
The body that opens a pull request: title, head, base, body, assignees and
labels out of the options $1, a field with no value left out.
FUN
__forgejo__pull_request_body() {
  @pick __forgejo__pull_request_body__fields "$1" title head base body assignees labels
  @filter __forgejo__pull_request_body__given "$__forgejo__pull_request_body__fields" forge__base__member_is_set
  @dump __forgejo__pull_request_body__out "$__forgejo__pull_request_body__given"
  println "$__forgejo__pull_request_body__out"
}

:<<'FUN'
The title and body a caller asked to change, as Forgejo's REST fields. An empty
field is omitted so a PATCH never blanks one it was not given.
FUN
__forgejo__pull_request_update_body() {
  @let "$1" __forgejo__pull_request_update_body__ title body
  @obj __forgejo__pull_request_update_body__out

  if @defined "$__forgejo__pull_request_update_body__title"; then
    @set __forgejo__pull_request_update_body__out \
        "$__forgejo__pull_request_update_body__out" \
        '.title' \
        "$__forgejo__pull_request_update_body__title"
  fi

  if @defined "$__forgejo__pull_request_update_body__body"; then
    @set __forgejo__pull_request_update_body__out \
        "$__forgejo__pull_request_update_body__out" \
        '.body' \
        "$__forgejo__pull_request_update_body__body"
  fi

  @unlet __forgejo__pull_request_update_body__ title body
  println "$__forgejo__pull_request_update_body__out"
}
