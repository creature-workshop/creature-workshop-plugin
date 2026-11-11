#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/github/api.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/releases/github_assets.sh" \
  "$SHELLOPS_DIR/lib/releases/prepare.sh" \
  "$SHELLOPS_DIR/lib/tarball/api.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
Publishing a tag's release to the GitHub mirror. The tag reaches GitHub
through a push mirror on the mirror's own clock, so the publish waits for it
before creating anything and never pushes the tag itself. The release opens
at the confidence gate, beta unless the caller says otherwise: a tag below
the gate gets no GitHub release, a prerelease at or above it gets one flagged
prerelease so "latest" stays on the stable release, and a stable tag gets the
release itself. The files the build wrote go on it with their SHA256SUMS.

Publishing the same tag twice is a no-op: a release the tag already carries
is kept and only the assets it lacks are uploaded, so a run that failed part
way through finishes on the next.
MODULE

: <<'PUB_FUN'
Default options for releases__release_publish_github, with owner and repo from
manifest.json.

  tag        the tag to publish
  owner      the GitHub repository the mirror pushes to
  repo
  artifacts  the files to upload, a struct array of paths
  outdir     the directory SHA256SUMS is written to, beside the artifacts
  gate       the channel at or above which the release opens
  body       the release notes; empty names the tag alone
  timeout    seconds to wait for the tag to reach GitHub
  interval   seconds between two looks for it
  token      the GitHub token

Usage: releases__release_github_options
PUB_FUN
releases__release_github_options() {
  @arr __releases__release_github_options__arr_1
  @obj __releases__release_github_options__out \
    '.tag'       "" \
    '.owner'     "$(manifest__get org)" \
    '.repo'      "$(manifest__get repo)" \
    '.artifacts' "$__releases__release_github_options__arr_1" \
    '.outdir'    "." \
    '.gate'      "beta" \
    '.body'      "" \
    '.timeout'   420 \
    '.interval'  15 \
    '.token'     ""
  println "$__releases__release_github_options__out"
}

: <<'PUB_FUN'
Prints the releases__release_publish_github options a tag pipeline describes: the tag
the manifest records, the files the artifacts file $1 names with SHA256SUMS
to be written beside it, a body linking the release on the canonical forge
when GitLab CI names the project, and GITHUB_TOKEN as the token. The
repository, gate and wait keep their defaults for the caller to patch. An
artifacts file that does not exist gives the release no assets, since a build
with nothing to ship writes none; one naming a missing path fails, as does a
version no tag records.

Usage: releases__release_github_pipeline_options ./dist/artifacts.json
PUB_FUN
releases__release_github_pipeline_options() {
  __releases__release_github_pipeline_options__tag="$(releases__release_recorded_tag)" || return 1
  __releases__release_github_pipeline_options__artifacts="$(tarball__artifacts_from "$1")" || return 1
  if @defined "$1" && [ ! -f "$1" ]; then
    log "no artifacts file at $1: publishing the release without assets"
  fi

  @patch __releases__release_github_pipeline_options__out "$(releases__release_github_options)" \
    '.tag'       "$__releases__release_github_pipeline_options__tag" \
    '.artifacts' "$__releases__release_github_pipeline_options__artifacts" \
    '.outdir'    "$(tarball__artifacts_dir "$1")" \
    '.body'      "$(releases__release_github_body "$__releases__release_github_pipeline_options__tag")" \
    '.token'     "${GITHUB_TOKEN:-}"
  println "$__releases__release_github_pipeline_options__out"
}

: <<'PUB_FUN'
Prints the GitHub release's body for tag $1: a link to the release on the
canonical forge when GitLab CI names the project, else nothing, which the
publish fills with the tag's name.

  CI_PROJECT_URL=https://gitlab.example/g/r releases__release_github_body v1.0.0
    ->  See the full release notes at https://gitlab.example/g/r/-/releases/v1.0.0
PUB_FUN
releases__release_github_body() {
  if ! @defined "${CI_PROJECT_URL:-}"; then
    return 0
  fi

  printf 'See the full release notes at %s/-/releases/%s\n' "$CI_PROJECT_URL" "$1"
}

: <<'PUB_FUN'
Publishes the release for .tag on .owner/.repo as the module doc says:
nothing below .gate, otherwise a wait for the tag, the release found or
created, and every artifact and the SHA256SUMS not yet on it uploaded.
Fails when the tag is missing, the wait runs out, or GitHub refuses a call.

Usage: releases__release_publish_github "$(releases__release_github_options)"
PUB_FUN
releases__release_publish_github() {
  @get __releases__release_publish_github__tag "$1" '.tag' ''
  @get __releases__release_publish_github__gate "$1" '.gate' 'beta'
  if ! @defined "$__releases__release_publish_github__tag"; then
    error "releases__release_publish_github: no tag to publish"
    return 1
  fi
  if ! @is_true "$(__releases__github__opens "$__releases__release_publish_github__tag" "$__releases__release_publish_github__gate")"; then
    log "$__releases__release_publish_github__tag is below the $__releases__release_publish_github__gate gate: no GitHub release"
    return 0
  fi

  github__wait_for_tag "$1" || return 1
  __releases__release_publish_github__release="$(__releases__github__release "$1")" || return 1
  __releases__release_publish_github__artifacts="$(__releases__github__artifacts_with_checksums "$1")"
  __releases__release_publish_github__counts="$(releases__release_github_upload_missing "$1" "$__releases__release_publish_github__release" "$__releases__release_publish_github__artifacts")" || return 1

  @get __releases__release_publish_github__get_2 "$__releases__release_publish_github__counts" '.uploaded'
  @get __releases__release_publish_github__get_3 "$__releases__release_publish_github__counts" '.present'
  log "Published GitHub release $__releases__release_publish_github__tag: $__releases__release_publish_github__get_2 uploaded, $__releases__release_publish_github__get_3 already there"
}

: <<'FUN'
Prints true when a release for tag $1 opens on GitHub, which is when the
tag's channel is at or above the gate $2 or the tag is stable; false for a
tag below the gate. A leading v is the git spelling and not the version.

  __releases__github__opens v1.2.0-beta.1 beta  ->  true
  __releases__github__opens 1.2.0-dev.3 beta    ->  false
FUN
__releases__github__opens() {
  @succeeds __releases__github__opens__out versions__version_meets_confidence "${1#v}" "$2"
  println "$__releases__github__opens__out"
}

: <<'FUN'
Prints true when tag $1 is a prerelease, so the GitHub release carries the
flag and "latest" stays on the stable one, and false for a stable tag.

  __releases__github__prerelease v1.2.0-rc.1  ->  true
  __releases__github__prerelease v1.2.0       ->  false
FUN
__releases__github__prerelease() {
  @fails __releases__github__prerelease__out versions__is_release_version "${1#v}"
  println "$__releases__github__prerelease__out"
}

: <<'FUN'
Prints the release for the options' tag, the one GitHub already holds when
there is one, else the one created here: named after the tag, carrying the
options' body or the tag's name, flagged prerelease below stable. Fails when
GitHub refuses either call.
FUN
__releases__github__release() {
  @get __releases__github__release__tag "$1" '.tag'
  __releases__github__release__existing="$(github__release_for_tag "$1")" || return 1
  if @defined "$__releases__github__release__existing"; then
    @get __releases__github__release__get_4 "$__releases__github__release__existing" '.id'
    log "GitHub already carries the release for $__releases__github__release__tag (id $__releases__github__release__get_4)"
    println "$__releases__github__release__existing"
    return 0
  fi

  __releases__github__release__created="$(github_create_release "$(__releases__github__create_options "$1")")" || return 1
  @get __releases__github__release__id "$__releases__github__release__created" '.id' ''
  if ! @defined "$__releases__github__release__id"; then
    error "Failed to create the GitHub release for $__releases__github__release__tag. Response:"
    @dump __releases__github__release__dump_5 "$__releases__github__release__created"
    error "$__releases__github__release__dump_5"
    return 1
  fi

  log "Created GitHub release $__releases__github__release__tag (id $__releases__github__release__id)"
  println "$__releases__github__release__created"
}

: <<'FUN'
Prints the github_create_release options for the publish options $1.
FUN
__releases__github__create_options() {
  @let "$1" __releases__github__create_options__ tag owner repo body token
  @defined "$__releases__github__create_options__body" \
    || __releases__github__create_options__body="Release $__releases__github__create_options__tag"

  @set __releases__github__create_options__out "$(github__new_github_release_options "$__releases__github__create_options__owner" "$__releases__github__create_options__repo")" \
    '.tag_name'   "$__releases__github__create_options__tag" \
    '.name'       "$__releases__github__create_options__tag" \
    '.body'       "$__releases__github__create_options__body" \
    '.prerelease' "$(__releases__github__prerelease "$__releases__github__create_options__tag")" \
    '.token'      "$__releases__github__create_options__token"
  println "$__releases__github__create_options__out"
  __releases__github__create_options__status=$?
  @unlet __releases__github__create_options__ tag owner repo body token
  return "$__releases__github__create_options__status"
}

: <<'FUN'
Prints the options' artifacts with their SHA256SUMS appended, written to the
options' outdir.
FUN
__releases__github__artifacts_with_checksums() {
  @get __releases__github__artifacts_with_checksums__get_6 "$1" '.outdir' '.'
  @get __releases__github__artifacts_with_checksums__get_7 "$1" '.artifacts'
  tarball__with_checksums "$__releases__github__artifacts_with_checksums__get_6" "$__releases__github__artifacts_with_checksums__get_7"
}
