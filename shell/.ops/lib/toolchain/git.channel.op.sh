#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/self/cache.sh" \
  "$SHELLOPS_DIR/lib/self/pins.sh"

: <<'DOC'
Channel plugin for a git repository taken at a commit as a dev-time tree
(ADR 000050): a test, a lint or CI reads it, and nothing under lib/, cli/
or actions/ sources it. The tree is fetched into the project's cache, and
the lock records it under dependencies.tools.git like every channel, so
the pins file names it like any other.

Every tool of the channel needs git, which the system channel provides.

Requirements:
  version     the commit the tree is pinned at
  repository  optional, the URL of the repository; a path relative to
              this project's origin, as .gitmodules writes one, is joined
              to it; "../<tool>.git" when left out
DOC

: <<'FUN'
Fetches the tree of the tool $1 at the commit its requirements $2 pin into
the project's cache, from the repository they name or the one beside this
project's origin.
FUN
__toolchain__git_channel__install() {
  @get __toolchain__git_channel__install__get_1 "$2" '.repository' ''
  __toolchain__git_channel__install__url="$(self__pins__url "$PROJ" "$1" "$__toolchain__git_channel__install__get_1" '')" || return 1
  @get __toolchain__git_channel__install__get_2 "$2" '.version'
  self__cache__ensure "$(self__pins__cache "$PROJ")" "$1" "$__toolchain__git_channel__install__url" "$__toolchain__git_channel__install__get_2"
}

: <<'FUN'
Removes the tree of the tool $1 at the commit its requirements $2 pin from
the project's cache.
FUN
__toolchain__git_channel__uninstall() {
  @get __toolchain__git_channel__uninstall__get_3 "$2" '.version'
  __toolchain__git_channel__uninstall__dir="$(self__cache__dir "$(self__pins__cache "$PROJ")" "$1" "$__toolchain__git_channel__uninstall__get_3")"
  rm -rf "$__toolchain__git_channel__uninstall__dir" "$__toolchain__git_channel__uninstall__dir.gitlinks"
}

: <<'FUN'
Prints true when the tree of the tool $1 at the commit its requirements $2
pin is in the project's cache.

  __toolchain__git_channel__installed shell-scan '{"version":"da3ddd31..."}'  ->  true
FUN
__toolchain__git_channel__installed() {
  if @get __toolchain__git_channel__installed__get_4 "$2" '.version'; [ -d "$(self__cache__dir "$(self__pins__cache "$PROJ")" "$1" "$__toolchain__git_channel__installed__get_4")" ]; then
    @true __toolchain__git_channel__installed__out
    println "$__toolchain__git_channel__installed__out"
  else
    @false __toolchain__git_channel__installed__out
    println "$__toolchain__git_channel__installed__out"
  fi
}

:<<'DOC'
The git channel: one channel plugin. See lib/toolchain/channel.sh for what
the roles mean.
DOC
@channel.git() {
  @summary() {
    println "A git repository at a commit, fetched into the cache as a dev-time tree."
  }

  @install_tool() {
    __toolchain__git_channel__install "$@"
  }

  @uninstall_tool() {
    __toolchain__git_channel__uninstall "$@"
  }

  @probe() {
    __toolchain__git_channel__installed "$@"
  }

  @dependency() {
    printf 'git\n'
  }

  @dependency_default() {
    @obj __channel_git__out '.channel' 'system' '.version' 'latest'
    println "$__channel_git__out"
  }
}
