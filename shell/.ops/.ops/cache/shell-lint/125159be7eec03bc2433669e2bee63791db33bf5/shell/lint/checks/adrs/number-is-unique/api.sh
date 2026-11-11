#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/api.sh"

: <<'MODULE'
The adr-number-is-unique check. A record's number is how every other file
cites it, so a number belongs to one record. Two branches that each take
the next free number both look right until the second one lands; the check
says so on the branch, by reading the default branch as well as the working
tree.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__adrs__number_is_unique__DIR="$SHELL_LINT_DIR/shell/lint/checks/adrs/number-is-unique"

: <<'PUB_FUN'
Prints a finding for each of <files...> that is a decision record under PROJ
whose number another record carries: one beside it in the working tree, or one
the default branch has added since HEAD forked from it. A file that is not a
decision record is passed over. <opts>.config names the folder.

  lint__checks__adrs__number_is_unique__run "$(@obj)" docs/decisions/000034-a-climb.md
    ->  docs/decisions/000034-a-climb.md:1: number 000034 is taken by 000034-a-bundle.md
  lint__checks__adrs__number_is_unique__run "$opts" adrs/000007-fragments/adr.md
    ->  adrs/000007-fragments/adr.md:1: number 000007 is taken by 000007-singlets

Returns 0 when every number is its record's alone, 1 otherwise.

Usage: lint__checks__adrs__number_is_unique__run <opts> <files...>
PUB_FUN
lint__checks__adrs__number_is_unique__run() {
  lint__checks__adrs__number_is_unique__run__folder="$(lint__checks__adrs__folder "$1")"
  shift

  {
    lint__checks__adrs__taken_lines "$lint__checks__adrs__number_is_unique__run__folder"
    println "$@" | lint__checks__adrs__tagged file
  } | lint__checks__adrs__awk "$__lint__checks__adrs__number_is_unique__DIR/number_taken.awk" \
    -v folder="$lint__checks__adrs__number_is_unique__run__folder" \
    >&2
}
