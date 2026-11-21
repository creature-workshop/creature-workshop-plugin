#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/compile/sources.sh" \
  "$SHELLOPS_DIR/lib/compile/tree.sh" \
  "$SHELLOPS_DIR/lib/compile/lower.sh" \
  "$SHELLOPS_DIR/lib/self/compiled.sh"

: <<'MODULE'
The compile step: the type plugins git tracks under PROJ/lib, lowered to
their plain functions, and every library module's tree beside them, as
PROJ's compiled tree, .ops/__compiled__/, the one the importer and
@load_types read (ADR 000047). The tree is derived: .envrc keys it by the
sources and lays it down from the cache or by compiling, and ops compile
writes it by hand through this module. A type plugin, <name>.type.op.sh,
lowers to its path with .op.sh as .sh. A module compiles to its tree, the
document help and the reference render from, and is still imported from
its source until the engine compiles it. A plugin of another kind compiles
to nothing: its kind loads it. A source path here is relative to PROJ, and
a compiled path is relative to the tree.

  compile__compiled_path lib/structs/types/int.type.op.sh
    ->  lib/structs/types/int.type.sh
  compile__tree_path lib/git/api.sh
    ->  lib/git/api.tree.json
MODULE

: <<'PUB_FUN'
Prints the compiled tree's lib/, relative to PROJ: .ops/__compiled__/lib,
where the lowered plugins and the trees sit.
PUB_FUN
compile__compiled_lib() {
  println ".ops/__compiled__/lib"  # private-name-check: allow -- .ops/__compiled__ is the tree's path, no name (ADR 000047)
}

: <<'PUB_FUN'
Compiles PROJ's tree afresh from every source its index holds, in place of
whatever tree stood for the sources' key, and links it as PROJ's compiled
tree; with nothing to compile, leaves PROJ with no tree. Fails when any
source does not compile, leaving the standing tree as it was.
PUB_FUN
compile__rebuild() {
  self__compiled__rebuild "$PROJ"
}

: <<'PUB_FUN'
Compiles each line of <files>, sources named relative to PROJ, into PROJ's
compiled tree as it stands, tracked or not, laying the tree down first when
none stands. What is written stands until the sources' key changes. Fails
when any does not compile, after trying them all.

Usage: compile__named <files>
PUB_FUN
compile__named() {
  self__compiled__ensure_owner "$PROJ" || return 1
  import__compiled_root "$PROJ"
  compile__each_source "$PROJ" "$__import__compiled_root__path" "$1"  # private-name-check: allow -- import__compiled_root answers in this variable so nothing forks
}
