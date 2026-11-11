#!/bin/sh

:<<'FRAGMENT'
Assigning a GitLab merge request to the people named by their usernames.

GitLab's mutations address a user by a global id, which a caller holding a
username would have to look up first. The /assign quick action takes the
mention instead, so this spells the assignment the way a person types it.
FRAGMENT

:<<'PUB_FUN'
Assigns merge request .review_number of the project the options name to every
username in the struct array $2, and does nothing at all when that array is
empty. The options carry .token, and .owner/.repo where the manifest is not
the project being written to.

Usage: gitlab__assign_review '{"review_number":"12","token":"t"}' '["blizz"]'
PUB_FUN
gitlab__assign_review() {
  if @len __gitlab__assign_review__len_1 "$2"; [ "$__gitlab__assign_review__len_1" -eq 0 ]; then
    return 0
  fi

  @map __gitlab__assign_review__mentions __gitlab__mention_of "$2"
  @join __gitlab__assign_review__join_2 "$__gitlab__assign_review__mentions" " "
  __gitlab__assign_review__action="/assign $__gitlab__assign_review__join_2"

  gitlab__create_mr_comment \
    "$(__gitlab__normalize_review_options "$1")" \
    "$__gitlab__assign_review__action" \
    > /dev/null
}

:<<'FUN'
One username as the mention GitLab resolves to that user. @map hands each
element over still JSON-encoded, so the name is unwrapped before the mention
is spelled.

Usage: __gitlab__mention_of '"blizz"'   # -> @blizz
FUN
__gitlab__mention_of() {
  @unwrap __gitlab__mention_of__unwrap_3 "$1"
  printf '@%s\n' "$__gitlab__mention_of__unwrap_3"
}
