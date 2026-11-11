#!/usr/bin/env bash

: <<'DOC'
Channel plugin for tools installed by the system package manager layer.

Requirements:
  version   preferred package version when supported by the host manager
  repo      per-manager third-party repo config (passed to system_packages__add_repo)
  needs     list of other system tools that must be installed first
DOC

function __system_packages__channel__install() {
  local tool="$1"
  local requirements="$2"
  local version repo_json

  @get version "$requirements" '.version' ''
  @get repo_json "$requirements" '.repo' ''

  if @defined "$repo_json"; then
    system_packages__add_repo "$tool" "$repo_json"
  fi

  system_packages__install "$tool" "$version"
}

function __system_packages__channel__uninstall() {
  local tool="$1"
  system_packages__remove "$tool"
}

: <<'FUN'
Prints true when the host's package manager reports the package installed.

  __system_packages__channel__installed git  ->  true
FUN
__system_packages__channel__installed() {
  @succeeds __system_packages__channel__installed__out system_packages__installed "$1"
  println "$__system_packages__channel__installed__out"
}

:<<'DOC'
The system channel: one channel plugin. See lib/toolchain/channel.sh for
what the roles mean.
DOC
@channel.system() {
  @summary() {
    println "Packages from the host's own package manager."
  }

  @install_tool() {
    __system_packages__channel__install "$@"
  }

  @uninstall_tool() {
    __system_packages__channel__uninstall "$@"
  }

  @probe() {
    __system_packages__channel__installed "$@"
  }
}
