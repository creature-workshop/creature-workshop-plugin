#!/bin/sh

import "$SHELLOPS_DIR/lib/tui/api.sh"

: <<'MODULE'
Counting the forks and program starts one command costs.

Every shellops command is fork-bound: forks and execs account for nearly all
of its wall time, so the number a change is judged by is how many it makes.
forks__trace records a command under strace, the report functions read the
trace back, and forks.profile.op.sh offers both as the forks profiler.
MODULE

__forks__DIR="$SHELLOPS_DIR/lib/forks"

: <<'PUB_FUN'
Runs a command under strace, following every child, and writes the trace to
$1. Only clone, clone3 and execve are recorded. The command's stdout is
dropped and its stderr passes through; forks__trace returns the command's
own status so a failing command is not mistaken for a cheap one.

args:
  $1  The file to write the trace to
  $@  The command and its arguments
PUB_FUN
forks__trace() {
  __forks__trace__out="$1"
  shift
  strace \
    -f \
    -o "$__forks__trace__out" \
    -e trace=clone,clone3,execve \
    -- "$@" \
    >/dev/null
}

: <<'FUN'
Runs one forks awk program over the trace at $2, with the shared line
predicates loaded ahead of it.

args:
  $1  The program name, without the .awk
  $2  The trace file
FUN
__forks__awk() {
  awk \
    -f "$__forks__DIR/lines.awk" \
    -f "$__forks__DIR/$1.awk" \
    "$2"
}

: <<'PUB_FUN'
The fork and program-start totals of the trace at $1, as a struct object.

  forks__totals trace.txt  ->  {"forks":2506,"starts":684}
PUB_FUN
forks__totals() {
  __forks__awk totals "$1"
}

: <<'PUB_FUN'
How many times each program started in the trace at $1 and its share of
every start in percent, as a struct array, most started first.

  forks__by_program trace.txt  ->  [{"program":"jq","starts":478,"share":69.9}, ...]
PUB_FUN
forks__by_program() {
  __forks__awk by_program "$1"
}

: <<'PUB_FUN'
The trace at $1 as a table: each program with its starts and share, then
the totals under a rule. Named apart from the profile roles on purpose: the
forks profiler's @report re-homes to forks_report, and a library function of
that name would be replaced by the role that calls it.

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Program                       Starts       Share
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   jq                               478       69.9%
   grep                             113       16.5%
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Programs started                 684
   Forks                           2506
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PUB_FUN
forks__table() {
  tui__rule 2
  tui__row Program Starts Share
  tui__rule 2
  @foreach __forks__program_row "$(forks__by_program "$1")"
  tui__rule 2
  __forks__total_rows "$(forks__totals "$1")"
  tui__rule 2
}

: <<'FUN'
@foreach callback: one table row for a program's struct.
FUN
__forks__program_row() {
  @let "$1" __forks__program_row__ program starts share
  @arr __forks__program_row__arr_1 \
    "$__forks__program_row__program" \
    "$__forks__program_row__starts" \
    "$(printf '%.1f%%' "$__forks__program_row__share")"
  tui__row "$__forks__program_row__arr_1"
  @unlet __forks__program_row__ program starts share
}

: <<'FUN'
The two total rows for the totals struct.
FUN
__forks__total_rows() {
  @let "$1" __forks__total_rows__ starts forks
  tui__row "Programs started" "$__forks__total_rows__starts"
  tui__row "Forks" "$__forks__total_rows__forks"
  @unlet __forks__total_rows__ starts forks
}
