#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/http/api.sh" \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/xplat/api.sh"

: <<'MODULE'
LaTeX compiled to PDF with Tectonic.

Tectonic is a self-contained TeX engine that fetches the packages a document
needs on first use and keeps them in a cache, so a compile is deterministic
and offline once that cache is warm. This library installs a pinned Tectonic
into the tools home, keeps its package cache beside it so the runner's tools
cache carries both, and compiles one LaTeX source into a PDF. Markdown is
not Tectonic's concern: pandoc (lib/pandoc) turns it into LaTeX first, and
the render action chains the two.
MODULE

TECTONIC_BASE_URL="https://github.com/tectonic-typesetting/tectonic/releases/download"

: <<'PUB_FUN'
Prints the directory Tectonic versions install under: TECTONIC_HOME when set,
otherwise the tectonic entry of the tools home.
PUB_FUN
tectonic__home() {
  echo "${TECTONIC_HOME:-$(self__tool_home .tectonic)}"
}

: <<'PUB_FUN'
Prints the directory Tectonic's package cache lives in. It sits inside the
Tectonic home so the tools cache that carries the binary carries the
packages too, which is what makes a warm compile offline.
PUB_FUN
tectonic__cache_home() {
  echo "${TECTONIC_CACHE_HOME:-$(tectonic__home)/cache}"
}

: <<'PUB_FUN'
Prints the install directory for Tectonic version $1.
PUB_FUN
tectonic__install_dir() {
  echo "$(tectonic__home)/tectonic-$1"
}

: <<'FUN'
Prints the release target the prebuilt tarball is fetched for: the static
musl build on Linux, since it runs on a bare container image, and the Apple
build on macOS.

    __tectonic__target  ->  x86_64-unknown-linux-musl
FUN
__tectonic__target() {
  __tectonic__target__arch="$(xplat__arch_uname)"
  case "$(uname -s)" in
    Darwin) echo "${__tectonic__target__arch}-apple-darwin" ;;
    *)      echo "${__tectonic__target__arch}-unknown-linux-musl" ;;
  esac
}

: <<'PUB_FUN'
Prints the release tarball name for Tectonic version $1.

    tectonic__tarball_name 0.15.0  ->  tectonic-0.15.0-x86_64-unknown-linux-musl.tar.gz
PUB_FUN
tectonic__tarball_name() {
  echo "tectonic-${1}-$(__tectonic__target).tar.gz"
}

: <<'PUB_FUN'
Prints true when Tectonic version $1 is installed in the tools home, false
otherwise.
PUB_FUN
tectonic__installed() {
  @succeeds __tectonic__installed__out [ -x "$(tectonic__install_dir "$1")/tectonic" ]
  println "$__tectonic__installed__out"
}

: <<'FUN'
Puts the install directory of Tectonic version $1 on PATH, for this shell and
for every later shell that sources .envrc.
FUN
__tectonic__export_env() {
  __tectonic__export_env__dir="$(tectonic__install_dir "$1")"
  export PATH="${__tectonic__export_env__dir}:${PATH}"
  self__add_persistent_path "$__tectonic__export_env__dir"
}

: <<'FUN'
Downloads the release tarball at $1 and extracts it into the install
directory for version $2.
FUN
__tectonic__download_and_extract() {
  __tectonic__download_and_extract__dir="$(tectonic__install_dir "$2")"
  __tectonic__download_and_extract__tmpfile="$(mktemp)"

  mkdir -p "$__tectonic__download_and_extract__dir"
  if ! http__download "$1" "$__tectonic__download_and_extract__tmpfile"; then
    rm -f "$__tectonic__download_and_extract__tmpfile"
    return 1
  fi

  tar -xzf "$__tectonic__download_and_extract__tmpfile" -C "$__tectonic__download_and_extract__dir"
  rm -f "$__tectonic__download_and_extract__tmpfile"
}

: <<'PUB_FUN'
Installs Tectonic version $1 into the tools home and puts it on PATH. The
version comes from ops.lock through the installer, the one place it is
written (ADR 000007); an empty one fails. A version already installed is
only put on PATH.
PUB_FUN
tectonic__install() {
  if ! @defined "${1:-}"; then
    error "tectonic__install: a version is required; ops.lock pins it"
    return 1
  fi
  __tectonic__install__version="$1"

  if [ "$(tectonic__installed "$__tectonic__install__version")" = true ]; then
    log "tectonic $__tectonic__install__version already installed"
    __tectonic__export_env "$__tectonic__install__version"
    return 0
  fi

  __tectonic__install__tarball="$(tectonic__tarball_name "$__tectonic__install__version")"
  __tectonic__install__url="${TECTONIC_BASE_URL}/tectonic%40${__tectonic__install__version}/${__tectonic__install__tarball}"

  log "downloading tectonic ${__tectonic__install__version} from ${__tectonic__install__url}"
  __tectonic__download_and_extract "$__tectonic__install__url" "$__tectonic__install__version" || return 1
  __tectonic__export_env "$__tectonic__install__version"
  log "tectonic $__tectonic__install__version ready"
}

: <<'PUB_FUN'
Removes Tectonic version $1 from the tools home. The package cache stays,
since every version shares it.
PUB_FUN
tectonic__uninstall() {
  rm -rf "$(tectonic__install_dir "$1")"
}

: <<'PUB_FUN'
Compiles the LaTeX source $1 into directory $2 with Tectonic, its package
cache under the cache home, and prints the path of the PDF it wrote, named
after the source. Only the path goes to stdout: Tectonic's own chatter is
sent to stderr so a caller capturing the path never picks it up.

    tectonic__compile src/report.tex dist  ->  dist/report.pdf
PUB_FUN
tectonic__compile() {
  mkdir -p "$2"
  XDG_CACHE_HOME="$(tectonic__cache_home)" tectonic -X compile --outdir "$2" "$1" >&2 || return 1
  echo "$2/$(basename "$1" .tex).pdf"
}
