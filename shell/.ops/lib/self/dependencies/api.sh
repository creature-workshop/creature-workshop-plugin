#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/self/lock/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The dependencies section of the lock, .ops/lock. It records what ops
install derived from the declarations under .ops/config (ADR 000050), in
two maps. dependencies.imports has every run-time tree the resolver
reached, at the commit it chose. dependencies.tools has the tools by
channel, at the version installed; the git channel's trees are among them,
like every channel's tools. ops install writes both maps through this
module. The resolver reads the imports of a dependency's own lock,
through this module, when it walks the graph. The boot also reads both
maps, in awk before the structs library has loaded, so the boot does not
go through this module.
MODULE

# CONST: The section of the lock the resolved graph sits under.
__self__dependencies__SECTION='dependencies'

# CONST: The awk program that prints the imports of a dependencies section, from a lock of either shape.
__self__dependencies__IMPORTS="$SHELLOPS_DIR/lib/self/dependencies/imports.awk"

# CONST: The awk program that places a new imports map on a dependencies section.
__self__dependencies__WITH_IMPORTS="$SHELLOPS_DIR/lib/self/dependencies/with_imports.awk"

# CONST: The awk program that turns a resolver's registry into the tools map.
__self__dependencies__TOOLS="$SHELLOPS_DIR/lib/self/dependencies/tools.awk"

: <<'PUB_FUN'
Prints the run-time trees that the lock of <root> records, the map under
dependencies.imports, or the empty map when the lock records none. The
map has one entry per repository the resolver reached, keyed by the
repository's name. Each entry has commit, the commit the resolver chose.
A direct entry also has repository, the repository it was declared as,
when the declaration named one; a tree reached through another records
none, since it is fetched from beside its parent. When the tree was pinned as a submodule of another
dependency, the entry has via, the name of that dependency, and mount,
the path it is mounted at (ADR 000050). A lock written before the imports
map existed keeps its trees under dependencies.git with a scope on each;
this prints its run-time entries, without the scope.

  self__dependencies__imports /repo
    ->  {"strata":{"commit":"73e6..."},
         "shell-logs":{"commit":"7f3d...","repository":"../shell-logs.git","via":"strata","mount":"shell/.logs"}}

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
self__dependencies__imports() {
  @run_awk __self__dependencies__imports__out "$__self__dependencies__IMPORTS" "$(self__lock__get_section "$__self__dependencies__SECTION" "${1:-}")" || return 1
  println "$__self__dependencies__imports__out"
}

: <<'PUB_FUN'
Replaces the map under dependencies.imports in the lock of <root> with
<imports> and writes the lock. Everything else in the lock is kept,
including dependencies.tools. A lock written before the imports map
existed loses its dependencies.git here, since the imports and the tools
record the same trees. ops install calls this with what the resolver
derived.

args:
  $1  The imports, as a struct: {<name>: {commit, ...}}
  $2  The repository's root; $PROJ when omitted
PUB_FUN
self__dependencies__set_imports() {
  __self__dependencies__set_imports__section="$(self__lock__get_section "$__self__dependencies__SECTION" "${2:-}")"
  @obj __self__dependencies__set_imports__input '.section' "$__self__dependencies__set_imports__section" '.imports' "$1"
  @run_awk __self__dependencies__set_imports__section "$__self__dependencies__WITH_IMPORTS" "$__self__dependencies__set_imports__input" || return 1
  self__lock__set_section "$__self__dependencies__SECTION" "$__self__dependencies__set_imports__section" "${2:-}"
}

: <<'PUB_FUN'
Replaces the map under dependencies.tools in the lock of <root> with
<tools> and writes the lock. Everything else in the lock is kept,
including dependencies.imports. ops install calls this with the map that
self__dependencies__tools_of_registry made from the resolver's registry.

args:
  $1  The tools by channel, as a struct: {<channel>: {<tool>: {version, ...}}}
  $2  The repository's root; $PROJ when omitted
PUB_FUN
self__dependencies__set_tools() {
  __self__dependencies__set_tools__section="$(self__lock__get_section "$__self__dependencies__SECTION" "${2:-}")"
  @set __self__dependencies__set_tools__section "$__self__dependencies__set_tools__section" '.tools' "$1"
  self__lock__set_section "$__self__dependencies__SECTION" "$__self__dependencies__set_tools__section" "${2:-}"
}

: <<'PUB_FUN'
Converts a resolver's registry into the tools map the lock keeps under
dependencies.tools. The registry has one entry per tool, and each entry
names its channel. The result groups the entries by channel: the channel
is the outer key and the tool's name is the inner key. Each entry keeps
its version and the other facts about the tool. It loses the channel
field, the directory the declaration was read from, and the paths of its
installer and uninstaller scripts, because those describe one checkout and
not the tool. The git channel is kept like every other: its entries pin a
commit under version.

  self__dependencies__tools_of_registry \
    '{"jq": {"channel": "system", "version": "1.6", "origin_dir": "/repo"}}'
    ->  {"system": {"jq": {"version": "1.6"}}}

args:
  $1  The resolver's registry: {<tool>: {channel, version, origin_dir, ...}}
PUB_FUN
self__dependencies__tools_of_registry() {
  @run_awk __self__dependencies__tools_of_registry__out "$__self__dependencies__TOOLS" "$1" || return 1
  println "$__self__dependencies__tools_of_registry__out"
}
