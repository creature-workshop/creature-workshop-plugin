#!/bin/sh

:<<'FRAGMENT'
What the git tags leave free: whether a version is already tagged, and the
first slot at a bump level that no tag holds.

Its own module because this is the one place the planners leave the version
struct and ask the repository a question. A tag counts in either form, bare or
v-prefixed, since a repository may carry either or be mid-move, and a repo with
no tags at all answers every question with "free".
FRAGMENT

:<<'FUN'
Prints the struct boolean for whether a tag records the version, bare or
v-prefixed.

Usage: if @is_true "$(__bump__tag_exists "1.2.3")"; then ... fi
FUN
__bump__tag_exists() {
  git tag -l "$1" "v$1" | { @succeeds __bump__tag_exists__out grep -q .; println "$__bump__tag_exists__out"; }
}

: <<'FUN'
Advances past any existing tags to find an available version slot,
incrementing at the requested bump level, a prerelease moving on along its
tier as the format the repository writes moves it (__bump__move_on_tier). A
tag holds its slot wherever its commit sits: a release above dev is recorded
off the trunk (ADR 000044), and git tag -l lists it where git describe from
the trunk never reaches it. Fails when a move hands back the name it was
given, since the tags then hold the next name and not the plan.
FUN
__bump__ensure_tag_available() {
  __bump__ensure_tag_available__version="$1"
  __bump__ensure_tag_available__options="$2"

  __bump__ensure_tag_available__parsed="$(versions__parse_version "$__bump__ensure_tag_available__version")"
  @get __bump__ensure_tag_available__pre_type "$__bump__ensure_tag_available__parsed" '.pre_type' ''

  if @defined "$__bump__ensure_tag_available__pre_type"; then
    __bump__ensure_tag_available__level="pre"
  else
    __bump__ensure_tag_available__level="$(__bump__release_type "$__bump__ensure_tag_available__options")"
    ! @defined "$__bump__ensure_tag_available__level" && __bump__ensure_tag_available__level="patch"
  fi

  while @is_true "$(__bump__tag_exists "$__bump__ensure_tag_available__version")"; do
    log "Tag ${__bump__ensure_tag_available__version} already exists, advancing..."
    case "$__bump__ensure_tag_available__level" in
      major)
        @get __bump__ensure_tag_available__get_1 "$__bump__ensure_tag_available__parsed" '.major' 0
        __bump__ensure_tag_available__next="$(( __bump__ensure_tag_available__get_1 + 1 ))"
        @set __bump__ensure_tag_available__parsed "$__bump__ensure_tag_available__parsed" '.major' "$__bump__ensure_tag_available__next" '.minor' 0 '.patch' 0
        ;;
      minor)
        @get __bump__ensure_tag_available__get_2 "$__bump__ensure_tag_available__parsed" '.minor' 0
        __bump__ensure_tag_available__next="$(( __bump__ensure_tag_available__get_2 + 1 ))"
        @set __bump__ensure_tag_available__parsed "$__bump__ensure_tag_available__parsed" '.minor' "$__bump__ensure_tag_available__next" '.patch' 0
        ;;
      pre)
        __bump__ensure_tag_available__parsed="$(__bump__move_on_tier "$__bump__ensure_tag_available__parsed")" || return 1
        ;;
      *)
        @get __bump__ensure_tag_available__get_3 "$__bump__ensure_tag_available__parsed" '.patch' 0
        __bump__ensure_tag_available__next="$(( __bump__ensure_tag_available__get_3 + 1 ))"
        @set __bump__ensure_tag_available__parsed "$__bump__ensure_tag_available__parsed" '.patch' "$__bump__ensure_tag_available__next"
        ;;
    esac

    __bump__ensure_tag_available__next="$(versions__format_version "$__bump__ensure_tag_available__parsed")"
    if [ "$__bump__ensure_tag_available__next" = "$__bump__ensure_tag_available__version" ]; then
      error "no name past ${__bump__ensure_tag_available__version} to advance to: the tags hand out the next"
      return 1
    fi
    __bump__ensure_tag_available__version="$__bump__ensure_tag_available__next"
  done

  echo "$__bump__ensure_tag_available__version"
}
