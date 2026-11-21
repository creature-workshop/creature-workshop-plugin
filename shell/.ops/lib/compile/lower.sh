#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/compile/sources.sh" \
  "$SHELLOPS_DIR/lib/compile/tree.sh" \
  "$SHELLOPS_DIR/lib/kinds/lower.sh" \
  "$SHELLOPS_DIR/lib/structs/roles.sh"

: <<'MODULE'
Writing what an owner's sources compile to into a tree: a type plugin lowers
to its plain functions, a module writes its tree, a plugin of another kind
writes nothing. Plain shell over awk, so the tree can be derived before the
structs library loads (ADR 000047). A source is named relative to its
owner, and a compiled path relative to the tree.

  compile__each_source "$PROJ" "$tree" "$(compile__sources "$PROJ")"
MODULE

: <<'PUB_FUN'
Prints the lowered form of the owner <dir>'s type plugin <file>, failing
with the lowering's diagnostics when it does not lower.

Usage: compile__compiled_text <owner> <file>
PUB_FUN
compile__compiled_text() {
  @type_roles __compile__compiled_text__roles
  @type_required __compile__compiled_text__required
  (cd "$1" && kinds__lower type "$(compile__plugin_name "$2")" "$__compile__compiled_text__roles" "$__compile__compiled_text__required" "$2")
}

: <<'PUB_FUN'
Writes what the owner <dir>'s source <file> compiles to under the tree
<tree>: a type plugin lowers, a module writes its tree, a plugin of another
kind writes nothing. Fails when a type plugin does not lower.

Usage: compile__write <owner> <file> <tree>
PUB_FUN
compile__write() {
  case "$(compile__source_kind "$2")" in
    "$__compile__sources__KIND_TYPE") compile__write_type "$1" "$2" "$3" ;;
    "$__compile__sources__KIND_MODULE") __compile__write_module "$1" "$2" "$3" ;;
  esac
}

: <<'FUN'
Writes the tree of the owner <dir>'s module <file> under the tree <tree>
when the module has one, and nothing otherwise.

Usage: __compile__write_module <owner> <file> <tree>
FUN
__compile__write_module() {
  if [ "$(compile__has_tree "$2")" = true ]; then  # structs-lint: allow -- plain shell, loaded before structs
    compile__write_tree "$1" "$2" "$3"
  fi
}

: <<'PUB_FUN'
Writes the lowered form of the owner <dir>'s type plugin <file> under the
tree <tree>. Fails when the plugin does not lower.

Usage: compile__write_type <owner> <file> <tree>
PUB_FUN
compile__write_type() {
  __compile__write_type__out="$3/$(compile__compiled_path "$2")"
  __compile__write_type__text="$(compile__compiled_text "$1" "$2")" || return 1
  mkdir -p "$(dirname "$__compile__write_type__out")"
  println "$__compile__write_type__text" > "$__compile__write_type__out"
}

: <<'PUB_FUN'
Writes the tree of the owner <dir>'s module <file> under the tree <tree>.

Usage: compile__write_tree <owner> <file> <tree>
PUB_FUN
compile__write_tree() {
  __compile__write_tree__out="$3/$(compile__tree_path "$2")"
  mkdir -p "$(dirname "$__compile__write_tree__out")"
  (cd "$1" && compile__tree_text "$2") > "$__compile__write_tree__out"
}

: <<'PUB_FUN'
Compiles each line of <files>, sources of the owner <dir>, under the tree
<tree>; fails when any does not compile, after trying them all.

Usage: compile__each_source <owner> <tree> <files>
PUB_FUN
compile__each_source() {
  __compile__each_source__status=0
  while IFS= read -r __compile__each_source__file; do
    [ -n "$__compile__each_source__file" ] || continue
    compile__write "$1" "$__compile__each_source__file" "$2" || __compile__each_source__status=1
  done <<EOF_FILES
$3
EOF_FILES
  return "$__compile__each_source__status"
}
