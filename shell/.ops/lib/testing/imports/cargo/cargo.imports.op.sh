#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/imports/cargo/manifests.sh"

:<<'DOC'
The import provider for cargo manifests. A Rust crate's loads of other
workspace crates are declared in its Cargo.toml, as path dependencies or as
`workspace = true` entries the root's [workspace.dependencies] resolves, so
the provider reads manifests rather than source: an edge runs from a
crate's manifest to the manifest of each crate it depends on. `mod` and
`use` inside a crate stay inside the crate's area and carry no edge. See
lib/testing/imports/registry.sh for what the roles mean.
DOC
@imports.cargo() {
  :<<'FUN'
Every Cargo.toml is a cargo file to the classifier.
FUN
  @language() {
    printf 'cargo\n'
  }

  :<<'FUN'
The dependencies declared among the given manifests, one edge per path
dependency, resolved to the manifest it names.
FUN
  @edges() {
    testing__imports__cargo__edges "$1"
  }
}
