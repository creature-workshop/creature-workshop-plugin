#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/language/api.sh" \
  "$SHELLOPS_DIR/lib/testing/imports/registry.sh" \
  "$SHELLOPS_DIR/lib/testing/imports/providers.sh"

: <<'MODULE'
The import graph of a project: which tracked file loads which, read from the
source by the provider registered for each file's language.

  testing__imports__import_edges   the edges among a set of tracked files

Usage:
  import "$SHELLOPS_DIR/lib/testing/imports/api.sh"

  testing__imports__import_edges "$(@split "$(git__tracked_files "$PROJ")")"
MODULE

__testing__imports__EDGES_AMONG="$SHELLOPS_DIR/lib/testing/imports/edges_among.awk"
__testing__imports__FILES_OF_LANGUAGE="$SHELLOPS_DIR/lib/testing/imports/files_of_language.awk"
__testing__imports__NL="
"

: <<'PUB_FUN'
Prints the loads among the tracked <files> (a struct array of $PROJ-relative
paths) as a struct array of {from, to} edges, sorted and unique. Each
language with a provider is read in one pass by that provider, and an edge
to a file outside <files> is dropped; a file of a language with no provider
loads nothing as far as this graph knows.

  testing__imports__import_edges '["lib/git/api.sh", "lib/structs/api.sh", "engine/cli/Cargo.toml", "engine/parser/Cargo.toml"]'
  ->  [{"from": "engine/cli/Cargo.toml", "to": "engine/parser/Cargo.toml"},
       {"from": "lib/git/api.sh", "to": "lib/structs/api.sh"}]

Usage: testing__imports__import_edges <files>
PUB_FUN
testing__imports__import_edges() {
  @join __testing__imports__TESTING_IMPORT_EDGES_PATHS "$1" "$__testing__imports__NL" || return 1
  __testing__imports__TESTING_IMPORT_EDGES_LINES="$(language__of_paths \
    "$PROJ" \
    "$__testing__imports__TESTING_IMPORT_EDGES_PATHS"
  )" || return 1
  @arr __testing__imports__import_edges__arr_1
  @reduce __testing__imports__TESTING_IMPORT_EDGES_READ __testing__imports__edges_of_language \
    "$(testing__imports__provider_languages)" \
    "$__testing__imports__import_edges__arr_1" \
    "$__testing__imports__TESTING_IMPORT_EDGES_LINES" || return 1

  @run_awk __testing__imports__import_edges__out "$__testing__imports__EDGES_AMONG" \
    "$__testing__imports__TESTING_IMPORT_EDGES_READ" \
    --with "$1" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" \
    --load "$SHELLOPS_DIR/lib/testing/imports/edges.awk" || return 1
  println "$__testing__imports__import_edges__out"
}

: <<'FUN'
@reduce callback: adds the edges among one language's files, as its
provider reads them, to the accumulator.

args:
  $1  The accumulator (the edges so far)
  $2  The language (wrapped)
  $3  The language lines (from language__of_paths)
FUN
__testing__imports__edges_of_language() {
  @unwrap __testing__imports__edges_of_language__language "$2"
  __testing__imports__edges_of_language__provider="$(testing__imports__provider_for \
    "$__testing__imports__edges_of_language__language"
  )"
  __testing__imports__edges_of_language__files="$(__testing__imports__files_of_language \
    "$3" \
    "$__testing__imports__edges_of_language__language"
  )"
  __testing__imports__edges_of_language__edges="$(testing__imports__provider_edges \
    "$__testing__imports__edges_of_language__provider" \
    "$__testing__imports__edges_of_language__files"
  )" || return 1

  @concat __testing__imports__edges_of_language__out "$1" "$__testing__imports__edges_of_language__edges"
  println "$__testing__imports__edges_of_language__out"
}

: <<'FUN'
Prints the paths in the language <lines> whose language is <language>, one
per line.

Usage: __testing__imports__files_of_language <lines> <language>
FUN
__testing__imports__files_of_language() {
  println "$1" \
    | awk \
      -v language="$2" \
      -f "$__testing__imports__FILES_OF_LANGUAGE"
}
