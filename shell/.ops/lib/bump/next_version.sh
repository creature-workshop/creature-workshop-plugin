#!/bin/sh

:<<'FRAGMENT'
The version a merge's labels plan, worked out from the current version, the
format the manifest declares a plan writes in, and the tags where that
format reads them. A prerelease plans its next prerelease and a clean
version opens a dev series or cuts a release; the labels pick the level
either way.

This is the planner CI runs on a code review, so the version lands in the diff
the review is judged on.
FRAGMENT

: <<'PUB_FUN'
Computes the next version from the current version, the PR labels, and the
channel a clean version plans on when the labels name none. The prerelease
part is written in the format the manifest declares under version-format
(versions__format), increment when it declares none.

No side effects, no API calls.

Usage: bump__compute_next_version "$latest" "$labels" "$channel"

  latest:  current version string (e.g. "1.0.0" or "1.1.0-dev.3")
  labels:  JSON array of PR label names
  channel: dev or stable, what manifest.json's default-channel declares;
           empty or omitted reads as dev

The labels pick the level, and on a clean version the channel picks the
track:

  bump__compute_next_version 0.63.3 '["type/fix"]' dev         ->  0.63.4-dev.1
  bump__compute_next_version 0.63.3 '["type/feature"]' dev     ->  0.64.0-dev.1
  bump__compute_next_version 0.63.3 '["type/fix"]' stable      ->  0.63.4
  bump__compute_next_version 0.63.3 '["meta/release"]' dev     ->  0.63.4

A prerelease plans the same on either channel: the next dev, a promotion up
the ladder, or the clean version from meta/release. In the counter format
the plan names the version and the tier and never a count, which the tags
hand out (ADR.17@global); with version-format: counter declared:

  bump__compute_next_version 0.67.0-dev '["type/fix"]' dev         ->  0.67.0-dev
  bump__compute_next_version 0.67.1-dev '["type/feature"]' dev     ->  0.68.0-dev
  bump__compute_next_version 0.67.0-3.alpha '["meta/promote"]' dev ->  0.67.0-beta
  bump__compute_next_version 0.67.0-6.rc '["meta/release"]' dev    ->  0.67.0

Outputs the next version string.
PUB_FUN
bump__compute_next_version() {
  __bump__compute_next_version__latest="$1"
  __bump__compute_next_version__labels="$2"
  __bump__compute_next_version__channel="$(__bump__check_channel "${3:-}")" || return 1

  bump__validate_meta_labels "$__bump__compute_next_version__labels" || return 1

  __bump__compute_next_version__version="$(versions__parse_version "$__bump__compute_next_version__latest")" || return 1

  __bump__compute_next_version__level="$(__bump__infer_bump_level "$__bump__compute_next_version__labels" "$__bump__compute_next_version__version")"

  @get __bump__compute_next_version__pre_type "$__bump__compute_next_version__version" '.pre_type' ''

  if @defined "$__bump__compute_next_version__pre_type"; then
    __bump__compute_next_version__version="$(__bump__plan_prerelease "$__bump__compute_next_version__version" "$__bump__compute_next_version__labels" "$__bump__compute_next_version__level")" || return 1
  else
    __bump__compute_next_version__version="$(__bump__plan_from_clean "$__bump__compute_next_version__version" "$__bump__compute_next_version__labels" "$__bump__compute_next_version__level" "$__bump__compute_next_version__channel")" || return 1
  fi

  versions__format_version "$__bump__compute_next_version__version"
}

: <<'FUN'
Takes a clean version struct, the labels, the bump level and the default
channel; echoes the planned struct. The labels or the channel put the plan on
the dev track (__bump__opens_dev_series); otherwise it is the clean
version at the level.
FUN
__bump__plan_from_clean() {
  __bump__plan_from_clean__version="$1"
  __bump__plan_from_clean__labels="$2"
  __bump__plan_from_clean__level="$3"
  __bump__plan_from_clean__channel="$4"

  __bump__plan_from_clean__dev="$(__bump__opens_dev_series "$__bump__plan_from_clean__labels" "$__bump__plan_from_clean__channel")"
  if @is_true "$__bump__plan_from_clean__dev"; then
    __bump__plan_dev "$__bump__plan_from_clean__version" "$__bump__plan_from_clean__level"
    return
  fi

  __bump__plan_release "$__bump__plan_from_clean__version" "$__bump__plan_from_clean__level"
}
