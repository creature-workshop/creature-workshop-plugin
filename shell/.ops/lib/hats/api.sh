#!/bin/sh
# shellcheck disable=SC2119  # bare @arr is the structs empty constructor

:<<'MODULE'
Hats: which lane owns a piece of work. A hat is a creature-workshop concept, not
a Linear or forge one, and this module is the one place its two spellings
meet: on a Linear issue it is a label under the `hat` group, on a code review
it is a hat/* label.

Both spellings have an older form this module still reads: a Linear label
group named `role`, and a role/* label on a code review. It writes only the
hat form.

Nothing here talks to either service. It reads issues already fetched and
prints label names, so an action decides when to look and what to do with the
answer.
MODULE

import "$SHELLOPS_DIR/lib/structs/api.sh"

__hats__GROUP="hat"
__hats__ROLE_GROUP="role"
__hats__PREFIX="hat/"
__hats__ROLE_PREFIX="role/"
__hats__UNKNOWN="unknown"

:<<'FUN'
A predicate for @filter: answers true in the variable $1 when the Linear
label $3 is under the `hat` group or under the `role` group, and false
otherwise.

  __hats__is_in_a_hat_group yes 0 '{"name":"ktlo","parent":{"name":"hat"}}'  ->  yes=true
FUN
__hats__is_in_a_hat_group() {
  @get __hats__is_in_a_hat_group__group "$3" '.parent.name' ''

  case "$__hats__is_in_a_hat_group__group" in
    "$__hats__GROUP" | "$__hats__ROLE_GROUP") @true "$1" ;;
    *) @false "$1" ;;
  esac
}

:<<'FUN'
A predicate for @filter: answers true in the variable $1 when the label
name $3 is a hat/* or a role/* label, and false otherwise.

  __hats__is_a_lane_label yes 0 '"hat/ktlo"'  ->  yes=true
FUN
__hats__is_a_lane_label() {
  @get __hats__is_a_lane_label__name "$3" '.' ''

  case "$__hats__is_a_lane_label__name" in
    "$__hats__PREFIX"* | "$__hats__ROLE_PREFIX"*) @true "$1" ;;
    *) @false "$1" ;;
  esac
}

:<<'PUB_FUN'
Prints the hats an issue carries, as a struct array: the names of its labels
under the `hat` group, or under the `role` group. Usually one or none. A
label named like a hat but outside either group is some other label and is
not listed.

  hats__of_issue "$issue"  ->  ["platform"]

Usage: hats__of_issue "$issue"
PUB_FUN
hats__of_issue() {
  @arr __hats__of_issue__arr_1
  @get __hats__of_issue__labels "$1" '.labels.nodes' "$__hats__of_issue__arr_1"
  @filter __hats__of_issue__grouped "$__hats__of_issue__labels" __hats__is_in_a_hat_group

  @pluck __hats__of_issue__out "$__hats__of_issue__grouped" '.name'
  println "$__hats__of_issue__out"
}

:<<'PUB_FUN'
Prints the one hat the issues agree on, or "unknown" when there is no such
hat: no issues, none of them carrying a hat, or two of them naming different
hats. An issue with no hat does not vote, so a ticket mentioned in passing
does not blank the hat the work's own ticket names.

  hats__hat_for_issues "$issues"  ->  platform

Usage: hats__hat_for_issues "$issues"
PUB_FUN
hats__hat_for_issues() {
  @arr __hats__hat_for_issues__arr_2
  @reduce __hats__hat_for_issues__hats __hats__add_issue_hats "$1" "$__hats__hat_for_issues__arr_2"
  @unique __hats__hat_for_issues__distinct "$__hats__hat_for_issues__hats"
  if @len __hats__hat_for_issues__len_3 "$__hats__hat_for_issues__distinct"; [ "$__hats__hat_for_issues__len_3" -ne 1 ]; then
    println "$__hats__UNKNOWN"
    return 0
  fi

  @first __hats__hat_for_issues__only "$__hats__hat_for_issues__distinct"

  @unwrap __hats__hat_for_issues__out "$__hats__hat_for_issues__only"
  println "$__hats__hat_for_issues__out"
}

:<<'FUN'
@reduce callback: the hats so far plus one more issue's.

  $1 hats so far   $2 the issue
FUN
__hats__add_issue_hats() {
  __hats__add_issue_hats__hats="$(hats__of_issue "$2")"

  @concat __hats__add_issue_hats__out "$1" "$__hats__add_issue_hats__hats"
  println "$__hats__add_issue_hats__out"
}

:<<'PUB_FUN'
Prints the hat/* label a code review referencing the issues should carry.

  hats__hat_label "$issues"  ->  hat/platform

Usage: hats__hat_label "$issues"
PUB_FUN
hats__hat_label() {
  __hats__hat_label__hat="$(hats__hat_for_issues "$1")"

  printf '%s%s\n' "$__hats__PREFIX" "$__hats__hat_label__hat"
}

:<<'PUB_FUN'
Prints the lane labels among a code review's label names, the hat/* and the
role/* ones, as a struct array, so a caller can count them or take off the
ones that no longer apply.

  hats__hat_labels_among '["area/cli","hat/ktlo","role/ktlo"]'  ->  ["hat/ktlo","role/ktlo"]

Usage: hats__hat_labels_among "$labels"
PUB_FUN
hats__hat_labels_among() {
  @filter __hats__hat_labels_among__out "$1" __hats__is_a_lane_label
  println "$__hats__hat_labels_among__out"
}
