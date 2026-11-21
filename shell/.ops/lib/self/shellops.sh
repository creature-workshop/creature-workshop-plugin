#!/bin/sh

import "$SHELLOPS_DIR/lib/git/api.sh"

: <<'MODULE'
The shellops a tree runs on: the copy its .gitmodules vendors, which is
the submodule whose entry points at a repository named shellops, or the
tree itself when it vendors none, since the one tree that runs ops and
vendors no shellops is shellops. A command a tree runs, and its boot, go
through that copy, so a consumer measured at an older commit runs the
shellops that commit pins, and the resolver leaves that copy out of the
dependencies it walks.

  self__shellops__of /p/agents    ->  /p/agents/shell/.ops
  self__shellops__of /p/shellops  ->  /p/shellops
MODULE

# CONST: The name of this library's repository, which a .gitmodules entry points at when it vendors a copy.
__self__shellops__NAME='shellops'

: <<'PUB_FUN'
Prints true when the submodule of the tree <tree> at <path> is a vendored
shellops: its .gitmodules entry points at a repository named shellops, by
any URL. Prints false otherwise, and for a path the tree names no
repository for.

  self__shellops__is_vendored /p/agents shell/.ops   ->  true
  self__shellops__is_vendored /p/strata shell/.logs  ->  false

args:
  $1  The tree
  $2  The submodule's path inside it
PUB_FUN
self__shellops__is_vendored() {
  __self__shellops__is_vendored__url="$(git__submodule_url "$1" "$2")"
  __self__shellops__is_vendored__name="${__self__shellops__is_vendored__url##*/}"
  if [ "${__self__shellops__is_vendored__name%.git}" = "$__self__shellops__NAME" ]; then
    println true
  else
    println false
  fi
}

: <<'PUB_FUN'
Prints where the shellops the tree <tree> runs on stands: the first
submodule its .gitmodules vendors as shellops, or the tree itself when it
vendors none.

args:
  $1  The tree
PUB_FUN
self__shellops__of() {
  __self__shellops__of__vendored="$(__self__shellops__vendored_path "$1")"
  if @defined "$__self__shellops__of__vendored"; then
    println "$1/$__self__shellops__of__vendored"
  else
    println "$1"
  fi
}

: <<'FUN'
Prints the path of the first submodule the tree <tree> vendors as
shellops, or nothing.

args:
  $1  The tree
FUN
__self__shellops__vendored_path() {
  git__submodule_paths "$1" | while IFS= read -r __self__shellops__vendored_path__path; do
    if @is_true "$(self__shellops__is_vendored "$1" "$__self__shellops__vendored_path__path")"; then
      println "$__self__shellops__vendored_path__path"
      break
    fi
  done
}
