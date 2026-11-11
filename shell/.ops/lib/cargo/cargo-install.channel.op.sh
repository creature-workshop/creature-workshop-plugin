#!/usr/bin/env bash

: <<'DOC'
Channel plugin for installing Rust crates with `cargo install`.

Requirements:
  version   crate version to install
  crate     optional crate name override
  args      optional extra arguments passed to `cargo install`
DOC

function __cargo__install__install() {
  local tool="$1"
  local requirements="$2"

  local version crate args
  @get version "$requirements" '.version'
  @get crate "$requirements" '.crate' "$tool"
  @get args "$requirements" '.args'

  if ! @defined "$args"; then
    args=""
  fi

  # shellcheck disable=SC2086
  cargo install "$crate" --version "$version" $args
}

function __cargo__install__uninstall() {
  local tool="$1"
  local requirements="$2"
  local crate
  @get crate "$requirements" '.crate' "$tool"

  cargo uninstall -v "$crate"
}

:<<'DOC'
The cargo-install channel: one channel plugin. See lib/toolchain/channel.sh
for what the roles mean.
DOC
@channel.cargo-install() {
  @summary() {
    println "Rust crates built from source, with cargo install."
  }

  @install_tool() {
    __cargo__install__install "$@"
  }

  @uninstall_tool() {
    __cargo__install__uninstall "$@"
  }

  @dependency() {
    printf 'rustup\n'
  }

  @dependency_default() {
    @arr __at1 build-essential
    @obj __at_out \
      '.channel' 'script' \
      '.version' '1.28.2' \
      '.needs' "$__at1"
    println "$__at_out"
  }
}
