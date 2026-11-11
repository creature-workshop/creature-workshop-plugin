#!/bin/sh

: <<'MODULE'
The bats side of a golden suite: every fileset under GOLDEN_FIXTURES
registered as a test of its own, once per variant, and one case checked
against its expected.txt.

A fileset is a directory GOLDEN_FIXTURES/<name>/ that contains:

  name.txt      the case's name, which is the test's name in the log
  about.txt     what the case checks, printed when it fails
  calls.txt     the calls the transcript runs
  expected.txt  the transcript they must write

A document that a call reads by name has a directory of its own inside
the fileset, <name>/<document>/, with a name.txt and an about.txt beside
it. golden__unnamed_documents lists the documents that lack them; a
name.txt or an about.txt is never itself a document.

A bats file sets GOLDEN_FIXTURES, loads this file, defines a transcript
function and calls golden__register with that function and the variants
to run under. bats_test_function needs bats 1.5.0, so the bats file calls
bats_require_minimum_version first.

UPDATE_GOLDENS=1 rewrites each expected.txt from the transcript written
under the first variant, to be read before it is committed.
MODULE

: <<'PUB_FUN'
Registers every fileset under GOLDEN_FIXTURES as a test under each
variant, described "golden, <variant>: <name.txt>". With no variant, it
registers each fileset once, described "golden: <name.txt>".

args:
  $1  The transcript function: takes a fileset's name and a variant, and
      prints the transcript of the fileset's calls under that variant
  $@  The variants, any text each; UPDATE_GOLDENS writes under the first
PUB_FUN
golden__register() {
  __golden__register__transcript="$1"
  shift
  if [ "$#" -eq 0 ]; then
    set -- ''
  fi
  GOLDEN_UPDATE_VARIANT="$1"

  for __golden__register__calls in "$GOLDEN_FIXTURES"/*/calls.txt; do
    if [ ! -f "$__golden__register__calls" ]; then
      continue
    fi
    __golden__register__name="$(__golden__fileset_of "$__golden__register__calls")"
    __golden__register_fileset "$__golden__register__transcript" "$__golden__register__name" "$@"
  done
}

: <<'PUB_FUN'
Checks one fileset under one variant: the transcript the function writes
against the fileset's expected.txt. When they differ, prints the diff,
the case's name and its about.txt, and fails. Under UPDATE_GOLDENS=1 and
the first registered variant, rewrites expected.txt first.

args:
  $1  The transcript function
  $2  The fileset's name
  $3  The variant
PUB_FUN
golden__case() {
  __golden__case__fileset="$GOLDEN_FIXTURES/$2"
  __golden__case__actual="$("$1" "$2" "$3")"

  if [ "${UPDATE_GOLDENS:-}" = 1 ] && [ "$3" = "$GOLDEN_UPDATE_VARIANT" ]; then
    printf '%s\n' "$__golden__case__actual" > "$__golden__case__fileset/expected.txt"
  fi

  if ! printf '%s\n' "$__golden__case__actual" | diff "$__golden__case__fileset/expected.txt" -; then
    printf '## %s (%s%s): the transcript differs from %s/expected.txt\n' \
      "$(cat "$__golden__case__fileset/name.txt")" \
      "$2" \
      "${3:+, $3}" \
      "$2"
    cat "$__golden__case__fileset/about.txt"
    false
  fi
}

: <<'PUB_FUN'
Prints every document under the filesets, one per line relative to
GOLDEN_FIXTURES, that has no name.txt or no about.txt beside it. Prints
nothing when every document has both.

args:
  $@  The extensions of the documents, without their dot

  golden__unnamed_documents json yaml  ->  "toml/date/date.json"
PUB_FUN
golden__unnamed_documents() {
  for __golden__unnamed_documents__extension in "$@"; do
    for __golden__unnamed_documents__document in "$GOLDEN_FIXTURES"/*/*/*."$__golden__unnamed_documents__extension"; do
      case "${__golden__unnamed_documents__document##*/}" in
        name.txt | about.txt) continue ;;
      esac
      __golden__unnamed_document "$__golden__unnamed_documents__document"
    done
  done
}

: <<'FUN'
Prints a document's path relative to GOLDEN_FIXTURES when it has no
name.txt or no about.txt beside it, and nothing otherwise. A path that
matched no file is not a document.
FUN
__golden__unnamed_document() {
  if [ ! -f "$1" ]; then
    return
  fi
  if [ ! -f "${1%/*}/name.txt" ] || [ ! -f "${1%/*}/about.txt" ]; then
    printf '%s\n' "${1#"$GOLDEN_FIXTURES/"}"
  fi
}

: <<'FUN'
Registers one fileset as a test under each variant.

args:
  $1  The transcript function
  $2  The fileset's name
  $@  The variants, after those two
FUN
__golden__register_fileset() {
  __golden__register_fileset__transcript="$1"
  __golden__register_fileset__name="$2"
  shift 2
  for __golden__register_fileset__variant in "$@"; do
    bats_test_function \
      --description "$(__golden__description "$__golden__register_fileset__name" "$__golden__register_fileset__variant")" \
      -- golden__case "$__golden__register_fileset__transcript" "$__golden__register_fileset__name" "$__golden__register_fileset__variant"
  done
}

: <<'FUN'
Prints the name of the fileset that a calls.txt belongs to: its
directory's name.
FUN
__golden__fileset_of() {
  __golden__fileset_of__directory="${1%/calls.txt}"
  printf '%s' "${__golden__fileset_of__directory##*/}"
}

: <<'FUN'
Prints a test's description: "golden, <variant>: <name.txt>", or
"golden: <name.txt>" when the variant is empty.

args:
  $1  The fileset's name
  $2  The variant
FUN
__golden__description() {
  printf 'golden%s: %s' "${2:+, $2}" "$(cat "$GOLDEN_FIXTURES/$1/name.txt")"
}
