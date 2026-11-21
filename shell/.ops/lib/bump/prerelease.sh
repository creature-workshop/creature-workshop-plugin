#!/bin/sh

:<<'FRAGMENT'
Prerelease planning: the prerelease a merge lands on, and the ladder it climbs.
dev, alpha, beta and rc rank in that order; meta/promote moves a version one
rung up and off the ladder past rc, a label naming a level above the one the
version targets retargets it to a fresh dev at the higher base, and an ops
git-bump flag names its channel outright.

A plan writes the prerelease part in the format the repository's manifest
declares (lib/versions/_format.sh). The increment format moves its own
count; in the counter format the count is the version's counter, handed
out by the tags when a tag is cut (ADR.17@global), so a plan there names
the version and the tier and nothing more: 0.67.0-3.alpha promotes to
0.67.0-beta.

  __bump__channel_order beta  ->  2
  __bump__channel_at 3        ->  rc
FRAGMENT

: <<'FUN'
Maps a prerelease channel to its order rank (dev<alpha<beta<rc). Unknown
channels rank 0. Backed by a struct literal read through @get.
FUN
__bump__channel_order() {
  @get __bump__channel_order__out '{"dev":0,"alpha":1,"beta":2,"rc":3}' "$1" 0
  println "$__bump__channel_order__out"
}

: <<'FUN'
Inverse of __bump__channel_order: maps an order index back to its channel
name. Indices outside 0-3 echo nothing.
FUN
__bump__channel_at() {
  case "$1" in
    0) echo "dev" ;;
    1) echo "alpha" ;;
    2) echo "beta" ;;
    3) echo "rc" ;;
  esac
}

: <<'FUN'
Takes a version struct + options; echoes the struct with the requested
prerelease channel applied: moved on along the channel when the version is
already on it (__bump__move_on_tier), and opening the channel otherwise
(__bump__with_tier).
FUN
__bump__plan_flag_prerelease() {
  __bump__plan_flag_prerelease__version="$1"
  __bump__plan_flag_prerelease__options="$2"

  __bump__plan_flag_prerelease__target="$(__bump__prerelease_type "$__bump__plan_flag_prerelease__options")"
  @let "$__bump__plan_flag_prerelease__version" __bump__plan_flag_prerelease__ pre_type patch
  @defined "$__bump__plan_flag_prerelease__patch" || __bump__plan_flag_prerelease__patch=0

  if [ "$__bump__plan_flag_prerelease__target" = "$__bump__plan_flag_prerelease__pre_type" ]; then
    __bump__move_on_tier "$__bump__plan_flag_prerelease__version"
    return
  fi

  if ! @defined "$__bump__plan_flag_prerelease__pre_type" \
    && @is_false "$(__bump__is_release_bump "$__bump__plan_flag_prerelease__options")"; then
    @set __bump__plan_flag_prerelease__version "$__bump__plan_flag_prerelease__version" '.patch' "$((__bump__plan_flag_prerelease__patch + 1))"
  fi

  if @is_true "$(__bump__is_release_bump "$__bump__plan_flag_prerelease__options")"; then
    __bump__plan_flag_prerelease__release_type="$(__bump__release_type "$__bump__plan_flag_prerelease__options")"
    __bump__plan_flag_prerelease__version="$(__bump__apply_bump "$__bump__plan_flag_prerelease__version" "$__bump__plan_flag_prerelease__release_type")"
  fi

  __bump__with_tier "$__bump__plan_flag_prerelease__version" "$__bump__plan_flag_prerelease__target"
  __bump__plan_flag_prerelease__status=$?
  @unlet __bump__plan_flag_prerelease__ pre_type patch
  return "$__bump__plan_flag_prerelease__status"
}

: <<'FUN'
Takes a version struct + labels + bump level; echoes the planned struct.
FUN
__bump__plan_prerelease() {
  __bump__plan_prerelease__version="$1"
  __bump__plan_prerelease__labels="$2"
  __bump__plan_prerelease__level="$3"
  __bump__plan_prerelease__retargeted=false

  if __bump__needs_retarget "$__bump__plan_prerelease__version" "$__bump__plan_prerelease__level"; then
    __bump__plan_prerelease__version="$(__bump__retarget "$__bump__plan_prerelease__version" "$__bump__plan_prerelease__level")"
    __bump__plan_prerelease__retargeted=true
  fi

  if @is_true "$(__bump__has_label "$__bump__plan_prerelease__labels" "meta/release")"; then
    __bump__clear_prerelease "$__bump__plan_prerelease__version"
    return
  fi

  if @is_true "$(__bump__has_label "$__bump__plan_prerelease__labels" "meta/promote")"; then
    __bump__promote_channel "$__bump__plan_prerelease__version"
    return
  fi

  if [ "$__bump__plan_prerelease__retargeted" = true ]; then
    println "$__bump__plan_prerelease__version"
    return
  fi

  __bump__gravitate_to_dev "$__bump__plan_prerelease__version"
}

: <<'FUN'
Takes a version struct; echoes the struct promoted to the next channel, as
__bump__with_tier puts it there, or stripped to stable when promoting past
rc.
FUN
__bump__promote_channel() {
  __bump__promote_channel__version="$1"
  @get __bump__promote_channel__channel "$__bump__promote_channel__version" '.pre_type' ''
  __bump__promote_channel__order="$(__bump__channel_order "$__bump__promote_channel__channel")"
  __bump__promote_channel__next_order=$((__bump__promote_channel__order + 1))

  if [ "$__bump__promote_channel__next_order" -gt 3 ]; then
    __bump__clear_prerelease "$__bump__promote_channel__version"
    return
  fi

  __bump__promote_channel__next_channel="$(__bump__channel_at "$__bump__promote_channel__next_order")"
  __bump__with_tier "$__bump__promote_channel__version" "$__bump__promote_channel__next_channel"
}

: <<'FUN'
Returns 0 when the inferred bump level outranks the current prerelease
target level (and a retarget is therefore needed).
FUN
__bump__needs_retarget() {
  __bump__needs_retarget__version="$1"
  __bump__needs_retarget__level="$2"

  __bump__needs_retarget__current_level="$(__bump__current_target_level "$__bump__needs_retarget__version")"

  __bump__needs_retarget__bump_rank="$(__bump__level_rank "$__bump__needs_retarget__level")"
  __bump__needs_retarget__current_rank="$(__bump__level_rank "$__bump__needs_retarget__current_level")"
  [ "$__bump__needs_retarget__bump_rank" -gt "$__bump__needs_retarget__current_rank" ]
}

: <<'FUN'
Takes a version struct + bump level; echoes the struct retargeted to a fresh
dev at the bumped base, opened as __bump__with_tier opens it.

  __bump__retarget <1.2.1-dev.4> minor  ->  <1.3.0-dev.1>  (version-format: increment)
  __bump__retarget <1.2.1-dev> minor    ->  <1.3.0-dev>    (version-format: counter)
FUN
__bump__retarget() {
  __bump__retarget__version="$(__bump__reset_to_base "$1")"
  __bump__retarget__version="$(__bump__apply_bump "$__bump__retarget__version" "$2")"

  __bump__with_tier "$__bump__retarget__version" dev
}

: <<'FUN'
Takes a version struct; echoes the struct rewound by one increment of its
current target level (so a subsequent apply_bump lands on the same number).
FUN
__bump__reset_to_base() {
  __bump__reset_to_base__version="$1"
  __bump__reset_to_base__level="$(__bump__current_target_level "$__bump__reset_to_base__version")"

  case "$__bump__reset_to_base__level" in
    patch)
      @get __bump__reset_to_base__patch "$__bump__reset_to_base__version" '.patch' 0
      @set __bump__reset_to_base__out "$__bump__reset_to_base__version" '.patch' "$((__bump__reset_to_base__patch - 1))"
      println "$__bump__reset_to_base__out"
      ;;
    minor)
      @get __bump__reset_to_base__minor "$__bump__reset_to_base__version" '.minor' 0
      @set __bump__reset_to_base__out "$__bump__reset_to_base__version" '.minor' "$((__bump__reset_to_base__minor - 1))" '.patch' 0
      println "$__bump__reset_to_base__out"
      ;;
    major)
      @get __bump__reset_to_base__major "$__bump__reset_to_base__version" '.major' 0
      @set __bump__reset_to_base__out "$__bump__reset_to_base__version" '.major' "$((__bump__reset_to_base__major - 1))" '.minor' 0 '.patch' 0
      println "$__bump__reset_to_base__out"
      ;;
    *)
      println "$__bump__reset_to_base__version"
      ;;
  esac
}
