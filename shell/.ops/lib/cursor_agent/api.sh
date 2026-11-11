#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/http/api.sh" \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/xplat/api.sh"

: <<'MODULE'
The Cursor CLI, `agent`, as a pinned tool.

Cursor publishes the CLI as one tarball per version and platform, and its
own install script fetches whichever version the script was cut for into
the user's home. This library fetches the version ops.lock pins into the
tools home instead, so a job on a plain image provisions it like any other
tool, the tools cache carries it between jobs, and a bump is a lock change.
The tool plugin beside this file, cursor-agent.tool.op.sh, hands the
version over; the cursor-cli agent adaptor (lib/agents/cursor-cli) is what
runs it.
MODULE

__cursor_agent__BASE_URL="https://downloads.cursor.com/lab"

: <<'PUB_FUN'
Prints the directory Cursor CLI versions install under: CURSOR_AGENT_HOME
when set, otherwise the cursor-agent entry of the tools home.
PUB_FUN
cursor_agent__home() {
  println "${CURSOR_AGENT_HOME:-$(self__tool_home .cursor-agent)}"
}

: <<'PUB_FUN'
Prints the install directory for Cursor CLI version $1.
PUB_FUN
cursor_agent__install_dir() {
  println "$(cursor_agent__home)/cursor-agent-$1"
}

: <<'PUB_FUN'
Prints the directory `agent` is linked in for version $1, the one PATH gets.
The package itself is hundreds of files, so PATH carries this and not it.
PUB_FUN
cursor_agent__bin_dir() {
  println "$(cursor_agent__install_dir "$1")/bin"
}

: <<'PUB_FUN'
Prints the URL of the package for Cursor CLI version $1 on this platform.
Cursor spells the platform as linux or darwin over x64 or arm64; a host it
does not build for fails naming its architecture.

    cursor_agent__tarball_url 2026.09.15-d2fe57e
    -> https://downloads.cursor.com/lab/2026.09.15-d2fe57e/linux/x64/agent-cli-package.tar.gz
PUB_FUN
cursor_agent__tarball_url() {
  __cursor_agent__tarball_url__arch="$(__cursor_agent__arch)" || return 1
  println "${__cursor_agent__BASE_URL}/$1/$(__cursor_agent__os)/${__cursor_agent__tarball_url__arch}/agent-cli-package.tar.gz"
}

: <<'FUN'
Prints the operating system as Cursor's download path spells it.

    __cursor_agent__os  ->  linux
FUN
__cursor_agent__os() {
  case "$(uname -s)" in
    Darwin) printf 'darwin\n' ;;
    *) printf 'linux\n' ;;
  esac
}

: <<'FUN'
Prints the architecture as Cursor's download path spells it, and fails on
one Cursor does not build for.

    __cursor_agent__arch  ->  x64
FUN
__cursor_agent__arch() {
  case "$(xplat__arch_uname)" in
    x86_64|amd64) printf 'x64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *)
      error "cursor-agent: Cursor builds no CLI for $(xplat__arch_uname)"
      return 1
      ;;
  esac
}

: <<'PUB_FUN'
Prints true when Cursor CLI version $1 is installed in the tools home, false
otherwise.
PUB_FUN
cursor_agent__installed() {
  @succeeds __cursor_agent__installed__out [ -x "$(cursor_agent__bin_dir "$1")/agent" ]
  println "$__cursor_agent__installed__out"
}

: <<'PUB_FUN'
Installs Cursor CLI version $1 into the tools home and puts `agent` on PATH.
The version comes from ops.lock through the tool plugin, the one place it
is written; an empty one fails. A version already installed is only put on
PATH.
PUB_FUN
cursor_agent__install() {
  if ! @defined "${1:-}"; then
    error "cursor_agent__install: a version is required; ops.lock pins it"
    return 1
  fi

  if @is_true "$(cursor_agent__installed "$1")"; then
    log "cursor-agent $1 already installed"
    __cursor_agent__export_env "$1"
    return 0
  fi

  __cursor_agent__install__url="$(cursor_agent__tarball_url "$1")" || return 1
  log "downloading cursor-agent $1 from $__cursor_agent__install__url"
  __cursor_agent__download_and_extract "$__cursor_agent__install__url" "$1" || return 1
  __cursor_agent__link_agent "$1"
  __cursor_agent__export_env "$1"
  log "cursor-agent $1 ready"
}

: <<'PUB_FUN'
Removes Cursor CLI version $1 from the tools home.
PUB_FUN
cursor_agent__uninstall() {
  rm -rf "$(cursor_agent__install_dir "$1")"
}

: <<'FUN'
Downloads the package at $1 and extracts it into the install directory for
version $2, dropping the package's one enclosing directory so `cursor-agent`
sits at the top of the install directory.
FUN
__cursor_agent__download_and_extract() {
  __cursor_agent__download_and_extract__dir="$(cursor_agent__install_dir "$2")"
  __cursor_agent__download_and_extract__tmpfile="$(mktemp)"

  mkdir -p "$__cursor_agent__download_and_extract__dir"
  if ! http__download "$1" "$__cursor_agent__download_and_extract__tmpfile"; then
    rm -f "$__cursor_agent__download_and_extract__tmpfile"
    return 1
  fi

  tar --strip-components=1 -xzf "$__cursor_agent__download_and_extract__tmpfile" -C "$__cursor_agent__download_and_extract__dir"
  rm -f "$__cursor_agent__download_and_extract__tmpfile"
}

: <<'FUN'
Links `agent`, and the older name `cursor-agent`, in the bin directory of
version $1 to the executable the package ships.
FUN
__cursor_agent__link_agent() {
  __cursor_agent__link_agent__bin="$(cursor_agent__bin_dir "$1")"

  mkdir -p "$__cursor_agent__link_agent__bin"
  ln -sf ../cursor-agent "$__cursor_agent__link_agent__bin/agent"
  ln -sf ../cursor-agent "$__cursor_agent__link_agent__bin/cursor-agent"
}

: <<'FUN'
Puts the bin directory of version $1 on PATH, for this shell and for every
later shell that sources .envrc.
FUN
__cursor_agent__export_env() {
  __cursor_agent__export_env__bin="$(cursor_agent__bin_dir "$1")"
  export PATH="${__cursor_agent__export_env__bin}:${PATH}"
  self__add_persistent_path "$__cursor_agent__export_env__bin"
}
