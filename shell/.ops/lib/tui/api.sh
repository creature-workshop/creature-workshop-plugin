#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Tables for a terminal, in the shape tokei prints: a heavy rule, a header
row, a rule, the body rows, a rule, the totals, a closing rule.

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Program                       Starts       Share
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   jq                               478       69.9%
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

A row is one label, set left in the first column, and any number of cells,
each set right in a column of its own; it arrives as arguments or as one
struct array, the label first. Every row of one table names the
same number of cells, and the rules take that number so they come out the
width of the rows. Column widths are the module's; a caller that needs
others sets SHELLOPS_TUI_LABEL_WIDTH or SHELLOPS_TUI_CELL_WIDTH before importing.
MODULE

__tui__NL="
"
__tui__LABEL_WIDTH="${SHELLOPS_TUI_LABEL_WIDTH:-24}"
__tui__CELL_WIDTH="${SHELLOPS_TUI_CELL_WIDTH:-12}"
__tui__RULE='━'

: <<'PUB_FUN'
The width in columns of a row with $1 cells: the leading space, the label,
and the cells.

  tui__width 2  ->  49
PUB_FUN
tui__width() {
  printf '%d\n' $((1 + __tui__LABEL_WIDTH + $1 * __tui__CELL_WIDTH))
}

: <<'PUB_FUN'
A heavy rule as wide as a row with $1 cells.
PUB_FUN
tui__rule() {
  __tui__rule__width="$(tui__width "$1")"
  __tui__rule__i=0
  while [ "$__tui__rule__i" -lt "$__tui__rule__width" ]; do
    printf '%s' "$__tui__RULE"
    __tui__rule__i=$((__tui__rule__i + 1))
  done
  printf '\n'
}

: <<'PUB_FUN'
One row: the label set left, then each cell set right in its own column. The
label and cells arrive either as arguments or as one struct array, so a row
built from struct values needs no unpacking at the call site.

  tui__row jq 478 69.9%             ->  " jq                               478       69.9%"
  tui__row "$(@arr jq 478 69.9%)"   ->  the same row

A lone argument that is not a struct array is a label on its own.

args:
  $1  The label, or a struct array holding the label and the cells
  $@  The cells
PUB_FUN
tui__row() {
  if @typeof __tui__row__typeof_1 "$1"; [ "$#" -eq 1 ] && @is_valid "$1" && [ "$__tui__row__typeof_1" = array ]; then
    @join __tui__row__join_2 "$1" "$__tui__NL"
    args__call_with_lines __tui__row_of "$__tui__row__join_2"
    return
  fi

  __tui__row_of "$@"
}

: <<'FUN'
The row itself, from the label and cells as arguments.
FUN
__tui__row_of() {
  printf " %-${__tui__LABEL_WIDTH}s" "$1"
  shift
  for __tui__row_of__cell in "$@"; do
    printf "%${__tui__CELL_WIDTH}s" "$__tui__row_of__cell"
  done
  printf '\n'
}
