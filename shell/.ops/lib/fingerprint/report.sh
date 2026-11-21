#!/bin/sh
# shellcheck disable=SC2119  # bare @arr/@obj are the structs empty constructors

import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/fingerprint/_line.sh"
import "$SHELLOPS_DIR/lib/fingerprint/_emit.sh"

:<<'FRAGMENT'
Folding the pending declarations into a report: one line per name, each name
once per process, carrying the marker of whichever chain resolved to it.
FRAGMENT

: <<'CONST'
The chains awaiting a report. Materialized on first use so a process that
never reports pays nothing, and kept across a re-import, since a second module
asking for this one re-sources it.
CONST
__fingerprint__PENDING="${__fingerprint__PENDING:-}"

# CONST: The names this process has already reported, kept the same way.
__fingerprint__REPORTED="${__fingerprint__REPORTED:-}"

:<<'PUB_FUN'
Prints the fingerprint of every secret declared and not yet reported, one line
per variable name, and appends the same lines to FINGERPRINT_OUT.

Usage: fingerprint__report
PUB_FUN
fingerprint__report() {
  __fingerprint__report__chains="$(__fingerprint__pending)"
  __fingerprint__PENDING=""

  __fingerprint__report__empty="$(__fingerprint__empty_report)"
  __fingerprint__report__marked="$(__fingerprint__marked "$__fingerprint__report__chains")"
  @reduce __fingerprint__report__report __fingerprint__fold_chain \
    "$__fingerprint__report__chains" \
    "$__fingerprint__report__empty" \
    "$__fingerprint__report__marked"

  @let "$__fingerprint__report__report" __fingerprint__report__ reported lines
  __fingerprint__REPORTED="$__fingerprint__report__reported"
  __fingerprint__emit "$__fingerprint__report__lines"
  __fingerprint__report__status=$?
  @unlet __fingerprint__report__ reported lines
  return "$__fingerprint__report__status"
}

:<<'PUB_FUN'
Prints how a declaration is reported in this process: "deferred" when a caller
reports declarations itself, "live" when each one reports as it is made, and
"off" when nothing will read them.
PUB_FUN
fingerprint__mode() {
  if @is_true "${FINGERPRINT_DEFER:-false}"; then
    printf 'deferred\n'
    return 0
  fi

  if @defined "${FINGERPRINT_OUT:-}"; then
    printf 'live\n'
    return 0
  fi

  printf 'off\n'
}

:<<'FUN'
The declared chains, an empty list until one is declared.
FUN
__fingerprint__pending() {
  if @defined "$__fingerprint__PENDING"; then
    println "$__fingerprint__PENDING"
    return 0
  fi

  @arr __fingerprint__pending__out
  println "$__fingerprint__pending__out"
}

:<<'FUN'
The names already reported, an empty set until one is.
FUN
__fingerprint__reported() {
  if @defined "$__fingerprint__REPORTED"; then
    println "$__fingerprint__REPORTED"
    return 0
  fi

  @obj __fingerprint__reported__out
  println "$__fingerprint__reported__out"
}

:<<'FUN'
A report holding no lines yet, carrying the names this process has already
reported so that a second report does not repeat them.
FUN
__fingerprint__empty_report() {
  __fingerprint__empty_report__reported="$(__fingerprint__reported)"

  @arr __fingerprint__empty_report__arr_1
  @obj __fingerprint__empty_report__out \
    '.lines' "$__fingerprint__empty_report__arr_1" \
    '.reported' "$__fingerprint__empty_report__reported"
  println "$__fingerprint__empty_report__out"
}

:<<'FUN'
The names the chains of <chains> resolved to, as a set.

Resolving a marker is a fact about a chain, but a line belongs to a name, so a
name two declarations reach can only carry one. Gathering the markers before any
line is composed is what keeps that line the same whichever declaration reached
the name first: the forge baseline declares its tokens bare, ahead of every
reader that falls back through one of them, so a marker settled per chain would
be lost to the order modules happen to be sourced in.
FUN
__fingerprint__marked() {
  @obj __fingerprint__marked__obj_2
  @reduce __fingerprint__marked__out __fingerprint__fold_marked "$1" "$__fingerprint__marked__obj_2"
  println "$__fingerprint__marked__out"
}

:<<'FUN'
@reduce callback: adds the name <chain> resolved to into <marked>.

  $1 the marked names so far
  $2 the chain, a struct array of variable names
FUN
__fingerprint__fold_marked() {
  @let "$2" __fingerprint__fold_marked__ names winner

  if @is_false "$(__fingerprint__chain_falls_back "$__fingerprint__fold_marked__names")"; then
    println "$1"
    return 0
  fi

  if ! @defined "$__fingerprint__fold_marked__winner"; then
    println "$1"
    return 0
  fi

  @set __fingerprint__fold_marked__out "$1" ".\"$__fingerprint__fold_marked__winner\"" true
  println "$__fingerprint__fold_marked__out"
  __fingerprint__fold_marked__status=$?
  @unlet __fingerprint__fold_marked__ names winner
  return "$__fingerprint__fold_marked__status"
}

:<<'FUN'
@reduce callback: folds a line per name in one declaration into <report>, in the
order its reader falls back through them.

  $1 the report so far
  $2 the declaration
  $3 the names some chain resolved to
FUN
__fingerprint__fold_chain() {
  @let "$2" __fingerprint__fold_chain__ names seen
  @reduce __fingerprint__fold_chain__out __fingerprint__fold_name "$__fingerprint__fold_chain__names" "$1" \
    "$3" \
    "$__fingerprint__fold_chain__seen"
  println "$__fingerprint__fold_chain__out"
  __fingerprint__fold_chain__status=$?
  @unlet __fingerprint__fold_chain__ names seen
  return "$__fingerprint__fold_chain__status"
}

:<<'FUN'
@reduce callback: folds the line for one name into <report>, unless the report
already carries that name.

  $1 the report so far
  $2 the variable name (wrapped)
  $3 the names some chain resolved to
  $4 the states taken when the name was declared
FUN
__fingerprint__fold_name() {
  @unwrap __fingerprint__fold_name__name "$2"
  __fingerprint__fold_name__marker="$(__fingerprint__marker \
    "$3" \
    "$__fingerprint__fold_name__name"
  )"

  if @is_true "$(__fingerprint__name_says "$1" \
    "$__fingerprint__fold_name__name" \
    "$__fingerprint__fold_name__marker"
  )"; then
    println "$1"
    return 0
  fi

  @get __fingerprint__fold_name__get_3 "$4" ".\"$__fingerprint__fold_name__name\""
  __fingerprint__fold_name__line="$(__fingerprint__compose \
    "$__fingerprint__fold_name__name" \
    "$__fingerprint__fold_name__get_3" \
    "$__fingerprint__fold_name__marker"
  )"

  __fingerprint__record \
    "$1" \
    "$__fingerprint__fold_name__name" \
    "$__fingerprint__fold_name__line" \
    "$__fingerprint__fold_name__marker"
}

:<<'FUN'
Prints <report> with <line> appended and <name> reported as saying <marker>.
FUN
__fingerprint__record() {
  @push __fingerprint__record__grown "$1" '.lines' "$3"
  __fingerprint__record__said="$(__fingerprint__said "$4")"

  @set __fingerprint__record__out "$__fingerprint__record__grown" \
    ".reported.\"$2\"" \
    "$__fingerprint__record__said"
  println "$__fingerprint__record__out"
}

:<<'FUN'
Prints what a line carrying <marker> says of its name, "none" standing for a
line carrying no marker. The reported names hold this rather than a bare true so
that a chain can tell whether its marker is news to a name already reported.
FUN
__fingerprint__said() {
  if ! @defined "$1"; then
    printf 'none\n'
    return 0
  fi

  println "$1"
}

:<<'FUN'
Prints whether <report> already carries a line for <name> saying what a line
marked <marker> would say.

A name reported bare by an earlier report is not settled: reporting is per
declaration when a job collects as it goes, so the chain resolving to that name
may only be declared by a module sourced later. Its marker is news then, and
earns the name a second line, since the first one is already in the job log.
FUN
__fingerprint__name_says() {
  @get __fingerprint__name_says__said "$1" ".reported.\"$2\""

  if ! @defined "$__fingerprint__name_says__said"; then
    @false __fingerprint__name_says__out
    println "$__fingerprint__name_says__out"
    return 0
  fi

  if ! @defined "$3"; then
    @true __fingerprint__name_says__out
    println "$__fingerprint__name_says__out"
    return 0
  fi

  @succeeds __fingerprint__name_says__out [ "$__fingerprint__name_says__said" = "$3" ]
  println "$__fingerprint__name_says__out"
}

:<<'FUN'
Prints whether <chain> names a variable to fall back to.
FUN
__fingerprint__chain_falls_back() {
  @len __fingerprint__chain_falls_back__len_4 "$1"
  @succeeds __fingerprint__chain_falls_back__out [ "$__fingerprint__chain_falls_back__len_4" -gt 1 ]
  println "$__fingerprint__chain_falls_back__out"
}

:<<'FUN'
Prints the marker <name> carries given the names <marked> holds: "used" for a
name some chain resolved to, nothing otherwise. A chain of one has nothing to
resolve, so a name no chain reaches says nothing about it.
FUN
__fingerprint__marker() {
  if @is_false "$(__fingerprint__name_marked "$1" "$2")"; then
    return 0
  fi

  printf 'used\n'
}

:<<'FUN'
Prints whether some chain resolved to <name>, given the names <marked> holds.
FUN
__fingerprint__name_marked() {
  @get __fingerprint__name_marked__get_5 "$1" ".\"$2\""
  @succeeds __fingerprint__name_marked__out @defined "$__fingerprint__name_marked__get_5"
  println "$__fingerprint__name_marked__out"
}
