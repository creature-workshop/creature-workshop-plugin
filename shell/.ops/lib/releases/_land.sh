#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/bump/api.sh" \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/git/tags.sh" \
  "$SHELLOPS_DIR/lib/releases/record/api.sh" \
  "$SHELLOPS_DIR/lib/releases/_tested.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
The trunk's job after a landing: check C, then the merge commit at the tip
tagged dev directly, and nothing committed (ADR.3@global, ADR.44@shellops).
Check C holds the landing to the tree its landing run validated
(lib/releases/_tested.sh); a landing it refuses earns no tag. The version
is the one the trunk's lock names or the one the reviews merged since
the last stable earn, whichever is higher, and the tag's name is the next
the format the repository writes gives that version on dev, read off the
tags (versions__format__tag_name); the tag is pushed on its own, and a
name another run took first is retried past, since a tag that exists
cannot be pushed again (ADR.17@global). This is the job of a repository
whose format names what the trunk holds (versions__format__has_trunk_name):
the version and dev alone in the counter format, a name no tag ever
carries, so the tags alone carry the count.
MODULE

# CONST: The tier a landing earns, the one the trunk's lock names.
__releases__land__TIER="dev"

: <<'PUB_FUN'
Holds HEAD, the landing at the trunk's tip, to check C, then tags it as the
next dev prerelease of the version the trunk is on, pushes the tag to
origin, and prints it. Fails when the landing is not the tree its run
validated, when the lock holds anything but a version and dev, when the
version cannot be planned, or when the push is refused RELEASE_PUSH_ATTEMPTS
times over.

  releases__release_land  ->  0.67.0-4.dev

Usage: releases__release_land
PUB_FUN
releases__release_land() {
  releases__tested__assert HEAD || return 1
  __releases__release_land__version="$(releases__land__version)" || return 1
  log "Landing: the trunk is on ${__releases__release_land__version}."

  releases__land__tag "$__releases__release_land__version"
}

: <<'PUB_FUN'
Prints the version a landing on the trunk is on: the one the lock names,
or the last stable moved by the level the reviews merged since it declare,
whichever is higher (ADR.17@global). The lock is the floor a person
set; the labels raise it when the work since the stable earns more, and the
lock catches up through a version bump of its own. Fails when the
lock holds anything but a version and dev alone, or the forge cannot be
asked.

  releases__land__version  ->  0.67.0   (lock 0.67.0-dev, last stable 0.65.0, a feature since)
  releases__land__version  ->  0.66.0   (lock 0.65.1-dev, last stable 0.65.0, a feature since)

Usage: releases__land__version
PUB_FUN
releases__land__version() {
  __releases__land__version__named="$(releases__land__manifest_version)" || return 1
  __releases__land__version__earned="$(releases__land__earned_version)" || return 1

  if @is_true "$(versions__version_is_newer "$__releases__land__version__earned" "$__releases__land__version__named")"; then
    log "The reviews merged since the last stable earn ${__releases__land__version__earned}, past the ${__releases__land__version__named} the lock names."
    println "$__releases__land__version__earned"
    return 0
  fi

  println "$__releases__land__version__named"
}

: <<'PUB_FUN'
Prints the version the trunk's lock names, and fails naming what it
holds when that is not what the format the repository writes has the trunk
hold for the version on dev (versions__format__trunk_name): on the trunk
the lock carries no count and no other tier (ADR.44@shellops).

  releases__land__manifest_version  ->  0.67.0   (latest 0.67.0-dev, version-format: counter)

Usage: releases__land__manifest_version
PUB_FUN
releases__land__manifest_version() {
  __releases__land__manifest_version__latest="$(releases__record__get_latest)" || return 1
  __releases__land__manifest_version__version="$(versions__version_of "$__releases__land__manifest_version__latest")" || return 1
  __releases__land__manifest_version__trunk="$(versions__format__trunk_name "$__releases__land__manifest_version__version" "$__releases__land__TIER")" || return 1

  if [ "$__releases__land__manifest_version__latest" != "$__releases__land__manifest_version__trunk" ]; then
    error "release land: the trunk's lock holds ${__releases__land__manifest_version__latest}; on the trunk it holds the version and dev alone, ${__releases__land__manifest_version__trunk}, and a tag's name only on a record off it (ADR.44@shellops)."
    return 1
  fi

  println "$__releases__land__manifest_version__version"
}

: <<'PUB_FUN'
Prints the version the reviews merged since the last stable earn: the
stable's numbers moved at the level their labels declare, and 0.0.0 moved
when no stable was ever cut, so the window then is the whole history. Fails
when the forge cannot be asked.

  releases__land__earned_version  ->  0.66.0   (last stable 0.65.0, a type/feature review since)

Usage: releases__land__earned_version
PUB_FUN
releases__land__earned_version() {
  __releases__land__earned_version__stable="$(versions__latest_release_version)"
  __releases__land__earned_version__since="$(__releases__land__stable_date "$__releases__land__earned_version__stable")"
  __releases__land__earned_version__reviews="$(forge__merged_reviews_since "$__releases__land__earned_version__since" "$(forge__default_branch)")" || return 1
  __releases__land__earned_version__labels="$(bump__aggregate_code_review_labels "$__releases__land__earned_version__reviews")" || return 1

  bump__version_at_level "${__releases__land__earned_version__stable:-0.0.0}" "$__releases__land__earned_version__labels"
}

: <<'FUN'
Prints when the stable <version> was tagged, in whichever form the tag was
written, and nothing for no stable at all, which leaves the window open.
FUN
__releases__land__stable_date() {
  if ! @defined "$1"; then
    printf '\n'
    return 0
  fi

  git__tag_date "$(versions__tag_for_version "$1")"
}

: <<'PUB_FUN'
Tags HEAD as the next dev prerelease of <version> and pushes the tag on its
own, printing it. The name is read off origin's tags fresh before each
attempt (versions__format__tag_name), so a run racing this one for the same
name loses the push and not the landing: the tag it took is dropped here
and the next name tried, up to RELEASE_PUSH_ATTEMPTS times. Fails when
every attempt is refused.

  releases__land__tag 0.67.0  ->  0.67.0-4.dev   (version-format: counter)

Usage: releases__land__tag <version>
PUB_FUN
releases__land__tag() {
  __releases__land__tag__attempt=1

  while : ; do
    git__remotes__fetch_tags origin || return 1
    __releases__land__tag__name="$(versions__format__tag_name "$1" "$__releases__land__TIER")" || return 1
    git__tag_annotate "$__releases__land__tag__name" || return 1

    if git__push_tag origin "$__releases__land__tag__name"; then
      log "Tagged the landing ${__releases__land__tag__name}; its tag's pipeline publishes it."
      println "$__releases__land__tag__name"
      return 0
    fi

    git__tag_delete "$__releases__land__tag__name"
    if [ "$__releases__land__tag__attempt" -ge "$RELEASE_PUSH_ATTEMPTS" ]; then
      fatal "release land: the tag was refused ${RELEASE_PUSH_ATTEMPTS} times over; the next name of ${1} kept being taken."
      return 1
    fi

    __releases__land__tag__attempt=$((__releases__land__tag__attempt + 1))
    log "The push of ${__releases__land__tag__name} was refused: another run took the name. Trying the next (attempt ${__releases__land__tag__attempt}/${RELEASE_PUSH_ATTEMPTS})."
  done
}
