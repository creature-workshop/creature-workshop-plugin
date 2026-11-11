#!/bin/sh

import "$SHELLOPS_DIR/lib/github/api.sh"

: <<'FRAGMENT'
Uploading a build's files onto a GitHub release: only the ones the release
does not already carry, so a second run uploads nothing and a run that failed
part way through finishes on the next, and a count of both kinds for the
publish to report.
FRAGMENT

# CONST: How many files the last releases__release_github_upload_missing uploaded.
__releases__github_assets__UPLOADED=0

# CONST: How many files the last releases__release_github_upload_missing found on the release already.
__releases__github_assets__PRESENT=0

: <<'PUB_FUN'
Uploads every file in the struct array $3 that release $2 does not already
carry as an asset of the same name, with the publish options $1, and prints
how many went up and how many were there. Fails on the first upload GitHub
refuses.

  releases__release_github_upload_missing "$options" "$release" '["./dist/a.tar.gz"]'  ->  {"uploaded":1,"present":0}
PUB_FUN
releases__release_github_upload_missing() {
  __releases__github_assets__UPLOADED=0
  __releases__github_assets__PRESENT=0
  @arr __releases__release_github_upload_missing__arr_1
  @get __releases__release_github_upload_missing__get_2 "$2" '.assets' "$__releases__release_github_upload_missing__arr_1"
  @pluck __releases__release_github_upload_missing__present "$__releases__release_github_upload_missing__get_2" '.name'

  @get __releases__release_github_upload_missing__get_3 "$2" '.id'
  @foreach __releases__github_assets__upload_one \
    "$3" \
    "$1" \
    "$__releases__release_github_upload_missing__get_3" \
    "$__releases__release_github_upload_missing__present" || return 1

  @obj __releases__release_github_upload_missing__out \
    '.uploaded' "$__releases__github_assets__UPLOADED" \
    '.present'  "$__releases__github_assets__PRESENT"
  println "$__releases__release_github_upload_missing__out"
}

: <<'FUN'
@foreach callback: uploads the wrapped path $1 to release $3 with the
publish options $2, unless the asset names in $4 already hold its name.
FUN
__releases__github_assets__upload_one() {
  @unwrap __releases__github_assets__upload_one__path "$1"
  __releases__github_assets__upload_one__name="${__releases__github_assets__upload_one__path##*/}"
  if @any __releases__github_assets__upload_one__any_4 __releases__github_assets__name_is "$4" "$__releases__github_assets__upload_one__name"; @is_true "$__releases__github_assets__upload_one__any_4"; then
    log "$__releases__github_assets__upload_one__name is already on the release"
    __releases__github_assets__PRESENT=$(( __releases__github_assets__PRESENT + 1 ))
    return 0
  fi

  @get __releases__github_assets__upload_one__get_5 "$2" '.owner'
  @get __releases__github_assets__upload_one__get_6 "$2" '.repo'
  @get __releases__github_assets__upload_one__get_7 "$2" '.token'
  @set __releases__github_assets__upload_one__options "$(github__new_github_upload_options "$__releases__github_assets__upload_one__get_5" "$__releases__github_assets__upload_one__get_6")" \
    '.release_id' "$3" \
    '.filename'   "$__releases__github_assets__upload_one__name" \
    '.filepath'   "$__releases__github_assets__upload_one__path" \
    '.token'      "$__releases__github_assets__upload_one__get_7"
  log "Uploading $__releases__github_assets__upload_one__name to GitHub..."
  github_upload_artifact "$__releases__github_assets__upload_one__options" > /dev/null || return 1
  __releases__github_assets__UPLOADED=$(( __releases__github_assets__UPLOADED + 1 ))
}

: <<'FUN'
@any callback: true when the wrapped asset name $1 is $2.
FUN
__releases__github_assets__name_is() {
  @unwrap __releases__github_assets__name_is__unwrap_8 "$1"
  [ "$__releases__github_assets__name_is__unwrap_8" = "$2" ]
}
