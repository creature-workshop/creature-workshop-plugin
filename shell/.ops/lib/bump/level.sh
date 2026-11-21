#!/bin/sh

:<<'FRAGMENT'
Which bump level a merge is owed: the level its labels ask for, capped at minor
while the major is still 0, and the level a version's own numbers record as the
target its prerelease works toward. Ranking two levels tells a caller whether
one outranks the other.

  __bump__infer_bump_level '["type/feature"]' <1.2.3>     ->  minor
  __bump__infer_bump_level '["crit/breaking"]' <0.63.3>   ->  minor
  __bump__current_target_level <0.64.0-dev.1>             ->  minor
FRAGMENT

__bump__infer_bump_level() {
  __bump__infer_bump_level__labels="$1"
  __bump__infer_bump_level__version="$2"

  __bump__infer_bump_level__raw_level="$versions__LEVEL_PATCH"

  if @is_true "$(__bump__has_any_label "$__bump__infer_bump_level__labels" "crit/breaking" "crit/removal")"; then
    __bump__infer_bump_level__raw_level="$versions__LEVEL_MAJOR"
  elif @is_true "$(__bump__has_any_label "$__bump__infer_bump_level__labels" "type/feature" "area/new")"; then
    __bump__infer_bump_level__raw_level="$versions__LEVEL_MINOR"
  fi

  __bump__apply_pre10_ceiling "$__bump__infer_bump_level__raw_level" "$__bump__infer_bump_level__version"
}

__bump__apply_pre10_ceiling() {
  __bump__apply_pre10_ceiling__level="$1"
  __bump__apply_pre10_ceiling__version="$2"

  @get __bump__apply_pre10_ceiling__major "$__bump__apply_pre10_ceiling__version" '.major'
  if [ "$__bump__apply_pre10_ceiling__level" = "$versions__LEVEL_MAJOR" ] && [ "$__bump__apply_pre10_ceiling__major" = "0" ]; then
    println "$versions__LEVEL_MINOR"
    return
  fi

  echo "$__bump__apply_pre10_ceiling__level"
}

__bump__current_target_level() {
  @let "$1" __bump__current_target_level__ patch minor
  @defined "$__bump__current_target_level__patch" || __bump__current_target_level__patch=0
  @defined "$__bump__current_target_level__minor" || __bump__current_target_level__minor=0

  if [ "$__bump__current_target_level__patch" -gt 0 ]; then
    println "$versions__LEVEL_PATCH"
  elif [ "$__bump__current_target_level__minor" -gt 0 ]; then
    println "$versions__LEVEL_MINOR"
  else
    println "$versions__LEVEL_MAJOR"
  fi
  @unlet __bump__current_target_level__ patch minor
}

__bump__level_rank() {
  case "$1" in
    "$versions__LEVEL_PATCH") echo 1 ;;
    "$versions__LEVEL_MINOR") echo 2 ;;
    "$versions__LEVEL_MAJOR") echo 3 ;;
    *) echo 0 ;;
  esac
}

: <<'PUB_FUN'
Prints the clean version <version> moves to at the level the labels
<labels> declare: crit/* moves the major, type/feature or area/new the
minor, anything else the patch, capped at minor while the major is 0.
A prerelease part on <version> is dropped first, so the answer is the
version the labels earn over a stable.

  bump__version_at_level 0.65.0 '["type/feature"]'   ->  0.66.0
  bump__version_at_level 0.65.0 '["crit/breaking"]'  ->  0.66.0
  bump__version_at_level 0.65.0 '[]'                 ->  0.65.1
PUB_FUN
bump__version_at_level() {
  __bump__version_at_level__version="$(versions__parse_version "$1")" || return 1
  __bump__version_at_level__version="$(__bump__clear_prerelease "$__bump__version_at_level__version")"
  __bump__version_at_level__level="$(__bump__infer_bump_level "$2" "$__bump__version_at_level__version")"

  versions__format_version "$(__bump__apply_bump "$__bump__version_at_level__version" "$__bump__version_at_level__level")"
}
