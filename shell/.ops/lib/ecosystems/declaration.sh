#!/bin/sh
import \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/self/config.sh"

: <<'MODULE'
The ecosystems a repository declares, read from where it declares them:
.ops/config/ecosystems.yaml (ADR 000049), or the manifest's `ecosystems`
in a repository that has not converted. Every reader of a declaration goes
through here, the ecosystems library and each adaptor alike, so the two
places are read by one rule.

  ecosystems__declaration          ->  {"cargo": {"path": "engine/Cargo.toml", "workspace": true}}
  ecosystems__setting cargo path   ->  engine/Cargo.toml
MODULE

: <<'PUB_FUN'
Prints the declared ecosystems as a struct keyed by id: the config file's
map when the repository has one, else the manifest's `ecosystems`, and an
empty map when the manifest declares none. Fails when the file does not
parse or the manifest cannot be read.

  ecosystems__declaration  ->  {"cargo": {"path": "engine/Cargo.toml", "workspace": true}}
  ecosystems__declaration  ->  {}

Usage: ecosystems__declaration
PUB_FUN
ecosystems__declaration() {
  if [ -f "$(self__config__path ecosystems)" ]; then
    self__config__load ecosystems
    return
  fi
  manifest__get ecosystems
}

: <<'PUB_FUN'
Prints the setting <field> of the declared ecosystem <id>, or <default>
when the declaration leaves it out.

  ecosystems__setting cargo path Cargo.toml   ->  engine/Cargo.toml
  ecosystems__setting cargo workspace true    ->  true

args:
  $1  The ecosystem's id
  $2  The field
  $3  The default, optional
PUB_FUN
ecosystems__setting() {
  __ecosystems__setting__declaration="$(ecosystems__declaration)" || return 1
  @get __ecosystems__setting__out "$__ecosystems__setting__declaration" ".$1.$2" "${3:-}"
  println "$__ecosystems__setting__out"
}
