#!/bin/sh

import "$SHELLOPS_DIR/lib/compile/sources.sh"

: <<'FRAGMENT'
A library module's tree: the compiled document help and the reference render
from (ADR 000039), written into the compiled tree as <path>.tree.json. The
tree is produced by lib/compile/tree.awk, the shell-side lowering that stands
in until the engine lowers library modules; the engine takes it over by
shadow, one producer of record at a time. Plain shell over awk, so the tree
can be derived before the structs library loads (ADR 000047). The lowering
reads a source through the scanner in shell-scan's tree and the doc-block
model in shell-lint's, both pinned in the lock and named by the pins
(ADR 000050).

  compile__tree_path lib/git/api.sh  ->  lib/git/api.tree.json
FRAGMENT

: <<'PUB_FUN'
Prints the path, relative to the compiled tree, the tree of the module
<file> is written to: the compiled copy's path with .sh as .tree.json.
PUB_FUN
compile__tree_path() {
  __compile__tree_path__compiled="$(compile__compiled_path "$1")"
  println "${__compile__tree_path__compiled%.sh}.tree.json"
}

: <<'PUB_FUN'
Prints the tree of the module <file>, a path relative to the current
directory: one JSON document, the module node with a node per root function
and per documented root constant or variable, each carrying its doc leaf and
its contract.
PUB_FUN
compile__tree_text() {
  __compile__tree__require_libraries || return 1
  awk \
    -v path="$1" \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/doc_block.awk" \
    -f "$SHELLOPS_DIR/lib/compile/tree.awk" \
    "$1"
}

: <<'FUN'
Fails, saying what is missing, when SHELL_SCAN_DIR or SHELL_LINT_DIR is
unset: the lock the shell booted from names no shell-scan or no shell-lint,
and the tree cannot be lowered without them.
FUN
__compile__tree__require_libraries() {
  if [ -n "${SHELL_SCAN_DIR:-}" ] && [ -n "${SHELL_LINT_DIR:-}" ]; then  # structs-lint: allow -- plain shell, loaded before structs
    return 0
  fi
  error "compile: SHELL_SCAN_DIR and SHELL_LINT_DIR must name the shell-scan and shell-lint trees the lock pins; declare both in the git channel of .ops/config/tools.yaml"
  return 1
}

: <<'PUB_FUN'
Prints true when the source <file> has a tree, false otherwise: a module
does; a type plugin does not, since its roles' docs are the kind's to carry,
and a template for an entrypoint does not, since it is no module.
PUB_FUN
compile__has_tree() {
  case "$1" in
    *.template.sh)
      printf 'false\n'  # structs-lint: allow -- plain shell, loaded before structs
      return 0
      ;;
  esac
  case "$(compile__source_kind "$1")" in
    "$__compile__sources__KIND_MODULE") printf 'true\n' ;;  # structs-lint: allow -- plain shell, loaded before structs
    *) printf 'false\n' ;;  # structs-lint: allow -- plain shell, loaded before structs
  esac
}
