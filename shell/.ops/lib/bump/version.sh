#!/bin/sh

:<<'FRAGMENT'
What a plan does to the version struct lib/versions/api.sh parses for it: bump
it at a level, put it on a tier, and drop its prerelease part. A move that
writes a prerelease part writes it in the format the repository's manifest
declares (versions__format, lib/versions/_format.sh).

Its own module because every planner beside it is built from these moves
and none of them owns one.

  __bump__apply_bump <0.63.3> minor      ->  <0.64.0>
  __bump__with_tier <0.63.4-3.dev> alpha ->  <0.63.4-alpha>   (version-format: counter)
FRAGMENT

: <<'FUN'
Takes a version struct + level (major|minor|patch); echoes the bumped struct.
An unknown level echoes the struct unchanged.
FUN
__bump__apply_bump() {
  __bump__apply_bump__version="$1"
  __bump__apply_bump__level="$2"

  case "$__bump__apply_bump__level" in
    major)
      @get __bump__apply_bump__get_1 "$__bump__apply_bump__version" '.major' 0
      __bump__apply_bump__next="$(( __bump__apply_bump__get_1 + 1 ))"
      @set __bump__apply_bump__out "$__bump__apply_bump__version" '.major' "$__bump__apply_bump__next" '.minor' 0 '.patch' 0
      println "$__bump__apply_bump__out"
      ;;
    minor)
      @get __bump__apply_bump__get_2 "$__bump__apply_bump__version" '.minor' 0
      __bump__apply_bump__next="$(( __bump__apply_bump__get_2 + 1 ))"
      @set __bump__apply_bump__out "$__bump__apply_bump__version" '.minor' "$__bump__apply_bump__next" '.patch' 0
      println "$__bump__apply_bump__out"
      ;;
    patch)
      @get __bump__apply_bump__get_3 "$__bump__apply_bump__version" '.patch' 0
      __bump__apply_bump__next="$(( __bump__apply_bump__get_3 + 1 ))"
      @set __bump__apply_bump__out "$__bump__apply_bump__version" '.patch' "$__bump__apply_bump__next"
      println "$__bump__apply_bump__out"
      ;;
    *)
      println "$__bump__apply_bump__version"
      ;;
  esac
}

: <<'FUN'
Takes a version struct; echoes the struct with any prerelease part removed,
a clean version.
FUN
__bump__clear_prerelease() {
  versions__with_prerelease "$1" ""
}

: <<'FUN'
Takes a version struct and a tier; echoes the struct opening a series on
the tier, as the format the repository writes spells it: the tier's first
count in the increment format, the tier alone in the counter format, whose
count the tags hand out (ADR.17@global). Fails when the manifest declares a
format no plugin spells.

  __bump__with_tier <0.63.4>        dev    ->  <0.63.4-dev.1>    (version-format: increment)
  __bump__with_tier <0.63.4-dev.3>  alpha  ->  <0.63.4-alpha.1>  (version-format: increment)
  __bump__with_tier <0.63.4-3.dev>  alpha  ->  <0.63.4-alpha>    (version-format: counter)
FUN
__bump__with_tier() {
  __bump__with_tier__format="$(versions__format)" || return 1
  __bump__with_tier__part="$(versions__format__call "$__bump__with_tier__format" open "$2")" || return 1

  versions__with_prerelease "$1" "$__bump__with_tier__part"
}

: <<'FUN'
Takes a prerelease version struct; echoes the struct moved on along its
tier, as the format the repository writes moves it: one count on in the
increment format, the tier alone in the counter format, where the tags hand
out the next count. Fails when the manifest declares a format no plugin
spells.

  __bump__move_on_tier <2.0.0-alpha.2>  ->  <2.0.0-alpha.3>  (version-format: increment)
  __bump__move_on_tier <2.0.0-3.alpha>  ->  <2.0.0-alpha>    (version-format: counter)
FUN
__bump__move_on_tier() {
  __bump__move_on_tier__format="$(versions__format)" || return 1
  @let "$1" __bump__move_on_tier__ pre_type pre_inc
  __bump__move_on_tier__part="$(versions__format__call "$__bump__move_on_tier__format" bump \
    "$__bump__move_on_tier__pre_type" \
    "$__bump__move_on_tier__pre_inc"
  )"
  __bump__move_on_tier__status=$?
  @unlet __bump__move_on_tier__ pre_type pre_inc
  [ "$__bump__move_on_tier__status" -eq 0 ] || return 1

  versions__with_prerelease "$1" "$__bump__move_on_tier__part"
}

: <<'FUN'
Takes a prerelease version struct; echoes the prerelease a merge on it lands
on when no label moves it, dev gravity, as the format the repository writes
spells it: in the increment format the next dev, or the first dev no tag of
the version holds from another tier; in the counter format dev alone. Fails
when the manifest declares a format no plugin spells.

  __bump__gravitate_to_dev <2.0.0-dev.5>    ->  <2.0.0-dev.6>          (version-format: increment)
  __bump__gravitate_to_dev <2.0.0-alpha.1>  ->  <2.0.0-dev.N>, N free  (version-format: increment)
  __bump__gravitate_to_dev <2.0.0-3.alpha>  ->  <2.0.0-dev>            (version-format: counter)
FUN
__bump__gravitate_to_dev() {
  __bump__gravitate_to_dev__format="$(versions__format)" || return 1
  @let "$1" __bump__gravitate_to_dev__ major minor patch pre_type pre_inc
  __bump__gravitate_to_dev__part="$(versions__format__call "$__bump__gravitate_to_dev__format" dev \
    "$__bump__gravitate_to_dev__major.$__bump__gravitate_to_dev__minor.$__bump__gravitate_to_dev__patch" \
    "$__bump__gravitate_to_dev__pre_type" \
    "$__bump__gravitate_to_dev__pre_inc"
  )"
  __bump__gravitate_to_dev__status=$?
  @unlet __bump__gravitate_to_dev__ major minor patch pre_type pre_inc
  [ "$__bump__gravitate_to_dev__status" -eq 0 ] || return 1

  versions__with_prerelease "$1" "$__bump__gravitate_to_dev__part"
}
