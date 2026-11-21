#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/self/config.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
A repository's profiling declaration, .ops/config/profiling.yaml (ADR
000049), read through the config module: the commands it has measured under
each profiler, and the most each may cost on every measure the profiler
reports. One object per profiler, keyed by the profiler's name; under it one
object per command, keyed by the command's cli words; under that one integer
per measure, named as the profiler's @totals names it.

  forks:
    lint:
      forks: 17500
      starts: 2700

The file is shaped by the profilers, not by this module: a new profiler is
a new top-level key, and its measures are whatever its @totals reports. The
schema holds only that shape; which profilers exist and which measures each
reports is asked of the kind.
FRAGMENT

__profile__declaration__SCHEMA="$SHELLOPS_DIR/lib/profile/profiling.schema.json"

: <<'PUB_FUN'
Prints the repository <root>'s profiling declaration as a struct, checked
against profiling.schema.json, every top-level key naming a loaded profiler.
No declaration gives an empty object, so a repository without one measures
nothing. A declaration that does not parse, breaks the schema or names a
profiler the kind does not know fails and says why.

Usage: profile__declaration           # $PROJ's declaration
       profile__declaration <root>    # another repository's
PUB_FUN
profile__declaration() {
  if ! @is_true "$(self__config__present profiling "${1:-}")"; then
    @obj __profile__declaration__out
    println "$__profile__declaration__out"
    return 0
  fi

  __profile__declaration__doc="$(self__config__load profiling "${1:-}")" || return 1
  @validate "$__profile__declaration__doc" "$__profile__declaration__SCHEMA" || return 1
  @keys __profile__declaration__keys_1 "$__profile__declaration__doc"
  @foreach __profile__declaration__require_profiler "$__profile__declaration__keys_1" || return 1
  println "$__profile__declaration__doc"
}

: <<'FUN'
@foreach callback: fails, naming the profilers the kind knows, when the
wrapped <name> is not one of them.
FUN
__profile__declaration__require_profiler() {
  @unwrap __profile__declaration__require_profiler__name "$1"
  if @is_true "$(kinds__registered profile "$__profile__declaration__require_profiler__name")"; then
    return 0
  fi
  @join __profile__declaration__require_profiler__join_2 "$(profile__names)" ', '
  error "profiling.yaml names no profiler '$__profile__declaration__require_profiler__name'; the profilers are: $__profile__declaration__require_profiler__join_2"
  return 1
}

: <<'PUB_FUN'
Prints the names of the profilers the declaration <decl> holds commands
under, as a struct array.

  profile__declared_profilers "$decl"  ->  ["forks"]
PUB_FUN
profile__declared_profilers() {
  @keys __profile__declared_profilers__out "$1"
  println "$__profile__declared_profilers__out"
}

: <<'PUB_FUN'
Prints the commands the declaration <decl> measures under the profiler
<profiler>, as a struct array of their cli words, sorted by name.

  profile__declared_commands "$decl" forks  ->  ["install --check","lint","test plan"]
PUB_FUN
profile__declared_commands() {
  @obj __profile__declared_commands__obj_3
  @get __profile__declared_commands__get_4 "$1" "$2" "$__profile__declared_commands__obj_3"
  @keys __profile__declared_commands__out "$__profile__declared_commands__get_4"
  println "$__profile__declared_commands__out"
}

: <<'PUB_FUN'
Prints every ceiling the declaration <decl> holds the command <command> to
under the profiler <profiler>, as a struct object keyed by measure; empty
when it names none.

  profile__ceilings "$decl" forks lint  ->  {"forks":17500,"starts":2700}
PUB_FUN
profile__ceilings() {
  @obj __profile__ceilings__obj_5
  @get __profile__ceilings__section "$1" "$2" "$__profile__ceilings__obj_5"
  @obj __profile__ceilings__obj_6
  @get __profile__ceilings__out "$__profile__ceilings__section" "$3" "$__profile__ceilings__obj_6"
  println "$__profile__ceilings__out"
}

: <<'PUB_FUN'
Prints the ceiling the declaration <decl> holds the command <command> to on
the measure <measure> under the profiler <profiler>, or nothing when it
names none.

  profile__ceiling "$decl" forks lint starts  ->  2700
PUB_FUN
profile__ceiling() {
  @get __profile__ceiling__out "$(profile__ceilings "$1" "$2" "$3")" "$4" ''
  println "$__profile__ceiling__out"
}
