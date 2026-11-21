#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/http/api.sh" \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/shell_rc/api.sh" \
  "$SHELLOPS_DIR/lib/xplat/api.sh"

: <<'MODULE'
The Go toolchain, and the tools built with it.

A pinned Go installs from go.dev's release archive into a prefix the whole
machine shares, /usr/local by default, so `go` is on PATH for every shell.
The tools `go install` builds land in the Go tool home, GOPATH when the
caller exports one and the go entry of the tools home otherwise, which the
runner's tools cache carries between runs. Both bin directories are recorded
for every later shell that sources .envrc.
MODULE

GOLANG_BASE_URL="https://go.dev/dl"

: <<'PUB_FUN'
Prints the prefix Go installs under: GOLANG_PREFIX when set, /usr/local
otherwise. The toolchain sits at <prefix>/go.
PUB_FUN
golang__prefix() {
  println "${GOLANG_PREFIX:-/usr/local}"
}

: <<'PUB_FUN'
Prints the directory the Go toolchain sits in.
PUB_FUN
golang__root() {
  printf '%s/go\n' "$(golang__prefix)"
}

: <<'PUB_FUN'
Prints the directory `go install` builds tools into: GOPATH when exported,
the go entry of the tools home otherwise.
PUB_FUN
golang__gopath() {
  println "${GOPATH:-$(self__tool_home go)}"
}

: <<'PUB_FUN'
Prints the archive go.dev publishes for version $1 on this host.

  golang__archive_name 1.25.5  ->  go1.25.5.linux-amd64.tar.gz
PUB_FUN
golang__archive_name() {
  printf 'go%s.%s-%s.tar.gz\n' "$1" "$(xplat__os)" "$(xplat__arch)"
}

: <<'PUB_FUN'
Prints true when the go on PATH is version $1, false otherwise -- when no
go is on PATH, or another version is.
PUB_FUN
golang__installed() {
  @succeeds __golang__installed__out __golang__on_path_at "$1"
  println "$__golang__installed__out"
}

: <<'FUN'
Succeeds quietly when a go on PATH answers `go version` with version $1.
FUN
__golang__on_path_at() {
  command -v go >/dev/null 2>&1 || return 1
  go version | grep -q "go$1 "
}

: <<'PUB_FUN'
Installs Go version $1 under the prefix and puts it on PATH. The version
comes from ops.lock through the installer, the one place it is written
(ADR 000007); an empty one fails. A version already installed is only put
on PATH.
PUB_FUN
golang__install() {
  if ! @defined "${1:-}"; then
    error "golang__install: a version is required; ops.lock pins it"
    return 1
  fi

  if @is_true "$(golang__installed "$1")"; then
    log "go $1 already installed"
    __golang__export_env
    return 0
  fi

  __golang__download_and_extract "$1" || return 1
  __golang__export_env
  log "go $1 ready"
}

: <<'PUB_FUN'
Removes the Go toolchain from under the prefix.
PUB_FUN
golang__uninstall() {
  __golang__privileged rm -rf "$(golang__root)"
}

: <<'PUB_FUN'
Builds the Go module $1 at version $2 with `go install`, into the Go tool
home, and records that home's bin directory for every later shell.

  golang__install_package github.com/evilmartians/lefthook 1.13.6
PUB_FUN
golang__install_package() {
  __golang__install_package__gopath="$(golang__gopath)"

  export GOPATH="$__golang__install_package__gopath"
  export PATH="$__golang__install_package__gopath/bin:$PATH"
  self__add_persistent_path "$__golang__install_package__gopath/bin"
  go install "$1@v$2"
}

: <<'FUN'
Puts the toolchain's and the Go tool home's bin directories on PATH, for
this shell and for every later shell that sources .envrc, and offers the
same to the interactive shell's rc file.
FUN
__golang__export_env() {
  __golang__export_env__root_bin="$(golang__root)/bin"
  __golang__export_env__gopath_bin="$(golang__gopath)/bin"

  export PATH="$__golang__export_env__gopath_bin:$__golang__export_env__root_bin:$PATH"
  self__add_persistent_path "$__golang__export_env__root_bin"
  self__add_persistent_path "$__golang__export_env__gopath_bin"
  shell_rc__offer_line \
    "Go toolchain and go install binaries" \
    "export PATH=\"$__golang__export_env__gopath_bin:$__golang__export_env__root_bin:\$PATH\""
}

: <<'FUN'
Downloads the release archive for version $1 and extracts it under the
prefix, replacing whatever Go sat there.
FUN
__golang__download_and_extract() {
  __golang__download_and_extract__archive="$(golang__archive_name "$1")"
  __golang__download_and_extract__tmpdir="$(mktemp -d)"
  __golang__download_and_extract__file="$__golang__download_and_extract__tmpdir/$__golang__download_and_extract__archive"

  log "downloading go $1 from $GOLANG_BASE_URL/$__golang__download_and_extract__archive"
  if ! http__download "$GOLANG_BASE_URL/$__golang__download_and_extract__archive" "$__golang__download_and_extract__file"; then
    rm -rf "$__golang__download_and_extract__tmpdir"
    return 1
  fi

  __golang__privileged rm -rf "$(golang__root)"
  __golang__privileged tar -C "$(golang__prefix)" -xzf "$__golang__download_and_extract__file"
  __golang__download_and_extract__status=$?
  rm -rf "$__golang__download_and_extract__tmpdir"
  return "$__golang__download_and_extract__status"
}

: <<'FUN'
Runs the command as the caller when the prefix is theirs to write, and
through sudo otherwise, so a prefix under the tools home needs no root and
/usr/local gets it.
FUN
__golang__privileged() {
  if [ -w "$(golang__prefix)" ]; then
    "$@"
  else
    sudo "$@"
  fi
}
