#!/bin/sh

import "$SHELLOPS_DIR/lib/xplat/api.sh"
import "$SHELLOPS_DIR/lib/rust/api.sh"
import "$SHELLOPS_DIR/lib/http/api.sh"
import "$SHELLOPS_DIR/lib/self/api.sh"

: <<'MODULE'
Cross-compilation API built on Zig and cargo-zigbuild.

Provides Zig toolchain installation, cargo-zigbuild invocation for
individual or batched target triples, and cross-arch binary stripping
via zig objcopy.
MODULE

ZIGBUILD_DEFAULT_ZIG_VERSION="0.16.0"
ZIGBUILD_ZIG_BASE_URL="https://ziglang.org/download"

: <<'PUB_FUN'
Downloads and extracts a Zig binary release for the host platform.
Sets ZIG_DIR in the environment and adds it to PATH.

  zigbuild__install_zig
  zigbuild__install_zig "0.16.0"
PUB_FUN
zigbuild__install_zig() {
  __zigbuild__install_zig__version="${1:-$ZIGBUILD_DEFAULT_ZIG_VERSION}"

  if @is_true "$(__zigbuild__zig_already_installed "$__zigbuild__install_zig__version")"; then
    log "zig $__zigbuild__install_zig__version already installed"
    __zigbuild__export_zig_env "$__zigbuild__install_zig__version"
    return
  fi

  __zigbuild__install_zig__filename="$(__zigbuild__zig_tarball_name "$__zigbuild__install_zig__version")"
  __zigbuild__install_zig__url="${ZIGBUILD_ZIG_BASE_URL}/${__zigbuild__install_zig__version}/${__zigbuild__install_zig__filename}"

  log "downloading zig ${__zigbuild__install_zig__version} from ${__zigbuild__install_zig__url}"
  __zigbuild__download_and_extract "$__zigbuild__install_zig__url" "$__zigbuild__install_zig__filename" "$__zigbuild__install_zig__version"
  __zigbuild__export_zig_env "$__zigbuild__install_zig__version"
  log "zig $(zig version) ready"
}

__zigbuild__zig_already_installed() {
  @succeeds __zigbuild__zig_already_installed__out [ -x "$(__zigbuild__zig_install_dir "$1")/zig" ]
  println "$__zigbuild__zig_already_installed__out"
}

__zigbuild__zig_home() {
  echo "${ZIGBUILD_ZIG_HOME:-$(self__tool_home .zig)}"
}

__zigbuild__zig_install_dir() {
  __zigbuild__zig_install_dir__os="$(__zigbuild__zig_os)"
  __zigbuild__zig_install_dir__arch="$(xplat__arch_uname)"
  echo "$(__zigbuild__zig_home)/zig-${__zigbuild__zig_install_dir__arch}-${__zigbuild__zig_install_dir__os}-${1}"
}

__zigbuild__zig_tarball_name() {
  __zigbuild__zig_tarball_name__os="$(__zigbuild__zig_os)"
  __zigbuild__zig_tarball_name__arch="$(xplat__arch_uname)"
  echo "zig-${__zigbuild__zig_tarball_name__arch}-${__zigbuild__zig_tarball_name__os}-${1}.tar.xz"
}

__zigbuild__zig_os() {
  __zigbuild__zig_os__os="$(xplat__os)"
  case "$__zigbuild__zig_os__os" in
    darwin) echo "macos" ;;
    *)      echo "$__zigbuild__zig_os__os" ;;
  esac
}

__zigbuild__download_and_extract() {
  __zigbuild__download_and_extract__url="$1"
  __zigbuild__download_and_extract__zig_home="$(__zigbuild__zig_home)"

  mkdir -p "$__zigbuild__download_and_extract__zig_home"
  __zigbuild__download_and_extract__tmpfile="$(mktemp)"

  if ! http__download "$__zigbuild__download_and_extract__url" "$__zigbuild__download_and_extract__tmpfile"; then
    return 1
  fi

  tar -xJf "$__zigbuild__download_and_extract__tmpfile" -C "$__zigbuild__download_and_extract__zig_home"
  rm -f "$__zigbuild__download_and_extract__tmpfile"
}

__zigbuild__export_zig_env() {
  __zigbuild__export_zig_env__install_dir="$(__zigbuild__zig_install_dir "$1")"

  export ZIG_DIR="$__zigbuild__export_zig_env__install_dir"
  export PATH="${__zigbuild__export_zig_env__install_dir}:${PATH}"
  self__add_persistent_path "$__zigbuild__export_zig_env__install_dir"

  if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$__zigbuild__export_zig_env__install_dir" >> "$GITHUB_PATH"
  fi
}

: <<'PUB_FUN'
Removes a Zig installation for the given version.

  zigbuild__uninstall_zig "0.16.0"
PUB_FUN
zigbuild__uninstall_zig() {
  __zigbuild__uninstall_zig__version="${1:-$ZIGBUILD_DEFAULT_ZIG_VERSION}"
  __zigbuild__uninstall_zig__install_dir="$(__zigbuild__zig_install_dir "$__zigbuild__uninstall_zig__version")"

  if [ -d "$__zigbuild__uninstall_zig__install_dir" ]; then
    log "removing zig ${__zigbuild__uninstall_zig__version}"
    rm -rf "$__zigbuild__uninstall_zig__install_dir"
  else
    log "zig ${__zigbuild__uninstall_zig__version} not installed, nothing to remove"
  fi
}

: <<'PUB_FUN'
Adds the Rust standard library stub for each target triple via rustup.

  zigbuild__add_targets '["x86_64-apple-darwin","aarch64-unknown-linux-gnu"]'
PUB_FUN
zigbuild__add_targets() {
  @foreach __zigbuild__add_one_target "$1"
}

__zigbuild__add_one_target() {
  @unwrap __zigbuild__add_one_target__triple "$1"
  log "adding rustup target: ${__zigbuild__add_one_target__triple}"
  rustup target add "$__zigbuild__add_one_target__triple"
}

: <<'PUB_FUN'
Builds a Rust project for a single target triple via cargo zigbuild.

  zigbuild__build "x86_64-apple-darwin"
  zigbuild__build "aarch64-unknown-linux-gnu" --no-default-features

Extra arguments are forwarded to cargo zigbuild.
PUB_FUN
zigbuild__build() {
  __zigbuild__build__triple="$1"
  shift

  rust__assert_cargo_tool cargo-zigbuild || return 1

  log "building for ${__zigbuild__build__triple}"
  cargo zigbuild --release --target "$__zigbuild__build__triple" "$@"
}

: <<'PUB_FUN'
Builds for every triple in a JSON array, forwarding extra cargo flags.

  zigbuild__build_all '["x86_64-apple-darwin","aarch64-unknown-linux-gnu"]'
  zigbuild__build_all '["x86_64-apple-darwin"]' --no-default-features
PUB_FUN
zigbuild__build_all() {
  __zigbuild__build_all__triples="$1"
  shift

  zigbuild__add_targets "$__zigbuild__build_all__triples"
  @foreach __zigbuild__build_one "$__zigbuild__build_all__triples" "$@"
}

__zigbuild__build_one() {
  @unwrap __zigbuild__build_one__triple "$1"
  shift
  zigbuild__build "$__zigbuild__build_one__triple" "$@"
}

: <<'PUB_FUN'
Strips a binary of debug symbols. Detects Mach-O vs ELF and picks
the right tool: llvm-strip for Darwin, zig objcopy for ELF, with
fallbacks to each other and system strip.

  zigbuild__strip "target/x86_64-apple-darwin/release/mybin" "x86_64-apple-darwin"
PUB_FUN
zigbuild__strip() {
  __zigbuild__strip__binary="$1"
  __zigbuild__strip__triple="${2:-}"

  log "stripping ${__zigbuild__strip__binary}"

  if __zigbuild__is_darwin_triple "$__zigbuild__strip__triple"; then
    __zigbuild__strip_macho "$__zigbuild__strip__binary" || warn "failed to strip ${__zigbuild__strip__binary}, continuing"
  else
    __zigbuild__strip_elf "$__zigbuild__strip__binary" || warn "failed to strip ${__zigbuild__strip__binary}, continuing"
  fi
}

__zigbuild__is_darwin_triple() {
  case "$1" in
    *-apple-darwin*) return 0 ;;
    *) return 1 ;;
  esac
}

__zigbuild__strip_macho() {
  if command -v llvm-strip >/dev/null 2>&1; then
    llvm-strip "$1"
    return
  fi

  if [ "$(xplat__os)" = "darwin" ] && command -v strip >/dev/null 2>&1; then
    strip "$1"
    return
  fi

  warn "no strip tool available for Mach-O binary, skipping"
}

__zigbuild__strip_elf() {
  if command -v llvm-strip >/dev/null 2>&1; then
    llvm-strip "$1"
    return
  fi

  if command -v zig >/dev/null 2>&1; then
    zig objcopy -S "$1" "${1}.stripped" && mv "${1}.stripped" "$1"
    return
  fi

  strip "$1"
}

: <<'PUB_FUN'
Strips debug symbols from a binary across all target triples.

  zigbuild__strip_all "mybin" '["x86_64-apple-darwin","aarch64-unknown-linux-gnu"]'
PUB_FUN
zigbuild__strip_all() {
  @foreach __zigbuild__strip_one "$2" "$1"
}

__zigbuild__strip_one() {
  @unwrap __zigbuild__strip_one__triple "$1"
  zigbuild__strip "target/${__zigbuild__strip_one__triple}/release/${2}" "$__zigbuild__strip_one__triple"
}
