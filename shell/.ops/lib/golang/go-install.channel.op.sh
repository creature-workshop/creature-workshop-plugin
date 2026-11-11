#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/golang/api.sh"

: <<'DOC'
Channel plugin for installing Go tools with `go install`, into the Go tool
home lib/golang names.

Requirements:
  version   module version to install
  pkg       required Go module path
DOC

: <<'FUN'
Builds the tool $1 from the module its entry $2 names, at the pinned
version. Fails, naming the tool, when the entry names no module or no go is
on PATH.
FUN
__golang__install__install() {
  @get __golang__install__install__version "$2" '.version'
  @get __golang__install__install__pkg "$2" '.pkg'

  if ! @defined "$__golang__install__install__pkg"; then
    error "go-install tool '$1' requires a 'pkg' field in manifest"
    return 1
  fi

  if ! command -v go >/dev/null 2>&1; then
    error "go-install tool '$1' requires Go on PATH (install the 'go' tool first)"
    return 1
  fi

  golang__install_package "$__golang__install__install__pkg" "$__golang__install__install__version"
}

: <<'FUN'
Removes the tool $1's binary from wherever PATH resolves it, and nothing
when PATH does not.
FUN
__golang__install__uninstall() {
  __golang__install__uninstall__bin="$(command -v "$1" 2>/dev/null || true)"

  if @defined "$__golang__install__uninstall__bin"; then
    rm -f "$__golang__install__uninstall__bin"
  fi
}

:<<'DOC'
The go-install channel: one channel plugin. See lib/toolchain/channel.sh for
what the roles mean.
DOC
@channel.go-install() {
  @summary() {
    println "Go tools into the Go tool home, with go install."
  }

  @install_tool() {
    __golang__install__install "$@"
  }

  @uninstall_tool() {
    __golang__install__uninstall "$@"
  }

  @dependency() {
    printf 'go\n'
  }

  @dependency_default() {
    @obj __at_out \
      '.channel' 'script' \
      '.version' '1.25.5'
    println "$__at_out"
  }
}
