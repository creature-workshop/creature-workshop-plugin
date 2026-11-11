#!/bin/sh

import "$SHELLOPS_DIR/lib/git/index.sh"

: <<'MODULE'
What the compile reads: the sources under an owner's lib/ that compile, what
each is to the compile, the compiled path of each, and the key that names
what they compile to. Plain shell, so the tree can be derived before the
structs library loads (ADR 000047): what a source is to the compile is
three plain constants here, where a module loaded after structs would
declare an @enum.

  compile__sources "$SHELLOPS_DIR"  ->  lib/agents/api.sh
                                        ...
                                        lib/structs/types/string.type.op.sh
  compile__key "$SHELLOPS_DIR"      ->  __compile__key__key=892558680
MODULE

# CONST: What a source is to the compile: a type plugin, which lowers.
__compile__sources__KIND_TYPE=type

# CONST: What a source is to the compile: a plugin of another kind, which its kind loads.
__compile__sources__KIND_PLUGIN=plugin

# CONST: What a source is to the compile: a library module, which writes its tree.
__compile__sources__KIND_MODULE=module

# CONST: The filter over an index or a file listing that keeps the sources the compile reads.
__compile__sources__FILTER="$SHELLOPS_DIR/lib/compile/sources.awk"

: <<'PUB_FUN'
Prints what the source <file> is to the compile: type for a type plugin,
plugin for a plugin of another kind, module for any other library file.

  compile__source_kind lib/structs/types/int.type.op.sh  ->  type
PUB_FUN
compile__source_kind() {
  case "$1" in
    *.type.op.sh) printf '%s\n' "$__compile__sources__KIND_TYPE" ;;
    *.op.sh) printf '%s\n' "$__compile__sources__KIND_PLUGIN" ;;
    *) printf '%s\n' "$__compile__sources__KIND_MODULE" ;;
  esac
}

: <<'PUB_FUN'
Prints every source under the owner <dir>'s lib/ the compile writes a copy
for, one per line, relative to the owner: the modules and the type plugins,
never a plugin of another kind and never a test fixture, which a suite
lowers for itself. Read from the owner's index when it has one, so a source
the index does not hold is not compiled, and from its tree otherwise.

Usage: compile__sources <owner>
PUB_FUN
compile__sources() {
  __compile__sources__listing "$1" | awk -v paths_only=1 -f "$__compile__sources__FILTER"
}

: <<'FUN'
Prints every path under the owner <dir>'s lib/, one per line, relative to
the owner: the index's when the owner sits in a repository, and nothing
there when git cannot read it; the tree's when the owner is no repository.

Usage: __compile__sources__listing <owner>
FUN
__compile__sources__listing() {
  if git__index__present "$1"; then
    git__index__files "$1" lib || true
    return 0
  fi
  (cd "$1" && find lib -type f 2>/dev/null) || true
}

: <<'PUB_FUN'
Sets __compile__key__key to the key of what the owner <dir>'s sources
compile to: a checksum over their index entries, paths and blob ids, so
the key changes when a source is staged, added or removed and not when a
file is edited in place. Sets it empty when the owner has no index, or
when its index holds no source, and __compile__key__indexed to true or
false for which. Sets variables rather than printing, so a shell can ask
without a fork of its own.

  compile__key "$SHELLOPS_DIR"  ->  __compile__key__key=892558680, __compile__key__indexed=true

Usage: compile__key <owner>
PUB_FUN
compile__key() {
  __compile__key__key=""
  __compile__key__indexed=false
  __compile__key__entries="$(git__index__entries "$1" lib)" || return 0
  __compile__key__indexed=true
  # shellcheck disable=SC2046  # cksum's two words are what set splits
  set -- $(println "$__compile__key__entries" | awk -f "$__compile__sources__FILTER" | cksum)
  [ "$2" -gt 0 ] || return 0
  __compile__key__key="$1"
}

: <<'PUB_FUN'
Prints the path, relative to the compiled tree, the type plugin <file>
lowers to: its own path with .op.sh as .sh. A module's path is itself, the
prefix compile__tree_path turns into the tree.
PUB_FUN
compile__compiled_path() {
  case "$1" in
    *.op.sh) printf '%s\n' "${1%.op.sh}.sh" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

: <<'PUB_FUN'
Prints the source the compiled copy <path> was written from: the type
plugin a .type.sh lowers, or the module a .tree.json is the tree of.

  compile__source_of lib/types/seconds.type.sh  ->  lib/types/seconds.type.op.sh
  compile__source_of lib/git/api.tree.json      ->  lib/git/api.sh
PUB_FUN
compile__source_of() {
  case "$1" in
    *.tree.json) printf '%s\n' "${1%.tree.json}.sh" ;;
    *) printf '%s\n' "${1%.sh}.op.sh" ;;
  esac
}

: <<'PUB_FUN'
Prints the plugin name <file> carries: its filename without the directory
and the .type.op.sh suffix.
PUB_FUN
compile__plugin_name() {
  __compile__plugin_name__base="${1##*/}"
  println "${__compile__plugin_name__base%.type.op.sh}"
}
