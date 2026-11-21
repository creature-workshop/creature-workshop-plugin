#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Questions about where a path sits, answered from its text alone: nothing here
touches the file system, so a path that does not exist yet gets the same
answer as one that does.

The arithmetic lives in paths.awk, a library an awk program loads ahead of
itself with a second -f, so a shell caller and an awk program place a path
the same way.
MODULE

__path__AWK_DIR="$SHELLOPS_DIR/lib/path"

: <<'PUB_FUN'
Prints true when <folder>, a relative path of whole segments, is one of the
directories <path> sits under, false otherwise. <path> may be relative or
absolute.

  path__is_under adrs/0007-fragments/adr.md adrs              ->  true
  path__is_under /repo/docs/decisions/000034-a.md docs/decisions  ->  true
  path__is_under notes/adrs.md adrs                           ->  false

Usage: path__is_under <path> <folder>
PUB_FUN
path__is_under() {
  @succeeds __path__is_under__out awk \
    -f "$__path__AWK_DIR/paths.awk" \
    -f "$__path__AWK_DIR/is_under.awk" \
    -v path="$1" \
    -v folder="$2"
  println "$__path__is_under__out"
}

: <<'PUB_FUN'
Prints the last segment of <path>: the file's name, or the directory's when
the path names one.

  path__basename adrs/000007-fragments/tables/kinds.md  ->  kinds.md
  path__basename /repo/adrs/000007-fragments            ->  000007-fragments

Usage: path__basename <path>
PUB_FUN
path__basename() {
  awk \
    -f "$__path__AWK_DIR/paths.awk" \
    -f "$__path__AWK_DIR/basename.awk" \
    -v path="$1"
}
