#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
Reading the crates a Cargo manifest depends on, from the manifest alone.

One awk pass over every manifest (manifest_deps.awk) records each dependency
that names a path, each that defers to the workspace, and each path the
workspace root declares; edges.awk then resolves every one to the manifest it
names, so no cargo has to be installed to read the graph.
FRAGMENT

__testing__imports__cargo__DIR="$SHELLOPS_DIR/lib/testing/imports/cargo"

: <<'PUB_FUN'
Prints the dependencies among the manifests in <files> (one per line,
$PROJ-relative) as a struct array of {from, to} edges between manifests,
project-relative and unique. A dependency fetched from a registry, or a
`workspace = true` one the root declares without a path, carries no edge.

  testing__imports__cargo__edges 'engine/Cargo.toml
  engine/cli/Cargo.toml
  engine/parser/Cargo.toml'
  ->  [{"from": "engine/cli/Cargo.toml", "to": "engine/parser/Cargo.toml"}]

Usage: testing__imports__cargo__edges <files>
PUB_FUN
testing__imports__cargo__edges() {
  __testing__imports__cargo__IMPORTS_CARGO_EDGES_RECORDS="$(
    cd "$PROJ" || exit 1
    args__call_with_lines __testing__imports__cargo__awk "$1"
  )" || return 1
  @split __testing__imports__cargo__IMPORTS_CARGO_EDGES_LINES "$__testing__imports__cargo__IMPORTS_CARGO_EDGES_RECORDS" || return 1

  @run_awk __testing__imports__cargo__edges__out "$__testing__imports__cargo__DIR/edges.awk" \
    "$__testing__imports__cargo__IMPORTS_CARGO_EDGES_LINES" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" \
    --load "$SHELLOPS_DIR/lib/testing/imports/edges.awk" || return 1
  println "$__testing__imports__cargo__edges__out"
}

: <<'FUN'
Runs the manifest reader over <manifests...> in the current directory.
Prints nothing for no manifests.

Usage: __testing__imports__cargo__awk [manifest...]
FUN
__testing__imports__cargo__awk() {
  [ "$#" -gt 0 ] || return 0

  awk -f "$__testing__imports__cargo__DIR/manifest_deps.awk" "$@"
}
