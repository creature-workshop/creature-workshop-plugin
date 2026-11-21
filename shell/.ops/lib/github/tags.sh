#!/bin/sh

:<<'FRAGMENT'
Tags on a GitHub repository: whether one exists, the wait for a mirrored one to
arrive, and the v* and release tags it carries.
FRAGMENT

:<<'PUB_FUN'
Checks whether a tag ref exists on a GitHub repository.
Returns 0 if the tag exists, 1 otherwise.

Usage: github__tag_exists "$repo_options"
PUB_FUN
github__tag_exists() {
  __github__tag_exists__token="$(__github__validate_token "$1")" || return 1
  __github__tag_exists__http_opts="$(__github__http_opts "$__github__tag_exists__token")"
  __github__tag_exists__endpoint="$(__github__tag_ref_endpoint "$1")"

  http__get "$__github__tag_exists__endpoint" "$__github__tag_exists__http_opts" > /dev/null 2>&1
}

:<<'PUB_FUN'
Lists all v* tags on a GitHub repository.

Usage: github__list_tags "$repo_options"
PUB_FUN
github__list_tags() {
  @let "$1" __github__list_tags__ owner repo
  __github__list_tags__token="$(__github__validate_token "$1")" || return 1
  __github__list_tags__http_opts="$(__github__http_opts "$__github__list_tags__token")"

  __github__list_tags__response="$(http__get \
    "${__github__BASE}/repos/${__github__list_tags__owner}/${__github__list_tags__repo}/tags?per_page=100" \
    "$__github__list_tags__http_opts")"
  @unlet __github__list_tags__ owner repo

  @pluck __github__list_tags__pluck_1 "$__github__list_tags__response" '.name'
  @filter __github__list_tags__filter_2 "$__github__list_tags__pluck_1" silt__text_starts_with . v
  @join __github__list_tags__out "$__github__list_tags__filter_2" "$__github__NL"
  println "$__github__list_tags__out"
}

:<<'PUB_FUN'
Lists all release tag names on a GitHub repository.

Usage: github__list_release_tags "$repo_options"
PUB_FUN
github__list_release_tags() {
  @let "$1" __github__list_release_tags__ owner repo
  __github__list_release_tags__token="$(__github__validate_token "$1")" || return 1
  __github__list_release_tags__http_opts="$(__github__http_opts "$__github__list_release_tags__token")"

  __github__list_release_tags__response="$(http__get \
    "${__github__BASE}/repos/${__github__list_release_tags__owner}/${__github__list_release_tags__repo}/releases?per_page=100" \
    "$__github__list_release_tags__http_opts")"
  @unlet __github__list_release_tags__ owner repo

  @pluck __github__list_release_tags__pluck_3 "$__github__list_release_tags__response" '.tag_name'
  @join __github__list_release_tags__out "$__github__list_release_tags__pluck_3" "$__github__NL"
  println "$__github__list_release_tags__out"
}

:<<'PUB_FUN'
Prints true when the repository holds the tag .tag names and false when it
does not, which is an answer and not a failure: a mirrored tag arrives on the
mirror's own clock. A refusal that is not absence, a bad token say, fails
with the request's own message.

Usage: github__tag_carried "$repo_options"
PUB_FUN
github__tag_carried() {
  __github__tag_carried__token="$(__github__validate_token "$1")" || return 1
  __github__tag_carried__endpoint="$(__github__tag_ref_endpoint "$1")"
  __github__tag_carried__ref="$(forge__base__probe "$__github__tag_carried__endpoint" "$(__github__http_opts "$__github__tag_carried__token")")" || return 1

  @succeeds __github__tag_carried__out @defined "$__github__tag_carried__ref"
  println "$__github__tag_carried__out"
}

:<<'PUB_FUN'
Waits until the repository holds the tag .tag names, looking every .interval
seconds for at most .timeout seconds, the ceiling a push mirror's update
window sets. Fails once the wait runs out, or when the repository cannot be
asked; it never creates the tag itself, since a tag GitHub does not carry is
one the mirror has not sent.

Usage: github__wait_for_tag "$repo_options"
PUB_FUN
github__wait_for_tag() {
  @get __github__wait_for_tag__tag "$1" '.tag' ''
  @get __github__wait_for_tag__timeout "$1" '.timeout' 420
  @get __github__wait_for_tag__interval "$1" '.interval' 15
  __github__wait_for_tag__polls="$(forge__base__polls "$__github__wait_for_tag__timeout" "$__github__wait_for_tag__interval")"
  __github__wait_for_tag__poll=0

  while :; do
    __github__wait_for_tag__carried="$(github__tag_carried "$1")" || return 1
    __github__wait_for_tag__poll=$(( __github__wait_for_tag__poll + 1 ))

    if @is_true "$__github__wait_for_tag__carried"; then
      log "GitHub holds $__github__wait_for_tag__tag"
      return 0
    fi

    if [ "$__github__wait_for_tag__poll" -ge "$__github__wait_for_tag__polls" ]; then
      error "Timed out after ${__github__wait_for_tag__timeout}s waiting for the tag $__github__wait_for_tag__tag to reach GitHub"
      return 1
    fi

    sleep "$__github__wait_for_tag__interval"
  done
}
