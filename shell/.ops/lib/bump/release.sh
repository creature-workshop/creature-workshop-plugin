#!/bin/sh

:<<'FRAGMENT'
Cutting a stable release: the clean version a promotion or the stable channel
lands on, and the confidence gate a release from a prerelease clears first.

One module because the gate exists for this version and no other -- a plan that
stays on a prerelease channel never consults it.
FRAGMENT

: <<'FUN'
Takes a clean version struct and the bump level; echoes the clean version
bumped at the level, the release a promotion or the stable channel cuts.

  __bump__plan_release <0.63.3> minor  ->  <0.64.0>
FUN
__bump__plan_release() {
  __bump__apply_bump "$1" "$2"
}

: <<'PUB_FUN'
Checks whether releasing from the current prerelease channel is below the
confidence gate. Emits a warning to stderr, or returns non-zero in strict mode.

  bump__check_release_safety "$current_version" "$options"

Options JSON fields:
  .confidence_gate  - override SHELLOPS_CONFIDENCE_GATE (default: beta)
  .strict_release   - "true" to treat below-gate releases as errors
PUB_FUN
bump__check_release_safety() {
  __bump__check_release_safety__version="$1"
  __bump__check_release_safety__options="$2"
  __bump__check_release_safety__gate="${SHELLOPS_CONFIDENCE_GATE:-beta}"

  @let "$__bump__check_release_safety__options" __bump__check_release_safety__ confidence_gate strict_release
  @defined "$__bump__check_release_safety__confidence_gate" \
    && __bump__check_release_safety__gate="$__bump__check_release_safety__confidence_gate"

  __bump__check_release_safety__parsed="$(versions__parse_version "$__bump__check_release_safety__version")" || return 0

  @get __bump__check_release_safety__pre_type "$__bump__check_release_safety__parsed" '.pre_type' ''
  @defined "$__bump__check_release_safety__pre_type" || return 0

  if ! versions__version_meets_confidence "$__bump__check_release_safety__version" "$__bump__check_release_safety__gate"; then
    __bump__check_release_safety__message="Warning: releasing from $__bump__check_release_safety__pre_type (below $__bump__check_release_safety__gate confidence)"

    if [ "$__bump__check_release_safety__strict_release" = "true" ]; then
      error "$__bump__check_release_safety__message"
      return 1
    fi

    warn "$__bump__check_release_safety__message"
  fi
  __bump__check_release_safety__status=$?
  @unlet __bump__check_release_safety__ confidence_gate strict_release
  return "$__bump__check_release_safety__status"
}
