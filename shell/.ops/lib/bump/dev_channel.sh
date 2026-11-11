#!/bin/sh

:<<'FRAGMENT'
Dev channel resolution: the channel manifest.json declares a merge carrying no
channel label defaults to, whether a merge from a clean version opens a dev
series there, and the version that series starts at.

  bump__default_channel                                    ->  dev
  __bump__opens_dev_series '["type/fix"]' stable  ->  false
  __bump__plan_dev <0.63.3> patch                 ->  <0.63.4-dev.1>  (version-format: increment)
FRAGMENT

: <<'PUB_FUN'
Prints the channel a merge carrying no channel label plans on a clean
version, as manifest.json's default-channel declares it: dev or stable, and
dev when the manifest is silent, a repository with no manifest included. A
manifest that is present has to read; any other value fails.
PUB_FUN
bump__default_channel() {
  if @is_false "$(manifest__present)"; then
    __bump__check_channel ""
    return
  fi

  __bump__default_channel__channel="$(manifest__get bump__default_channel)" || return 1
  __bump__check_channel "$__bump__default_channel__channel"
}

: <<'FUN'
Prints the channel $1 when it is one a merge may default to, dev or stable;
fails naming the value otherwise. An empty value reads as dev, so a caller
that was handed nothing gets the manifest's own default.
FUN
__bump__check_channel() {
  case "${1:-dev}" in
    dev|stable)
      println "${1:-dev}"
      ;;
    *)
      error "default-channel must be dev or stable, not '$1'"
      return 1
      ;;
  esac
}

: <<'FUN'
Prints true when a merge from a clean version opens a dev series rather than
cutting a release: meta/experimental asks for one on either channel, and the
dev channel gives one to every merge not carrying meta/release. Prints false
otherwise: the stable channel with no meta/experimental, or meta/release on
either.

  __bump__opens_dev_series '["type/fix"]' dev              ->  true
  __bump__opens_dev_series '["type/fix"]' stable           ->  false
  __bump__opens_dev_series '["meta/experimental"]' stable  ->  true
  __bump__opens_dev_series '["meta/release"]' dev          ->  false
FUN
__bump__opens_dev_series() {
  __bump__opens_dev_series__labels="$1"
  __bump__opens_dev_series__channel="$2"

  if @is_true "$(__bump__has_label "$__bump__opens_dev_series__labels" "meta/experimental")"; then
    @true __bump__opens_dev_series__out
    println "$__bump__opens_dev_series__out"
    return
  fi

  if @is_true "$(__bump__has_label "$__bump__opens_dev_series__labels" "meta/release")"; then
    @false __bump__opens_dev_series__out
    println "$__bump__opens_dev_series__out"
    return
  fi

  if [ "$__bump__opens_dev_series__channel" = "dev" ]; then
    @true __bump__opens_dev_series__out
    println "$__bump__opens_dev_series__out"
    return
  fi

  @false __bump__opens_dev_series__out
  println "$__bump__opens_dev_series__out"
}

: <<'FUN'
Takes a clean version struct and the bump level; echoes the struct bumped at
the level with the dev series opened, as __bump__with_tier opens it.

  __bump__plan_dev <0.63.3> patch  ->  <0.63.4-dev.1>  (version-format: increment)
  __bump__plan_dev <0.63.3> patch  ->  <0.63.4-dev>    (version-format: counter)
FUN
__bump__plan_dev() {
  __bump__with_tier "$(__bump__apply_bump "$1" "$2")" dev
}
