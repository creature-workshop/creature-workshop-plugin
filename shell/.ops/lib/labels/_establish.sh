#!/bin/sh

:<<'MODULE'
Creates, on the project, the area/* label of every area a review touches
that the project does not define yet, so the precise label can be applied
on the review's first labels run.

GitLab drops an add for a label the project does not define, and the area
labels are otherwise created only by `forge sync-labels` when a release is
cut. Between the two, a review that adds a new area to the testmap falls
back to area/new on every run, and the test dispatch turns area/new with no
net-new file into the full suite. Creating the label at review time closes
that gap.

The label takes the colour and description that `forge sync-labels` would
give it, read from the merged label set, so the release-time sync finds
nothing to change.

Usage:
  import "$SHELLOPS_DIR/lib/labels/_establish.sh"

  established="$(labels__establish "$changed" "$established" "$base" "$project" "$token")"
MODULE

import \
  "$SHELLOPS_DIR/lib/labels/_names.sh" \
  "$SHELLOPS_DIR/lib/labels/api.sh" \
  "$SHELLOPS_DIR/lib/testing/resolver.sh" \
  "$SHELLOPS_DIR/lib/areas/api.sh" \
  "$SHELLOPS_DIR/lib/http/api.sh"

:<<'PUB_FUN'
Prints the established area/* labels with the review's missing ones added,
after creating each missing one on the project. A label whose create fails
stays missing, so the plan falls back to area/new for it as before.

  changed      [<file>, ...]  the review's changed files, repo-relative
  established  [<label>, ...] the area/* labels the project defines
  api_base     GitLab REST v4 base
  project_id   numeric project id
  token        write-scoped token

Usage: labels__establish "$changed" "$established" "$base" "$project" "$token"
PUB_FUN
labels__establish() {
  __labels__establish__missing="$(__labels__establish__missing "$1" "$2")"
  if @len __labels__establish__len_1 "$__labels__establish__missing"; [ "$__labels__establish__len_1" -eq 0 ]; then
    println "$2"
    return 0
  fi

  __labels__establish__records="$(labels__flatten_labels "$(labels__merged_labels)")" || {
    println "$2"
    return 0
  }

  @reduce __labels__establish__out __labels__establish__create_one \
    "$__labels__establish__missing" \
    "$2" \
    "$__labels__establish__records" \
    "$3" "$4" "$5"
  println "$__labels__establish__out"
}

:<<'FUN'
Prints the precise area/* labels of the areas the review touches that are
not in the established set.

  $1 changed   $2 established
FUN
__labels__establish__missing() {
  __labels__establish__missing__config="$(areas__load_areas_config)"
  if ! @defined "$__labels__establish__missing__config"; then
    @arr __labels__establish__missing__out
    println "$__labels__establish__missing__out"
    return 0
  fi

  __labels__establish__missing__areas="$(areas__compute_areas "$__labels__establish__missing__config")" || {
    @arr __labels__establish__missing__out
    println "$__labels__establish__missing__out"
    return 0
  }
  __labels__establish__missing__names="$(testing__areas_for_paths "$__labels__establish__missing__areas" "$1")"
  @difference __labels__establish__missing__out "$(labels__from_areas "$__labels__establish__missing__names")" "$2"
  println "$__labels__establish__missing__out"
}

:<<'FUN'
@reduce callback: creates the label $2 on the project and prints the
established set $1 with it added; prints $1 unchanged when the label has no
record in the merged set or the create fails.

  $1 accumulator (established labels)   $2 the label name (wrapped)
  $3 the flat label records   $4 api_base   $5 project_id   $6 token
FUN
__labels__establish__create_one() {
  @unwrap __labels__establish__create_one__name "$2"
  @find __labels__establish__create_one__record __labels__establish__named "$3" "$__labels__establish__create_one__name"
  if ! @defined "$__labels__establish__create_one__record"; then
    log "labels/apply: $__labels__establish__create_one__name has no record in the label set; leaving it to area/new."
    println "$1"
    return 0
  fi

  if ! __labels__establish__send_create "$4" "$5" "$6" "$__labels__establish__create_one__record" >/dev/null; then
    log "labels/apply: could not create $__labels__establish__create_one__name on the project; leaving it to area/new."
    println "$1"
    return 0
  fi

  log "labels/apply: created $__labels__establish__create_one__name on the project."
  @push __labels__establish__create_one__out "$1" "$__labels__establish__create_one__name"
  println "$__labels__establish__create_one__out"
}

:<<'FUN'
@find callback: true when the label record $1 is named $2.
FUN
__labels__establish__named() {
  @get __labels__establish__named__get_2 "$1" '.name'
  [ "$__labels__establish__named__get_2" = "$2" ]
}

:<<'FUN'
Network seam: issues the GitLab "create label" REST call for one record.
Isolated as its own function so tests can stub it without a live API.

  $1 api_base   $2 project_id   $3 token   $4 the record ({name, color, description})
FUN
__labels__establish__send_create() {
  __labels__establish__send_create__url="${1}/projects/${2}/labels"
  @obj __labels__establish__send_create__opts '.auth' "Bearer $3"

  http__post \
    "$__labels__establish__send_create__url" \
    "$4" \
    "$__labels__establish__send_create__opts"
}
