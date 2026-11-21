#!/usr/bin/env bash

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import \
  "$SHELLOPS_DIR/lib/cargo/prebuilt.sh" \
  "$SHELLOPS_DIR/lib/rust/api.sh" \
  "$SHELLOPS_DIR/lib/xplat/api.sh"

# shellcheck disable=SC2034  # the usage is the file's doc; the script channel sources it with no arguments
USAGE="$(cat <<'HELP'
Installs cargo-binstall from its prebuilt musl release, into the cargo home
lib/rustup names (rustup__cargo_home), alongside the toolchain rustup installed.

cargo-binstall fetches prebuilt crate binaries, so building IT from source
(`cargo install cargo-binstall`) pulls in aws-lc-sys/rustls — a heavy C build
that OOMs CI runners, the very cost binstall exists to avoid. Bootstrap it from
the upstream static musl binary, which needs no Rust toolchain to install. The
archive comes through lib/cargo/prebuilt.sh, so a download mirror and a GitHub
token apply to it like to every other release archive.

Sourced by the script channel with the requirement in
SHELLOPS_TOOL_REQUIREMENTS; takes no arguments.
HELP
)"

# CONST: The release to fetch, as the requirement pins it.
__cargo_binstall_installer__VERSION="$(__shellops__tool_version cargo-binstall)"

# CONST: The release archive, by the template cargo-binstall's own metadata uses.
__cargo_binstall_installer__RELEASE="https://github.com/cargo-bins/cargo-binstall/releases/download/v{ version }/cargo-binstall-{ target }.tgz"

# CONST: The statically linked build for the machine's architecture.
__cargo_binstall_installer__TARGET="$(xplat__target_triple "$(xplat__arch_uname)" unknown linux musl)"

# CONST: Where cargo's own binaries live, so binstall sits beside them.
__cargo_binstall_installer__BIN_DIR="$(rustup__cargo_home)/bin"

main() {
  __main__url="$(cargo__prebuilt__url \
    "$__cargo_binstall_installer__RELEASE" \
    "$__cargo_binstall_installer__VERSION" \
    "$__cargo_binstall_installer__TARGET"
  )"
  cargo__prebuilt__install cargo-binstall "$__main__url" "$__cargo_binstall_installer__BIN_DIR"
}

main
