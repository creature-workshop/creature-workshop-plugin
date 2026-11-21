#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/ecosystems/declaration.sh" \
  "$SHELLOPS_DIR/lib/kinds/api.sh"

: <<'MODULE'
The ecosystems a repository is written in, as it declares them once, in
.ops/config/ecosystems.yaml or the manifest's `ecosystems` (ADR 000006, ADR
000049, lib/ecosystems/declaration.sh), and what each does for a release
(ADR 000008). A release names no language: it asks every declared ecosystem to
write the version into its own files and to say which files that was.

An ecosystem is a plugin of kind ecosystem (lib/kinds/api.sh says how a kind
loads), a file named <id>.ecosystem.op.sh in the ecosystem's own module
defining @ecosystem.<id>() with these roles, the release roles of ADR 000008
being its first:

  @summary                  The ecosystem in one line.
  @sync_version <version>   Writes the version into the ecosystem's files,
                            refreshing any lockfile and provisioning its own
                            toolchain.
  @version_files            The files that sync writes, as a struct array, so
                            a release commit names exactly them.

ADR 000008 also names @schema, @defaults and @version; nothing calls them
yet, and an ecosystem may leave them out until something does.

A manifest declaring an id no ecosystem is registered under is refused
before anything is written or read. Importing this module loads every
ecosystem under lib/.
MODULE

__ecosystems__ROLES="summary schema defaults version sync_version version_files"
__ecosystems__REQUIRED="sync_version version_files"

: <<'PUB_FUN'
Loads and registers the ecosystem <id>, whose plugin file has been imported.
See kinds__load.
PUB_FUN
ecosystems__load() {
  kinds__load ecosystem "$1" "$__ecosystems__ROLES" "$__ecosystems__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every ecosystem under <root>. See kinds__scan.
PUB_FUN
ecosystems__load_ecosystems() {
  kinds__scan ecosystem "$1" "$__ecosystems__ROLES" "$__ecosystems__REQUIRED"
}

: <<'PUB_FUN'
Prints the ids of every registered ecosystem, as a struct array, in load
order.
PUB_FUN
ecosystems__names() {
  kinds__names ecosystem
}

: <<'PUB_FUN'
Prints the ids the manifest declares, as a struct array sorted by id; empty
for a manifest declaring none.

  ecosystems__declared  ->  ["cargo"]
PUB_FUN
ecosystems__declared() {
  __ecosystems__declared__declaration="$(ecosystems__declaration)" || return 1
  @keys __ecosystems__declared__out "$__ecosystems__declared__declaration"
  println "$__ecosystems__declared__out"
}

: <<'PUB_FUN'
Writes version $1 into every declared ecosystem's files. Non-zero when a
declared ecosystem is not registered or its sync fails.
PUB_FUN
ecosystems__sync_version() {
  __ecosystems__require_registered || return 1
  @foreach __ecosystems__sync_one "$(ecosystems__declared)" "$1"
}

: <<'FUN'
@foreach callback: writes version $2 through the wrapped ecosystem $1.
FUN
__ecosystems__sync_one() {
  @unwrap __ecosystems__sync_one__unwrap_1 "$1"
  kinds__call ecosystem "$__ecosystems__sync_one__unwrap_1" sync_version "$2"
}

: <<'PUB_FUN'
Prints the files every declared ecosystem's sync writes, as one array, the
ecosystems sorted by id; empty for a manifest declaring none. Non-zero, and
prints nothing, when a declared ecosystem is not registered or its role
fails, so a caller never reads a list with an ecosystem's files missing.

  ecosystems__version_files  ->  ["engine/Cargo.lock", "/p/engine/Cargo.toml"]
PUB_FUN
ecosystems__version_files() {
  __ecosystems__require_registered || return 1
  @arr __ecosystems__append_files__files  # private-name-check: allow -- the list the callback gathers across the walk, started empty here
  @foreach __ecosystems__append_files "$(ecosystems__declared)" || return 1
  println "$__ecosystems__append_files__files"
}

: <<'FUN'
@foreach callback: appends the files of the wrapped ecosystem $1 to the
list in __ecosystems__append_files__files, which ecosystems__version_files
starts empty and prints after the walk. Fails when the role does, and the
walk stops there.
FUN
__ecosystems__append_files() {
  @unwrap __ecosystems__append_files__id "$1"
  __ecosystems__append_files__role="$(kinds__call ecosystem "$__ecosystems__append_files__id" version_files)" || return 1
  @concat __ecosystems__append_files__files "$__ecosystems__append_files__files" "$__ecosystems__append_files__role"
}

: <<'FUN'
Succeeds quietly when every declared ecosystem is registered; otherwise
names the first that is not, and the ecosystems there are, and returns 1
before any role runs.
FUN
__ecosystems__require_registered() {
  @foreach __ecosystems__require_one "$(ecosystems__declared)"
}

: <<'FUN'
@foreach callback: fails when the wrapped ecosystem $1 is not registered.
See kinds__require_known.
FUN
__ecosystems__require_one() {
  @unwrap __ecosystems__require_one__unwrap_4 "$1"
  kinds__require_known ecosystem "$__ecosystems__require_one__unwrap_4"
}

ecosystems__load_ecosystems "$SHELLOPS_DIR/lib"
