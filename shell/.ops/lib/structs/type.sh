#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/structs/roles.sh"

:<<'FRAGMENT'
Types: a struct scalar is a plugin of kind type (lib/kinds/api.sh says how a
kind loads), a file named <name>.type.op.sh declaring @type.<name>() whose
inner functions are its roles:

  @is <value>       Succeeds quietly when <value> spells a struct value of
                    the type, fails quietly otherwise. Required.
  @from <value>     Prints the struct value made from the shell value
                    <value>, or fails quietly when no value of the type can
                    be made from it. Required; a type whose struct spelling
                    is its shell spelling prints the value once @is accepts
                    it.
  @default          Prints the type's zero value, what the constructor
                    answers with no argument. A type without one has no zero
                    value, and the constructor refuses.
  @new <args>...    Prints a struct value of the type built from several
                    parts, or fails quietly. When a type defines it, the
                    constructor hands every call to it and holds the answer
                    to @is; without it, @from takes one value and @default
                    takes none.
  @values           Prints the closed set of the type's values, as a struct
                    array; only a type over a closed set has it.

A role calls a sibling by its @ name and another type's role by its plain
name, int_is. What loads is the lowered form under the owner's
.ops/__compiled__/, the tree .envrc derives from the sources
(lib/kinds/lower.sh says how; ADR 000037 and ADR 000047 say where): the
plain functions <name>_<role>, which @load_types reads for a library
directory and @load_type registers by name. A load binds two names a caller writes: @is_<name>, the is role,
and @<name>, the constructor. With a value the constructor prints what
from makes of it, naming the type when from makes nothing; with none it
prints the default; a type with new answers every call through it. The
four struct scalars, bool, int, number and string, are the plugins under
lib/structs/types, loaded here at import from their lowered copies; @enum
declares a type at run time into the same registry, defining the plain
functions itself. A load is definitions in the calling shell, so importing
structs with every type loaded starts no subprocess, and neither does
constructing or checking a bool, an int or a number.

  @int 12        ->  12
  @is_int 4.5    ->  fails
  @bool          ->  false
  @string a b    ->  "a b"
  @types x         ->  x=["bool","int","number","string"]
FRAGMENT

:<<'PUB_FUN'
Loads the type <name>, whose lowered file has been sourced, and binds
@is_<name> and @<name>. A plugin that still spells its outer @type.<name>()
with the plain functions inside is loaded through it. Loading a type twice
is harmless. Fails, saying which, when the type leaves a required role out.

  . "$PROJ/.ops/__compiled__/lib/seconds.type.sh"
  @load_type seconds
  @seconds 30  ->  30

Usage: @load_type <name>
PUB_FUN
@load_type() {
  if command -v "@type.$1" >/dev/null 2>&1; then
    kinds__load_flat type "$1" "$__structs__roles__REQUIRED" || return 1
  else
    kinds__register type "$1" "$__structs__roles__REQUIRED" || return 1
  fi
  __structs__type_bind "$1"
}

:<<'PUB_FUN'
Prints the names of every loaded type, as a struct array, in load order.
PUB_FUN
@types() {
  __structs__answer_to "$1" '' || return 1
  __structs__types__names="$(kinds__names type)" || return $?
  __structs__answer_to "$1" "$__structs__types__names"
}

:<<'FUN'
Defines @is_<name> as the type's is role and @<name> as its constructor, in
the calling shell. Each reaches the role through kinds__call, which holds the
name to the registry and names a role the type leaves out.
FUN
__structs__type_bind() {
  eval "@is_$1() { kinds__call type $1 is \"\$@\"; }"
  eval "@$1() { __structs__type_construct $1 \"\$@\"; }"
}

:<<'FUN'
The constructor of the type <name>: when the type defines new, prints what
new builds from the arguments, held to is. Otherwise prints the struct value
the type's from makes of <value>, failing naming the type when it makes
nothing, and with no value prints the type's default, failing when it has
none.

Usage: __structs__type_construct <name> [args...]
FUN
__structs__type_construct() {
  __structs__type_construct__name="$1"
  shift

  if command -v "${__structs__type_construct__name}_new" >/dev/null 2>&1; then
    __structs__type_new "$__structs__type_construct__name" "$@"
    return
  fi

  if [ "$#" -eq 0 ]; then
    kinds__call type "$__structs__type_construct__name" default
    return
  fi

  if ! kinds__call type "$__structs__type_construct__name" from "$1"; then
    error "@$__structs__type_construct__name: not of type $__structs__type_construct__name: $1"
    return 1
  fi
}

:<<'FUN'
Prints what the type <name>'s new builds from the arguments after it, once
the type's is accepts it. Fails naming the type when new builds nothing, and
naming what new answered when is refuses it, so a new that strays from its
own type is caught at the constructor.

Usage: __structs__type_new <name> [args...]
FUN
__structs__type_new() {
  __structs__type_new__name="$1"
  shift

  if ! __structs__type_new__value="$(kinds__call type "$__structs__type_new__name" new "$@")"; then
    error "@$__structs__type_new__name: no $__structs__type_new__name from: $*"
    return 1
  fi
  if ! kinds__call type "$__structs__type_new__name" is "$__structs__type_new__value"; then
    error "@$__structs__type_new__name: new answered no $__structs__type_new__name: $__structs__type_new__value"
    return 1
  fi
  println "$__structs__type_new__value"
}

:<<'PUB_FUN'
Loads every type under the library directory <dir>, named as an import names
a module and read from the owner's compiled tree: <owner>/.ops/__compiled__/<dir
relative to the owner>, the owner being whichever of SHELLOPS_DIR and PROJ
the path sits under (ADR 000037). The lowered files there, <name>.type.sh,
load in name order and bind each: a directory of types is discovered, never
listed. The walk is a shell glob, so it starts no subprocess. Fails naming
the path when neither owner holds it, and on the first type that does not
load.

  @load_types "$PROJ/lib/types"

Usage: @load_types <dir>
PUB_FUN
@load_types() {
  __structs__type_compiled_dir "$1" || return 1
  for __structs__load_types__file in "$__structs__type_compiled_dir__dir"/*.type.sh; do
    [ -e "$__structs__load_types__file" ] || continue
    __structs__type_load_file "$__structs__load_types__file" || return 1
  done
}

:<<'FUN'
Sets __structs__type_compiled_dir__dir to the compiled tree's copy of the
library directory <dir>, the way the importer places a module
(import__compiled_path). Fails naming the path when neither owner holds it.
FUN
__structs__type_compiled_dir() {
  import__compiled_path "$1"
  if [ -z "$__import__compiled_path__path" ]; then  # private-name-check: allow -- import__compiled_path answers in this variable so nothing forks
    error "@load_types: $1 is under neither SHELLOPS_DIR nor PROJ"
    return 1
  fi
  __structs__type_compiled_dir__dir="$__import__compiled_path__path"  # private-name-check: allow -- import__compiled_path answers in this variable so nothing forks
}

:<<'FUN'
Sources the lowered type at <file> and loads the type it names: the
filename without its directory and its .type.sh suffix.
FUN
__structs__type_load_file() {
  import "$1" || return 1
  __structs__type_load_file__name="${1##*/}"
  @load_type "${__structs__type_load_file__name%.type.sh}"
}

:<<'DOC'
The struct scalars, discovered under types/ at import through its compiled
copy. number reads its integer part through int when called, so load order
is free.
DOC
@load_types "$SHELLOPS_DIR/lib/structs/types"
