#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/cargo/api.sh" \
  "$SHELLOPS_DIR/lib/ecosystems/declaration.sh" \
  "$SHELLOPS_DIR/lib/rust/api.sh"

: <<'FRAGMENT'
What the cargo ecosystem does for a release (cargo.ecosystem.op.sh beside
this file): writes the version into the crate the repository declares under
the cargo ecosystem (lib/ecosystems/declaration.sh), and names the files
that writes.
FRAGMENT

: <<'FUN'
Writes version $1 into the declared crate and refreshes its lockfile,
provisioning the toolchain first. Prints nothing: what the installer
reports goes to stderr, so a caller that captures this sync, such as the
record write, reads only its own value.
FUN
__cargo__ecosystem__sync_version() {
  __cargo__ecosystem__sync_version__path="$(__cargo__ecosystem__path)"
  __cargo__ecosystem__sync_version__workspace="$(__cargo__ecosystem__workspace)"

  "$SHELLOPS_DIR/cli/install" rustup >&2
  "$SHELLOPS_DIR/action" cargo sync-version \
    --workspace "$__cargo__ecosystem__sync_version__workspace" \
    --cargo-path "$__cargo__ecosystem__sync_version__path" \
    "$1"
}

: <<'FUN'
Prints the files the version sync writes, as an array of paths: the lockfile
beside the declared Cargo.toml, then every manifest the sync writes.

  __cargo__ecosystem__version_files  ->  ["engine/Cargo.lock", "/p/engine/Cargo.toml"]
FUN
__cargo__ecosystem__version_files() {
  __cargo__ecosystem__version_files__crate="$(__cargo__ecosystem__path)"
  __cargo__ecosystem__version_files__lockfile="$(dirname "$__cargo__ecosystem__version_files__crate")/Cargo.lock"
  __cargo__ecosystem__version_files__manifests="$(__cargo__ecosystem__manifests)" || return 1

  @arr __cargo__ecosystem__version_files__arr_1 "$__cargo__ecosystem__version_files__lockfile"
  @concat __cargo__ecosystem__version_files__out "$__cargo__ecosystem__version_files__arr_1" "$__cargo__ecosystem__version_files__manifests"
  println "$__cargo__ecosystem__version_files__out"
}

: <<'FUN'
The Cargo manifests the version sync writes: the workspace manifest plus every
member that pins an internal dep in workspace mode, the one Cargo.toml
otherwise. Reading a workspace needs cargo, so that branch fails when the
job has not provisioned it.
FUN
__cargo__ecosystem__manifests() {
  __cargo__ecosystem__manifests__path="$(__cargo__ecosystem__path)"
  if @is_true "$(__cargo__ecosystem__workspace)"; then
    __cargo__ecosystem__require_cargo || return 1
    cargo__workspace_sync_manifests "$__cargo__ecosystem__manifests__path"
    return
  fi

  @arr __cargo__ecosystem__manifests__out "$__cargo__ecosystem__manifests__path"
  println "$__cargo__ecosystem__manifests__out"
}

: <<'FUN'
Puts the provisioned toolchain on this process's PATH and fails, naming
what to run, when cargo is still not there. A role never installs a tool:
the job provisions cargo with `ops install rustup` before it calls a step
that reads the workspace, and this check is where a job that did not finds
out.
FUN
__cargo__ecosystem__require_cargo() {
  rustup__prepare_cargo
  if @is_true "$(__cargo__ecosystem__cargo_present)"; then
    return 0
  fi
  error "cargo ecosystem: cargo is not on PATH, and reading the workspace needs it; run 'ops install rustup' before this step."
  return 1
}

: <<'FUN'
Prints true when cargo is on PATH, false otherwise.
FUN
__cargo__ecosystem__cargo_present() {
  if command -v cargo >/dev/null 2>&1; then
    @true __cargo__ecosystem__cargo_present__out
  else
    @false __cargo__ecosystem__cargo_present__out
  fi
  println "$__cargo__ecosystem__cargo_present__out"
}

: <<'FUN'
Prints the path of the declared crate's Cargo.toml, Cargo.toml at the root
when the declaration names none.
FUN
__cargo__ecosystem__path() {
  ecosystems__setting cargo path Cargo.toml
}

: <<'FUN'
Prints true when the declared crate is a workspace, which it is unless the
declaration says otherwise.
FUN
__cargo__ecosystem__workspace() {
  @true __cargo__ecosystem__workspace__true_2
  ecosystems__setting cargo workspace "$__cargo__ecosystem__workspace__true_2"
}
