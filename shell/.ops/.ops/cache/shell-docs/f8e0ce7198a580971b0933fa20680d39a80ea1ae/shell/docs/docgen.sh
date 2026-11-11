#!/bin/sh

import "$SHELLOPS_DIR/lib/kinds/api.sh"

: <<'MODULE'
The docgen kind: how a library's reference is written for one docs system.
The tree of a module (api.sh) is the same whatever the system; a system
decides what a page and an index look like and where each goes, and that
is a plugin of kind docgen (lib/kinds/api.sh of shellops says how a kind
loads), a file named <name>.docgen.op.sh defining @docgen.<name>() with these
roles:

  @summary                 What the system renders for, in one line.
  @needs                   The programs the system runs, as a struct array.
  @page <tree>             Prints the page of the module whose tree is in
                           the file <tree>.
  @index <trees...>        Prints the index over the modules whose trees
                           are in the files <trees...>, one entry each, in
                           the order given.
  @page_path <module>      Prints the path, relative to the reference's
                           root, the module <module> renders to.
  @index_path              Prints the path, relative to the reference's
                           root, the index is written to.

docusaurus is the first system, in docusaurus.docgen.op.sh beside this
file. A host adopts another docs system by adding a plugin, and changes
nothing else: docs__write and cli/docs take the system's name.
MODULE

# CONST: The roles the kind knows.
__docs__docgen__ROLES="summary needs page index page_path index_path"

# CONST: The roles a system must answer.
__docs__docgen__REQUIRED="summary page index page_path index_path"

: <<'PUB_FUN'
Loads and registers the docs system <name>, whose plugin file has been
sourced. See kinds__load.
PUB_FUN
docs__docgen__load() {
  kinds__load docgen "$1" "$__docs__docgen__ROLES" "$__docs__docgen__REQUIRED"
}

: <<'PUB_FUN'
Sources and loads every docs system under <root>, each a file
<name>.docgen.op.sh, in byte order of their paths. Fails when one does not
load.
PUB_FUN
docs__docgen__load_all() {
  __docs__docgen__load_all__files="$(find "$1" -type f -name '*.docgen.op.sh' | LC_ALL=C sort)"
  while IFS= read -r __docs__docgen__load_all__file; do
    [ -n "$__docs__docgen__load_all__file" ] || continue
    __docs__docgen__load_file "$__docs__docgen__load_all__file" || return 1
  done <<EOF_FILES
$__docs__docgen__load_all__files
EOF_FILES
}

: <<'FUN'
Sources the plugin file <file> and loads the system it defines, named by
the file.
FUN
__docs__docgen__load_file() {
  __docs__docgen__load_file__name="$(basename "$1" .docgen.op.sh)"
  . "$1"
  docs__docgen__load "$__docs__docgen__load_file__name"
}

: <<'PUB_FUN'
Prints the names of every loaded docs system, as a struct array, in load
order.
PUB_FUN
docs__docgen__names() {
  kinds__names docgen
}

: <<'PUB_FUN'
Prints the system <name>'s @summary.
PUB_FUN
docs__docgen__summary() {
  kinds__call docgen "$1" summary
}

: <<'PUB_FUN'
Prints the page the system <name> renders for the module whose tree is in
the file <tree>.

Usage: docs__docgen__page <name> <tree>
PUB_FUN
docs__docgen__page() {
  kinds__call docgen "$1" page "$2"
}

: <<'PUB_FUN'
Prints the index the system <name> renders over the modules whose trees
are in the files <trees...>, in the order given.

Usage: docs__docgen__index <name> <trees...>
PUB_FUN
docs__docgen__index() {
  __docs__docgen__index__name="$1"
  shift
  kinds__call docgen "$__docs__docgen__index__name" index "$@"
}

: <<'PUB_FUN'
Prints the path, relative to the reference's root, the system <name>
writes the module <module>'s page to.

  docs__docgen__page_path docusaurus shell/silt/get.sh  ->  shell/silt/get.md
PUB_FUN
docs__docgen__page_path() {
  kinds__call docgen "$1" page_path "$2"
}

: <<'PUB_FUN'
Prints the path, relative to the reference's root, the system <name>
writes the index to.

  docs__docgen__index_path docusaurus  ->  README.md
PUB_FUN
docs__docgen__index_path() {
  kinds__call docgen "$1" index_path
}
