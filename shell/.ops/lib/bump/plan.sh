#!/bin/sh

:<<'FRAGMENT'
The version ops git-bump plans against the repository it runs in:
manifest.json's version when that already outranks the newest tag, and
otherwise the bump the flags name -- or, with no flag at all, the dev-gravity
increment -- advanced to a slot no tag holds.

This is the planner a person runs by hand, so it reads the repository where
bump__compute_next_version is handed everything it needs.
FRAGMENT

bump__plan_bump() {
  __bump__plan_bump__options="$1"

  if __bump__plan_bump__current="$(bump__use_project_manifest)"; then
    __bump__plan_bump__planned="$__bump__plan_bump__current"
  else
    if ! versions__is_valid_semver "$__bump__plan_bump__current"; then
      error "Invalid version: $__bump__plan_bump__current"
      return 1
    fi

    __bump__plan_bump__version="$(versions__parse_version "$__bump__plan_bump__current")"

    if @is_true "$(__bump__is_prerelease_bump "$__bump__plan_bump__options")"; then
      __bump__plan_bump__version="$(__bump__plan_flag_prerelease "$__bump__plan_bump__version" "$__bump__plan_bump__options")" || return 1
    elif @is_true "$(__bump__is_release_bump "$__bump__plan_bump__options")" \
      || @is_true "$(__bump__is_releasing_prerelease "$__bump__plan_bump__version" "$__bump__plan_bump__options")"; then
      bump__check_release_safety "$__bump__plan_bump__current" "$__bump__plan_bump__options" || return 1
      __bump__plan_bump__release_type="$(__bump__release_type "$__bump__plan_bump__options")"
      __bump__plan_bump__version="$(__bump__apply_bump "$__bump__plan_bump__version" "$__bump__plan_bump__release_type")"
      __bump__plan_bump__version="$(__bump__clear_prerelease "$__bump__plan_bump__version")"
    else
      __bump__plan_bump__channel="$(bump__default_channel)" || return 1
      __bump__plan_bump__version="$(__bump__plan_auto_bump "$__bump__plan_bump__version" "$__bump__plan_bump__channel")" || return 1
    fi

    __bump__plan_bump__planned="$(versions__format_version "$__bump__plan_bump__version")"
  fi

  __bump__ensure_tag_available "$__bump__plan_bump__planned" "$__bump__plan_bump__options"
}

bump__use_project_manifest() {
  __bump__use_project_manifest__git_version="$(versions__latest_version)"
  __bump__use_project_manifest__manifest_version="$(releases__record__get_latest)"

  if @is_true "$(versions__version_is_newer \
    "$__bump__use_project_manifest__manifest_version" \
    "$__bump__use_project_manifest__git_version")"; then
    echo "$__bump__use_project_manifest__manifest_version"
    return 0
  fi

  echo "$__bump__use_project_manifest__git_version"
  return 1
}

: <<'FUN'
Takes a version struct and the default channel; echoes the struct after the
flagless git-bump increment. A prerelease gravitates to dev
(__bump__gravitate_to_dev). A clean version opens the next patch on the
channel, 1.0.0 -> 1.0.1-dev.1 on dev in the increment format and 1.0.1 on
stable.
FUN
__bump__plan_auto_bump() {
  __bump__plan_auto_bump__version="$1"
  __bump__plan_auto_bump__channel="$2"

  if @get __bump__plan_auto_bump__get_1 "$__bump__plan_auto_bump__version" '.pre_type' ''; @defined "$__bump__plan_auto_bump__get_1"; then
    __bump__gravitate_to_dev "$__bump__plan_auto_bump__version"
    return
  fi

  if [ "$__bump__plan_auto_bump__channel" = "dev" ]; then
    __bump__plan_dev "$__bump__plan_auto_bump__version" "patch"
    return
  fi

  __bump__plan_release "$__bump__plan_auto_bump__version" "patch"
}
