#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/profile/api.sh" \
  "$SHELLOPS_DIR/lib/profile/columns.sh" \
  "$SHELLOPS_DIR/lib/profile/_measure.sh"

: <<'MODULE'
The gate over a profile report: the lines that say where the head costs
more than it may. A measure above the base column's by more than the slack,
a measure above its ceiling in the declaration, a ceiling that names a
measure the profiler does not report, and a command that exits non-zero
where the base column's run exited zero.
MODULE

# CONST: The breach lines found so far, a struct array; profile__breaches fills it through its callbacks.
__profile__gate__FOUND=""

: <<'CONST'
How far above the merge base's measurement a head may be, in percent,
before the ratchet counts it. The ratchet is a coarse check: a rise within
this is accepted as the run's own variation, and a larger one is a
regression. The ceilings in the declaration take no slack.
CONST
__profile__gate__SLACK_PERCENT=10

: <<'PUB_FUN'
The lines that say where the head costs more than it may: one per
profiler, command and measure whose head is above the base column's by
more than the slack, one per ceiling the head is above, one per ceiling
naming a measure the profiler does not report, and one per command that
exits non-zero where the base column's run exited zero. A struct array of
strings, empty when the head is within all of them.

  profile__breaches "$base" "$head" "$declaration"
    ->  ["ops lint: 3000 starts, above the merge base's 2657 by more than 10%", ...]

  $1  Base measurements, by profiler (may be empty)   $2  Head measurements
  $3  The profiling declaration
PUB_FUN
profile__breaches() {
  @arr __profile__gate__FOUND
  @keys __profile__breaches__keys_1 "$2"
  @foreach __profile__gate__profiler_breaches "$__profile__breaches__keys_1" "$1" "$2" "$3"
  println "$__profile__gate__FOUND"
}

: <<'FUN'
@foreach callback: adds the breaches of every command measured under the
wrapped <profiler>.

  $1  The profiler, wrapped   $2  Base   $3  Head   $4  The declaration
FUN
__profile__gate__profiler_breaches() {
  @unwrap __profile__gate__profiler_breaches__name "$1"
  @get __profile__gate__profiler_breaches__get_2 "$3" "$__profile__gate__profiler_breaches__name"
  @arr __profile__gate__profiler_breaches__arr_3
  @get __profile__gate__profiler_breaches__get_4 "$2" "$__profile__gate__profiler_breaches__name" "$__profile__gate__profiler_breaches__arr_3"
  @foreachi __profile__gate__command_breaches \
    "$__profile__gate__profiler_breaches__get_2" \
    "$__profile__gate__profiler_breaches__name" \
    "$__profile__gate__profiler_breaches__get_4" \
    "$4"
}

: <<'FUN'
@foreachi callback: adds the breaches of the head measurement <row> at
<index> under <profiler>: each measure against the base row at the same
index and against its ceiling, then each ceiling that names a measure the
row does not report, then its exit status against the base row's.

  $1  Head row   $2  Index   $3  The profiler   $4  Base rows   $5  The declaration
FUN
__profile__gate__command_breaches() {
  @get __profile__gate__command_breaches__command "$1" '.command'
  __profile__gate__command_breaches__ceilings="$(profile__ceilings "$5" "$3" "$__profile__gate__command_breaches__command")"
  @keys __profile__gate__command_breaches__keys_5 "$1"
  @foreach __profile__gate__measure_breaches "$__profile__gate__command_breaches__keys_5" "$1" "$2" "$4" "$__profile__gate__command_breaches__ceilings"
  @keys __profile__gate__command_breaches__keys_6 "$__profile__gate__command_breaches__ceilings"
  @foreach __profile__gate__unreported_ceiling "$__profile__gate__command_breaches__keys_6" "$1" "$3"
  __profile__gate__exit_breach "$1" "$2" "$4"
}

: <<'FUN'
@foreach callback: adds the breach lines of the wrapped <measure> of the
head row <row> at <index>: above the base row's value, and above the
ceiling. The command's name and its exit status are keys of the row and
not measures.

  $1  The measure, wrapped   $2  Head row   $3  Index   $4  Base rows   $5  The ceilings
FUN
__profile__gate__measure_breaches() {
  @unwrap __profile__gate__measure_breaches__measure "$1"
  if @is_false "$(profile__is_measure "$__profile__gate__measure_breaches__measure")"; then
    return 0
  fi
  @get __profile__gate__measure_breaches__command "$2" '.command'
  @get __profile__gate__measure_breaches__head "$2" "$__profile__gate__measure_breaches__measure"
  @get __profile__gate__measure_breaches__base "$4" ".[$3].\"$__profile__gate__measure_breaches__measure\"" ''
  @get __profile__gate__measure_breaches__ceiling "$5" "$__profile__gate__measure_breaches__measure" ''

  if @defined "$__profile__gate__measure_breaches__base" && @is_true "$(__profile__gate__above_slack "$__profile__gate__measure_breaches__head" "$__profile__gate__measure_breaches__base")"; then
    __profile__gate__measure_breaches__above="$(profile__base_count_phrase "$__profile__gate__measure_breaches__base")"
    __profile__gate__add_breach "$(__profile__gate__breach_line "$__profile__gate__measure_breaches__command" "$__profile__gate__measure_breaches__head" "$__profile__gate__measure_breaches__measure" "$__profile__gate__measure_breaches__above by more than $__profile__gate__SLACK_PERCENT%")"
  fi
  if @defined "$__profile__gate__measure_breaches__ceiling" && [ "$__profile__gate__measure_breaches__head" -gt "$__profile__gate__measure_breaches__ceiling" ]; then
    __profile__gate__add_breach "$(__profile__gate__breach_line "$__profile__gate__measure_breaches__command" "$__profile__gate__measure_breaches__head" "$__profile__gate__measure_breaches__measure" "profiling.yaml's $__profile__gate__measure_breaches__ceiling")"
  fi
}

: <<'FUN'
Prints true when <head> is above <base> by more than the slack, false
otherwise. Integer arithmetic: head is over when a hundred of it exceeds a
hundred plus the slack of the base.

  __profile__gate__above_slack 16498 16485  ->  false
  __profile__gate__above_slack 17000 16485  ->  true

  $1  The head's count   $2  The base's count
FUN
__profile__gate__above_slack() {
  @succeeds __profile__gate__above_slack__out [ $(($1 * 100)) -gt $(($2 * (100 + __profile__gate__SLACK_PERCENT))) ]
  println "$__profile__gate__above_slack__out"
}

: <<'FUN'
@foreach callback: adds a breach when the wrapped ceiling <measure> is not
one the head row <row> reports under <profiler>, so a ceiling that guards
nothing is noticed.

  $1  The measure, wrapped   $2  Head row   $3  The profiler
FUN
__profile__gate__unreported_ceiling() {
  @unwrap __profile__gate__unreported_ceiling__measure "$1"
  if @get __profile__gate__unreported_ceiling__get_7 "$2" "$__profile__gate__unreported_ceiling__measure" ''; @defined "$__profile__gate__unreported_ceiling__get_7"; then
    return 0
  fi
  @get __profile__gate__unreported_ceiling__get_8 "$2" '.command'
  __profile__gate__add_breach "ops $__profile__gate__unreported_ceiling__get_8: profiling.yaml names a measure '$__profile__gate__unreported_ceiling__measure' that $3 does not report"
}

: <<'FUN'
Adds a breach when the head row <row> at <index> exits non-zero where the
base row at the same index exited zero: a command that fails runs less
than one that finishes, so its count is no saving. A row without a
status, no base row, and a base that failed too add nothing.

  $1  Head row   $2  Index   $3  Base rows
FUN
__profile__gate__exit_breach() {
  @get __profile__gate__exit_breach__head "$1" '.status' ''
  @get __profile__gate__exit_breach__base "$3" ".[$2].status" ''
  if ! @defined "$__profile__gate__exit_breach__head" || [ "$__profile__gate__exit_breach__head" = 0 ] || [ "$__profile__gate__exit_breach__base" != 0 ]; then
    return 0
  fi
  __profile__gate__exit_breach__how="$(profile__exit_phrase "$__profile__gate__exit_breach__head")"
  @get __profile__gate__exit_breach__get_9 "$1" '.command'
  __profile__gate__add_breach "ops $__profile__gate__exit_breach__get_9: $__profile__gate__exit_breach__how"
}

: <<'FUN'
Adds one breach line to those found so far.
FUN
__profile__gate__add_breach() {
  @push __profile__gate__FOUND "$__profile__gate__FOUND" "$1"
}

: <<'FUN'
One breach line.

  __profile__gate__breach_line lint 2800 starts "the merge base's 2657"
    ->  ops lint: 2800 starts, above the merge base's 2657

  $1  The command   $2  The head's count   $3  The measure   $4  What it is above
FUN
__profile__gate__breach_line() {
  printf 'ops %s: %s %s, above %s\n' "$1" "$2" "$3" "$4"
}
