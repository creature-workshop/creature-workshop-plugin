#!/bin/sh

:<<'FRAGMENT'
Releases on a GitHub repository: the one a tag carries.
FRAGMENT

:<<'PUB_FUN'
Prints the release the repository holds for the tag .tag names, as GitHub
describes it, and nothing when the tag has no release, which is an answer
and not a failure. A refusal that is not absence, a bad token say, fails
with the request's own message.

Usage: github__release_for_tag "$repo_options"
PUB_FUN
github__release_for_tag() {
  __github__release_for_tag__token="$(__github__validate_token "$1")" || return 1
  __github__release_for_tag__endpoint="$(__github__release_by_tag_endpoint "$1")"

  forge__base__probe "$__github__release_for_tag__endpoint" "$(__github__http_opts "$__github__release_for_tag__token")"
}
