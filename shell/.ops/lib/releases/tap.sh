#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/releases/prepare.sh" \
  "$SHELLOPS_DIR/lib/tarball/api.sh" \
  "$SHELLOPS_DIR/lib/sites/api.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
Publishing a tag's Homebrew formula from a pipeline with no ladder: the tag
is held to a confidence gate, stable unless the caller says otherwise, and
the version is put at the tap as a homebrew-tap site (lib/homebrew/tap.sh)
when it passes. Homebrew orders versions by rules of its own, which read a
counter tag as newer than its clean version, so the tap receives stable
releases alone (ADR.17@global). A repository whose ladder lists the tap as a
site needs none of this: releases__release_reach puts the tag there.
MODULE

: <<'PUB_FUN'
Default options for releases__release_publish_tap.

  tag        the tag to publish
  gate       the channel at or above which the tap is reached, stable
  tap        the tap repository's clone URL, without credentials
  asset_url  where the formula downloads from; empty means the tag's GitHub release
  artifact   the name the tarballs carry; empty means the manifest's command-name
  outdir     the directory the tarballs sit in

Usage: releases__release_tap_options
PUB_FUN
releases__release_tap_options() {
  @obj __releases__release_tap_options__out \
    '.tag'       "" \
    '.gate'      "stable" \
    '.tap'       "" \
    '.asset_url' "" \
    '.artifact'  "" \
    '.outdir'    "./dist"
  println "$__releases__release_tap_options__out"
}

: <<'PUB_FUN'
Prints the options a tag pipeline gives releases__release_publish_tap: the tag the
pipeline releases (releases__release_recorded_tag), and the tarballs where the
artifacts file $1 sits. The rest keeps its defaults for the caller to patch.
Fails when no tag is there to release.

Usage: releases__release_tap_pipeline_options ./dist/artifacts.json
PUB_FUN
releases__release_tap_pipeline_options() {
  __releases__release_tap_pipeline_options__tag="$(releases__release_recorded_tag)" || return 1

  @patch __releases__release_tap_pipeline_options__out "$(releases__release_tap_options)" \
    '.tag'    "$__releases__release_tap_pipeline_options__tag" \
    '.outdir' "$(tarball__artifacts_dir "$1")"
  println "$__releases__release_tap_pipeline_options__out"
}

: <<'PUB_FUN'
Reaches the tap with the tag's commit when the tag is at or above the gate,
or stable; below it, logs and does nothing. Fails when the tag or the tap is
missing, or the tap refuses the commit.

Usage: releases__release_publish_tap "$(releases__release_tap_options)"
PUB_FUN
releases__release_publish_tap() {
  @get __releases__release_publish_tap__tag "$1" '.tag' ''
  @get __releases__release_publish_tap__gate "$1" '.gate' 'rc'
  @get __releases__release_publish_tap__tap "$1" '.tap' ''
  if ! @defined "$__releases__release_publish_tap__tag"; then
    error "releases__release_publish_tap: no tag to publish"
    return 1
  fi
  if ! @defined "$__releases__release_publish_tap__tap"; then
    error "releases__release_publish_tap: no tap to publish $__releases__release_publish_tap__tag to"
    return 1
  fi
  if ! versions__version_meets_confidence "${__releases__release_publish_tap__tag#v}" "$__releases__release_publish_tap__gate"; then
    log "$__releases__release_publish_tap__tag is below the $__releases__release_publish_tap__gate gate: the tap is not reached"
    return 0
  fi

  __releases__release_publish_tap__commit="$(git rev-parse --verify --quiet "${__releases__release_publish_tap__tag}^{commit}")"
  @obj __releases__release_publish_tap__version '.tag' "$__releases__release_publish_tap__tag" '.commit' "$__releases__release_publish_tap__commit"
  sites__put tap "$(__releases__tap__site "$1")" "$__releases__release_publish_tap__version"
}

: <<'FUN'
Prints the homebrew-tap site the options $1 describe: the tap, plus the
download base, artifact name and outdir where the caller set them.

  __releases__tap__site '{"tap":"https://g/t.git","asset_url":"","artifact":"","outdir":"./dist"}'
    ->  {"kind":"homebrew-tap","tap":"https://g/t.git","outdir":"./dist"}
FUN
__releases__tap__site() {
  @let "$1" __releases__tap__site__ tap asset_url artifact outdir

  @obj __releases__tap__site__obj_1 '.kind' homebrew-tap '.tap' "$__releases__tap__site__tap"
  @patch __releases__tap__site__out "$__releases__tap__site__obj_1" \
    '.asset_url' "$__releases__tap__site__asset_url" \
    '.artifact'  "$__releases__tap__site__artifact" \
    '.outdir'    "$__releases__tap__site__outdir"
  println "$__releases__tap__site__out"
  __releases__tap__site__status=$?
  @unlet __releases__tap__site__ tap asset_url artifact outdir
  return "$__releases__tap__site__status"
}
