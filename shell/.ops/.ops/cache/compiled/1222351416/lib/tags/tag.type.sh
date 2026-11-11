#!/bin/sh
# GENERATED FILE. DO NOT EDIT.
# Lowered from lib/tags/tag.type.op.sh by kinds__lower. Any edit here is lost at the next
# ops compile, and CI refuses the bundle while this file differs from what
# its source lowers to. Edit the source.

:<<'DOC'
The tag type: a release tag's name as a struct string, one the versions
grammar reads as a release name, bare or led by a v, with or without a tier
and its count. Any such name makes one; a name that is no release name is
refused. A tag has no zero value, so the constructor with no argument
refuses. lib/structs/type.sh says what the roles mean.

  @tag 0.67.0-1.alpha             ->  "0.67.0-1.alpha"
  @is_tag "$(@wrap 0.66.0-dev.137)"  ->  succeeds
  @is_tag "$(@wrap latest)"       ->  fails
  @tag latest                     ->  fails
DOC
tag_is() {
  string_is "$1" || return 1
  @unwrap __type_tag__unwrap_1 "$1"
  versions__is_valid_semver "$__type_tag__unwrap_1"
}

tag_from() {
  versions__is_valid_semver "$1" || return 1
  @wrap __type_tag__out "$1"
  println "$__type_tag__out"
}
