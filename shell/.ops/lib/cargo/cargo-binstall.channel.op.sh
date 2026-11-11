#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/cargo/prebuilt.sh" \
  "$SHELLOPS_DIR/lib/rustup/api.sh" \
  "$SHELLOPS_DIR/lib/xplat/api.sh"

: <<'DOC'
Channel plugin for installing Rust crates from their prebuilt binaries:
through `cargo binstall`, or straight from the release archive when the
entry names one.

Requirements:
  version   crate version to install
  crate     optional crate name override
  args      optional extra arguments passed to `cargo binstall`
  musl      optional; prefer the statically linked musl build on Linux
  release   optional; the URL template of the crate's release archive, in
            cargo-binstall's pkg-url spelling ({ version }, { target }).
            An entry with one installs through lib/cargo/prebuilt.sh and
            never runs cargo binstall, so the download honours
            OPS_DOWNLOAD_MIRROR, which cargo-binstall cannot.
  bin       optional; the binary's name inside the archive, the tool's
            name otherwise

cargo binstall reads GITHUB_TOKEN from the environment on its own; the
channel passes it as --github-token as well, so a job that sets the
variable without exporting it still downloads authenticated.
DOC

: <<'FUN'
Installs the tool $1 from its requirements $2: from its release archive
when the entry names one, with cargo binstall otherwise.
FUN
__cargo__binstall__install() {
  if @defined "$(__cargo__binstall__release "$2")"; then
    __cargo__binstall__install_prebuilt "$1" "$2"
  else
    __cargo__binstall__install_with_binstall "$1" "$2"
  fi
}

: <<'FUN'
Removes the tool $1 installed from its requirements $2: the binary alone
for a release archive, through cargo uninstall otherwise.
FUN
__cargo__binstall__uninstall() {
  if @defined "$(__cargo__binstall__release "$2")"; then
    rm -f "$(__cargo__binstall__bin_dir)/$(__cargo__binstall__bin "$1" "$2")"
  else
    cargo uninstall -v "$(__cargo__binstall__crate "$1" "$2")"
  fi
}

: <<'FUN'
Installs the tool $1 at the version its requirements $2 pin with cargo
binstall: the entry's extra arguments, the musl target when it asks for
one, and the GitHub token when the environment has one.
FUN
__cargo__binstall__install_with_binstall() {
  @get __cargo__binstall__install_with_binstall__version "$2" '.version'
  __cargo__binstall__install_with_binstall__crate="$(__cargo__binstall__crate "$1" "$2")"
  @get __cargo__binstall__install_with_binstall__args "$2" '.args' ''

  if @is_true "$(__cargo__binstall__wants_musl "$2")"; then
    __cargo__binstall__install_with_binstall__args="$__cargo__binstall__install_with_binstall__args --target $(__cargo__binstall__musl_target)"
  fi

  if @defined "${GITHUB_TOKEN:-}"; then
    __cargo__binstall__install_with_binstall__args="$__cargo__binstall__install_with_binstall__args --github-token $GITHUB_TOKEN"
  fi

  # shellcheck disable=SC2086  # the entry's args are single tokens, so the word split is intended
  cargo binstall -y $__cargo__binstall__install_with_binstall__args \
    "${__cargo__binstall__install_with_binstall__crate}@${__cargo__binstall__install_with_binstall__version}"
}

: <<'FUN'
Installs the tool $1 from the release archive its requirements $2 name,
for the target the entry asks for, into cargo's bin directory.
FUN
__cargo__binstall__install_prebuilt() {
  @get __cargo__binstall__install_prebuilt__version "$2" '.version'
  __cargo__binstall__install_prebuilt__url="$(cargo__prebuilt__url \
    "$(__cargo__binstall__release "$2")" \
    "$__cargo__binstall__install_prebuilt__version" \
    "$(__cargo__binstall__target "$2")"
  )"

  log "installing $1 $__cargo__binstall__install_prebuilt__version from $__cargo__binstall__install_prebuilt__url"
  cargo__prebuilt__install \
    "$(__cargo__binstall__bin "$1" "$2")" \
    "$__cargo__binstall__install_prebuilt__url" \
    "$(__cargo__binstall__bin_dir)"
}

: <<'FUN'
Prints the release archive template the entry $1 names, nothing when it
names none.
FUN
__cargo__binstall__release() {
  @get __cargo__binstall__release__out "$1" '.release' ''
  println "$__cargo__binstall__release__out"
}

: <<'FUN'
Prints the crate the entry $2 installs for the tool $1: its override, or
the tool's name.
FUN
__cargo__binstall__crate() {
  @get __cargo__binstall__crate__out "$2" '.crate' "$1"
  println "$__cargo__binstall__crate__out"
}

: <<'FUN'
Prints the binary the entry $2 installs for the tool $1: its override, or
the tool's name.
FUN
__cargo__binstall__bin() {
  @get __cargo__binstall__bin__out "$2" '.bin' "$1"
  println "$__cargo__binstall__bin__out"
}

: <<'FUN'
Prints the directory cargo keeps its binaries in, where every tool of this
channel lands.
FUN
__cargo__binstall__bin_dir() {
  println "$(rustup__cargo_home)/bin"
}

: <<'FUN'
Prints true when the entry $1 asks for the statically linked musl build,
false otherwise.
FUN
__cargo__binstall__wants_musl() {
  if @false __cargo__binstall__wants_musl__false_1; @get __cargo__binstall__wants_musl__get_2 "$1" '.musl' "$__cargo__binstall__wants_musl__false_1"; @is_true "$__cargo__binstall__wants_musl__get_2"; then
    println true
  else
    println false
  fi
}

: <<'FUN'
Prints the target triple the entry $1 installs for: the host's musl target
when it asks for the musl build, the host's own triple otherwise.
FUN
__cargo__binstall__target() {
  if @is_true "$(__cargo__binstall__wants_musl "$1")"; then
    __cargo__binstall__musl_target
  else
    xplat__host_triple
  fi
}

: <<'FUN'
Target triple for the host's statically linked musl build.

A crate's default (gnu) artifact is built against whatever glibc its release
runner had, so it can refuse to start on an older distro -- cargo-tarpaulin's
0.35.4 gnu build needs GLIBC 2.38 and dies on Ubuntu 22.04's 2.35. The musl
build is static and runs anywhere. Derived from the host arch rather than
hardcoded, so aarch64 machines resolve their own artifact.
FUN
__cargo__binstall__musl_target() {
  xplat__target_triple "$(xplat__arch_uname)" "unknown" "linux" "musl"
}

:<<'DOC'
The cargo-binstall channel: one channel plugin. See lib/toolchain/channel.sh
for what the roles mean.
DOC
@channel.cargo-binstall() {
  @summary() {
    println "Rust crates from their prebuilt binaries, with cargo binstall or from the release archive."
  }

  @install_tool() {
    __cargo__binstall__install "$@"
  }

  @uninstall_tool() {
    __cargo__binstall__uninstall "$@"
  }

  @dependency() {
    printf 'cargo-binstall\n'
  }

  @dependency_default() {
    @obj __at_out \
      '.channel' 'cargo-install' \
      '.version' '1.18.0' \
      '.crate' 'cargo-binstall'
    println "$__at_out"
  }
}
