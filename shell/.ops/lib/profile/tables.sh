#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/profile/_measure.sh" \
  "$SHELLOPS_DIR/lib/profile/columns.sh" \
  "$SHELLOPS_DIR/lib/tui/api.sh"

: <<'MODULE'
The profile report on the terminal: one table per profiler, a row per
command and measure, with the base column, the head column and the
difference between them.
MODULE

: <<'PUB_FUN'
Prints the report as tables, one per profiler: a row per command and
measure with the base, the head and the difference. <base> may be empty, in
which case only the head column is filled.

  $1  Base measurements (may be empty)   $2  Head measurements
PUB_FUN
profile__print_tables() {
  @keys __profile__print_tables__keys_1 "$2"
  @foreach __profile__tables__table "$__profile__print_tables__keys_1" "$1" "$2"
}

: <<'FUN'
@foreach callback: the table of the wrapped <profiler>.

  $1  The profiler, wrapped   $2  Base   $3  Head
FUN
__profile__tables__table() {
  @unwrap __profile__tables__table__name "$1"
  tui__rule 4
  tui__row "$__profile__tables__table__name" measure base head delta
  tui__rule 4
  @get __profile__tables__table__get_2 "$3" "$__profile__tables__table__name"
  @arr __profile__tables__table__arr_3
  @get __profile__tables__table__get_4 "$2" "$__profile__tables__table__name" "$__profile__tables__table__arr_3"
  @foreachi __profile__tables__rows "$__profile__tables__table__get_2" "$__profile__tables__table__get_4"
  tui__rule 4
}

: <<'FUN'
@foreachi callback: one table row per measure of the head row <row> at
<index>, against the base row at the same index when there is one.

  $1  Head row   $2  Index   $3  Base rows
FUN
__profile__tables__rows() {
  @keys __profile__tables__rows__keys_5 "$1"
  @foreach __profile__tables__row "$__profile__tables__rows__keys_5" "$1" "$2" "$3"
}

: <<'FUN'
@foreach callback: one table row for the wrapped <measure> of the head row.

  $1  The measure, wrapped   $2  Head row   $3  Index   $4  Base rows
FUN
__profile__tables__row() {
  @unwrap __profile__tables__row__measure "$1"
  if @is_false "$(profile__is_measure "$__profile__tables__row__measure")"; then
    return 0
  fi
  @get __profile__tables__row__base "$4" ".[$3].\"$__profile__tables__row__measure\"" ''
  @get __profile__tables__row__head "$2" "$__profile__tables__row__measure"
  @get __profile__tables__row__get_6 "$2" '.command'
  tui__row \
    "ops $__profile__tables__row__get_6" \
    "$__profile__tables__row__measure" \
    "${__profile__tables__row__base:--}" \
    "$__profile__tables__row__head" \
    "$(profile__delta "$__profile__tables__row__base" "$__profile__tables__row__head")"
}
