#!/bin/sh

import "$SHELLOPS_DIR/lib/self/config.sh"

: <<'MODULE'
Cross-platform helpers: anything that needs to vary by OS, architecture, or
target triple lives here.
MODULE

: <<'CONST'
The operating systems this module knows a host as; xplat__os answers one and
the triple builder dispatches on it.
CONST
@enum __xplat__OS LINUX DARWIN

: <<'PUB_FUN'
Returns the normalized OS name for the current platform.

  xplat__os
  # => linux | darwin
PUB_FUN
xplat__os() {
  case "$(uname -s)" in
    Linux)  printf '%s\n' "$__xplat__OS_LINUX" ;;
    Darwin) printf '%s\n' "$__xplat__OS_DARWIN" ;;
    *)
      error "Unsupported OS: $(uname -s)"
      return 1
      ;;
  esac
}

: <<'PUB_FUN'
Returns the normalized CPU architecture.

Uses dpkg on Debian-based systems for accuracy (reflects multiarch config),
falls back to uname -m mapping otherwise.

  xplat__arch
  # => amd64 | arm64
PUB_FUN
xplat__arch() {
  if command -v dpkg >/dev/null 2>&1; then
    dpkg --print-architecture
    return
  fi

  __xplat__arch__machine="$(uname -m)"
  case "$__xplat__arch__machine" in
    x86_64)  echo "amd64" ;;
    aarch64) echo "arm64" ;;
    *)       echo "$__xplat__arch__machine" ;;
  esac
}

: <<'PUB_FUN'
Returns the CPU architecture as reported by uname -m.
This is the canonical form used by LLVM/GNU target triples.

  xplat__arch_uname
  # => x86_64 | aarch64
PUB_FUN
xplat__arch_uname() {
  uname -m
}

: <<'PUB_FUN'
Composes a target triple from its components: arch-vendor-os or arch-vendor-os-abi.

  xplat__target_triple "x86_64" "unknown" "linux" "gnu"
  # => x86_64-unknown-linux-gnu

  xplat__target_triple "aarch64" "apple" "darwin"
  # => aarch64-apple-darwin
PUB_FUN
xplat__target_triple() {
  __xplat__target_triple__arch="$1"
  __xplat__target_triple__vendor="$2"
  __xplat__target_triple__os="$3"
  __xplat__target_triple__abi="${4:-}"

  if [ -n "$__xplat__target_triple__abi" ]; then
    echo "${__xplat__target_triple__arch}-${__xplat__target_triple__vendor}-${__xplat__target_triple__os}-${__xplat__target_triple__abi}"
  else
    echo "${__xplat__target_triple__arch}-${__xplat__target_triple__vendor}-${__xplat__target_triple__os}"
  fi
}

: <<'PUB_FUN'
Returns the target triple for the current host.

  xplat__host_triple
  # => x86_64-unknown-linux-gnu | aarch64-apple-darwin
PUB_FUN
xplat__host_triple() {
  __xplat__host_triple__arch="$(xplat__arch_uname)"
  __xplat__host_triple__os="$(xplat__os)"

  case "$__xplat__host_triple__os" in
    "$__xplat__OS_DARWIN") xplat__target_triple "$__xplat__host_triple__arch" "apple" "darwin" ;;
    "$__xplat__OS_LINUX")  xplat__target_triple "$__xplat__host_triple__arch" "unknown" "linux" "gnu" ;;
    *)
      error "No target triple mapping for OS: $__xplat__host_triple__os"
      return 1
      ;;
  esac
}

: <<'PUB_FUN'
Returns a JSON array of target triples from the build targets config.
Checks for a "build-targets" key in $PROJ/manifest.json first,
then falls back to lib/xplat/build_targets.default.json.

  xplat__build_triples
  # => ["x86_64-apple-darwin","aarch64-apple-darwin","x86_64-unknown-linux-gnu","aarch64-unknown-linux-gnu"]
PUB_FUN
xplat__build_triples() {
  __xplat__build_triples__targets="$(__xplat__resolve_build_target_config)"

  @arr __xplat__build_triples__arr_1
  @reduce __xplat__build_triples__out __xplat__concat_target_triples "$__xplat__build_triples__targets" "$__xplat__build_triples__arr_1"
  println "$__xplat__build_triples__out"
}

__xplat__concat_target_triples() {
  __xplat__concat_target_triples__acc="$1"
  __xplat__concat_target_triples__target="$2"
  __xplat__concat_target_triples__triples="$(__xplat__expand_target "$__xplat__concat_target_triples__target")"
  @concat __xplat__concat_target_triples__out "$__xplat__concat_target_triples__acc" "$__xplat__concat_target_triples__triples"
  println "$__xplat__concat_target_triples__out"
}

__xplat__expand_target() {
  __xplat__expand_target__target="$1"

  @let "$__xplat__expand_target__target" __xplat__expand_target__ vendor os abi archs

  @map __xplat__expand_target__out __xplat__arch_to_triple "$__xplat__expand_target__archs" "$__xplat__expand_target__vendor" "$__xplat__expand_target__os" "$__xplat__expand_target__abi"
  println "$__xplat__expand_target__out"
  __xplat__expand_target__status=$?
  @unlet __xplat__expand_target__ vendor os abi archs
  return "$__xplat__expand_target__status"
}

__xplat__arch_to_triple() {
  __xplat__arch_to_triple__vendor="$2"
  __xplat__arch_to_triple__os="$3"
  __xplat__arch_to_triple__abi="$4"

  @get __xplat__arch_to_triple__arch "$1" '.'

  if @defined "$__xplat__arch_to_triple__abi"; then
    __xplat__arch_to_triple__triple="$(xplat__target_triple "$__xplat__arch_to_triple__arch" "$__xplat__arch_to_triple__vendor" "$__xplat__arch_to_triple__os" "$__xplat__arch_to_triple__abi")"
  else
    __xplat__arch_to_triple__triple="$(xplat__target_triple "$__xplat__arch_to_triple__arch" "$__xplat__arch_to_triple__vendor" "$__xplat__arch_to_triple__os")"
  fi

  @wrap __xplat__arch_to_triple__out "$__xplat__arch_to_triple__triple"
  println "$__xplat__arch_to_triple__out"
}

__xplat__resolve_build_target_config() {
  __xplat__resolve_build_target_config__default_config="${SHELLOPS_DIR}/lib/xplat/build_targets.default.json"

  if @is_true "$(self__config__present manifest)"; then
    __xplat__resolve_build_target_config__manifest_json="$(self__config__load manifest)"
    @get __xplat__resolve_build_target_config__override "$__xplat__resolve_build_target_config__manifest_json" '."build-targets"' 'null'
    if @defined "$__xplat__resolve_build_target_config__override"; then
      echo "$__xplat__resolve_build_target_config__override"
      return
    fi
  fi

  if [ ! -f "$__xplat__resolve_build_target_config__default_config" ]; then
    error "Build targets config not found: $__xplat__resolve_build_target_config__default_config"
    return 1
  fi

  cat "$__xplat__resolve_build_target_config__default_config"
}
