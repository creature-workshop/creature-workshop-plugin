#!/bin/sh

import "$SHELLOPS_DIR/lib/rustup/_toolchain.sh"

: <<'MODULE'
Where the Rust toolchain lives and how it gets there: the cargo and rustup
homes, the rustup installer and uninstaller, adding a toolchain with its
components to a rustup a cache restored, and whether the pinned toolchain
is whole. Every function settles both homes before it runs anything, so an
installer, a later job step and a developer shell all find the one
toolchain.
MODULE

: <<'PUB_FUN'
Prints the directory cargo keeps its binaries and registry in. A CARGO_HOME the
caller set wins; otherwise it is the shellops tool home for cargo, so a CI job
that points SHELLOPS_TOOLS_HOME at a cached directory keeps the toolchain in
the cache, and a developer shell keeps ~/.cargo.

    rustup__cargo_home                                        ->  /home/me/.cargo
    SHELLOPS_TOOLS_HOME=/p/.ops/cache/tools rustup__cargo_home  ->  /p/.ops/cache/tools/cargo
PUB_FUN
rustup__cargo_home() {
  echo "${CARGO_HOME:-$(self__tool_home .cargo)}"
}

: <<'PUB_FUN'
Prints the directory rustup keeps its toolchains in, on the same terms as
rustup__cargo_home: a RUSTUP_HOME the caller set wins, otherwise the shellops tool
home for rustup.

    rustup__home                                        ->  /home/me/.rustup
    SHELLOPS_TOOLS_HOME=/p/.ops/cache/tools rustup__home  ->  /p/.ops/cache/tools/rustup
PUB_FUN
rustup__home() {
  echo "${RUSTUP_HOME:-$(self__tool_home .rustup)}"
}

: <<'FUN'
Puts CARGO_HOME and RUSTUP_HOME in the environment of everything this process
runs from here on, at the homes rustup__cargo_home and rustup__home name.

rustup, cargo and every crate installed through them read those two variables
to find the toolchain, so a caller that is about to run one of them exports
both first and they all agree on one location.
FUN
__rustup__export_homes() {
  CARGO_HOME="$(rustup__cargo_home)"
  RUSTUP_HOME="$(rustup__home)"
  export CARGO_HOME RUSTUP_HOME
}

: <<'FUN'
Settles where the Rust toolchain lives before an installer writes it there:
exports both homes for this process, and records them in .ops/cache/env.sh so
every later job step reads the same two values and finds the toolchain the
cache restored.
FUN
__rustup__adopt_homes() {
  __rustup__export_homes
  self__add_persistent_env CARGO_HOME "$CARGO_HOME"
  self__add_persistent_env RUSTUP_HOME "$RUSTUP_HOME"
}

__rustup__ensure_path() {
  __rustup__ensure_path__cargo_bin="$(rustup__cargo_home)/bin"

  if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$__rustup__ensure_path__cargo_bin" >> "$GITHUB_PATH"
  fi

  self__add_persistent_path "$__rustup__ensure_path__cargo_bin"
  export PATH="$__rustup__ensure_path__cargo_bin:$PATH"
}

: <<'PUB_FUN'
Points CARGO_HOME and RUSTUP_HOME at the toolchain, sources the rustup/cargo
env file and prepends cargo's bin dir to PATH.

For an action that needs cargo in a fresh subprocess. `ops install` provisions
cargo and records it to .ops/cache/env.sh (sourced by .envrc); this is the
in-process equivalent for code paths that run before that activation.

  rustup__prepare_cargo
PUB_FUN
rustup__prepare_cargo() {
  __rustup__export_homes
  rustup__source_cargo_env
  __rustup__ensure_path
}

rustup__source_cargo_env() {
  __rustup__source_cargo_env__cargo_env="$(rustup__cargo_home)/env"
  [ -f "$__rustup__source_cargo_env__cargo_env" ] || return 0
  # shellcheck disable=SC1091
  . "$__rustup__source_cargo_env__cargo_env"
}

: <<'PUB_FUN'
Runs the upstream rustup installer, into the homes __rustup__adopt_homes
settles on, and leaves cargo on PATH for this process and for the steps after
it.

  rustup__install "1.28.2" -y --profile minimal

args:
  $1  The rustup version to install, or "" for whatever upstream serves
  $@  The remaining arguments, passed to the installer script
PUB_FUN
rustup__install() {
  __rustup__install__version="${1:-}"
  if [ "$#" -gt 0 ]; then
    shift
  fi

  __rustup__adopt_homes

  __rustup__install__installer="$(curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs)"

  if [ -n "$__rustup__install__version" ]; then
    RUSTUP_VERSION="$__rustup__install__version" sh -c "$__rustup__install__installer" -- "$@"
  else
    sh -c "$__rustup__install__installer" -- "$@"
  fi

  rustup__source_cargo_env
  __rustup__ensure_path
}

: <<'PUB_FUN'
Hands the rustup installation the two homes it was installed under and asks it
to remove itself, so `ops uninstall rustup` takes out the toolchain this
project provisioned rather than one in the developer's $HOME.
PUB_FUN
rustup__uninstall() {
  __rustup__export_homes
  rustup__source_cargo_env

  if command -v rustup >/dev/null 2>&1; then
    rustup self uninstall -y
  fi
}

__rustup__ensure() {
  __rustup__ensure__toolchain="$1"
  shift

  if command -v rustup >/dev/null 2>&1; then
    __rustup__install_toolchain "$__rustup__ensure__toolchain" "$@"
    return
  fi

  __rustup__install_with_toolchain "$__rustup__ensure__toolchain" "$@"
}

__rustup__install_with_toolchain() {
  __rustup__install_with_toolchain__toolchain="$1"
  shift

  # Render the components as "-c <name>" installer flags. Component names are
  # single tokens, so the word split below is safe. Plain shell, because this
  # runs while cli/install may still be on the awk structs backend, which
  # answers no jq-expression verb.
  __rustup__install_with_toolchain__flags=""
  for __rustup__install_with_toolchain__component in "$@"; do
    __rustup__install_with_toolchain__flags="$__rustup__install_with_toolchain__flags -c $__rustup__install_with_toolchain__component"
  done

  # shellcheck disable=SC2086
  rustup__install "" -y --default-toolchain "$__rustup__install_with_toolchain__toolchain" --profile minimal $__rustup__install_with_toolchain__flags
}

: <<'FUN'
Adds a toolchain and its components to an existing rustup, in the homes
__rustup__adopt_homes settles on — the warm path, where a cache restored
rustup itself and only the toolchain is missing. A toolchain the cache
restored half-installed is removed first, so that rustup installs it again
rather than trusting what is there.

args:
  $1  The toolchain to install (stable, nightly, 1.90.0...)
  $@  The components to add to it
FUN
__rustup__install_toolchain() {
  __rustup__install_toolchain__toolchain="$1"
  shift

  __rustup__adopt_homes
  __rustup__remove_broken_toolchain "$__rustup__install_toolchain__toolchain"
  rustup toolchain install "$__rustup__install_toolchain__toolchain" --profile minimal

  @arr __rustup__install_toolchain__arr_1 "$@"
  @foreach __rustup__add_component "$__rustup__install_toolchain__arr_1" "$__rustup__install_toolchain__toolchain"
}

__rustup__add_component() {
  @unwrap __rustup__add_component__unwrap_2 "$1"
  rustup component add "$__rustup__add_component__unwrap_2" --toolchain "$2"
}
