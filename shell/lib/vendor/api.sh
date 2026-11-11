#!/bin/sh

: <<'MODULE'
Copies of the project's dependencies that a built artifact carries, so that
the artifact runs where its submodules are not installed and nothing can be
fetched. A copy carries only what runs: no tests, fixtures or documentation.
MODULE

# CONST: The entries at the root of shellops and of each tree it pins that the plugin does not run: the test suites and their fixtures, the documentation and decision records, the plans, shellops' Rust engine, and each repository's own CI configuration.
__vendor__UNUSED_ROOTS="test docs adrs planning engine .gitlab-ci .gitlab-ci.yml .github .forgejo"

: <<'PUB_FUN'
Writes shellops, as the submodule at $SHELLOPS_DIR has it checked out, into
the directory <dest>, complete: its own shell/.logs, every tree its lock pins
and its compiled tree. The copy boots from any directory with no git
repository and no network, because each tree is already where its pins file
names it. shellops must have booted once, so that its cache holds those
trees; sourcing the project's .envrc does that. The copy carries no tests,
fixtures or documentation.

Usage: vendor__shellops <dest>
PUB_FUN
vendor__shellops() {
  rm -rf "$1"
  mkdir -p "$1"
  __vendor__archive "$SHELLOPS_DIR" "$1"
  __vendor__archive "$SHELLOPS_DIR/shell/.logs" "$1/shell/.logs"
  __vendor__copy_cache "$SHELLOPS_DIR/.ops" "$1/.ops"
  __vendor__prune_trees "$1"
  __vendor__boot "$1"
  __vendor__keep_live_compiled "$1/.ops"
}

: <<'FUN'
Writes the files of the commit checked out in the repository <repo> into the
directory <dest>, which git archive fills as the commit records it.

Usage: __vendor__archive <repo> <dest>
FUN
__vendor__archive() {
  mkdir -p "$2"
  git -C "$1" archive --format=tar HEAD | tar -x -C "$2"
}

: <<'FUN'
Copies the pinned trees, the pins file and the compiled tree from shellops'
.ops directory <from> into <to>.

Usage: __vendor__copy_cache <from> <to>
FUN
__vendor__copy_cache() {
  cp -a "$1/cache" "$2/cache"
  cp -a "$1/__compiled__" "$2/__compiled__"
}

: <<'FUN'
Boots the copy of shellops at <root> once, so that the copy carries the
compiled tree the installed plugin reads. shellops keys that tree by the git
index entries of its library modules, and the installed plugin is a git
clone that tracks the copy's files, so the boot runs in a throwaway
repository that tracks the same files, which gives the same key, and the
repository is removed afterwards. The boot runs in an environment that
carries nothing from the project's shell, and fetches nothing, since every
tree is already in the copy's cache.

Usage: __vendor__boot <root>
FUN
__vendor__boot() {
  git -C "$1" init -q
  git -C "$1" add -A -f .
  __vendor__boot__status=0
  (
    cd "$1" &&
      env -i HOME="$HOME" PATH="$PATH" bash -c '. ./.envrc >/dev/null'
  ) || __vendor__boot__status=$?
  rm -rf "${1:?}/.git"
  return "$__vendor__boot__status"
}

: <<'FUN'
Removes every compiled tree under the .ops directory <ops> except the one its
__compiled__ link names.

Usage: __vendor__keep_live_compiled <ops>
FUN
__vendor__keep_live_compiled() {
  __vendor__keep_live_compiled__live="$(readlink "$1/__compiled__")"
  for __vendor__keep_live_compiled__tree in "$1"/cache/compiled/*; do
    if [ "cache/compiled/${__vendor__keep_live_compiled__tree##*/}" != "$__vendor__keep_live_compiled__live" ]; then
      rm -rf "$__vendor__keep_live_compiled__tree"
    fi
  done
}

: <<'FUN'
Removes what the plugin does not run from the copy of shellops at <root> and
from each pinned tree in its cache: the directories __vendor__UNUSED_ROOTS
names at each one's root, and the fixtures beside each library module. The
compiled tree is shellops' own derived output and is left as it is.

Usage: __vendor__prune_trees <root>
FUN
__vendor__prune_trees() {
  for __vendor__prune_trees__tree in "$1" "$1/shell/.logs" "$1"/.ops/cache/*/*/; do
    case "$__vendor__prune_trees__tree" in
      "$1"/.ops/cache/compiled/*) continue ;;
    esac
    __vendor__prune_tree "${__vendor__prune_trees__tree%/}"
  done
}

: <<'FUN'
Removes the entries __vendor__UNUSED_ROOTS names at the root of the tree
<tree>, every fixtures directory under its lib/, and every fixture file
(<module>.fixture.<ext>) in it. The search for fixture files does not enter
the tree's .ops/cache, which holds the other trees and the compiled tree.

Usage: __vendor__prune_tree <tree>
FUN
__vendor__prune_tree() {
  for __vendor__prune_tree__entry in $__vendor__UNUSED_ROOTS; do
    rm -rf "${1:?}/$__vendor__prune_tree__entry"
  done
  if [ -d "$1/lib" ]; then
    find "$1/lib" -type d -name fixtures -prune -exec rm -rf {} +
  fi
  find "$1" -path "$1/.ops/cache" -prune -o -type f -name '*.fixture.*' -exec rm -f {} +
}
