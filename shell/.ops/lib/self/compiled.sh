#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/compile/sources.sh" \
  "$SHELLOPS_DIR/lib/git/index.sh"

: <<'MODULE'
An owner's compiled tree, .ops/__compiled__/, derived from its sources and
never tracked (ADR 000047): a link to the entry under .ops/cache/compiled/
named by the source key, a checksum over the index entries of what the
compile reads. .envrc asks this module on every shell, quietly. An owner
whose tree stands at its key costs the key and nothing more; one whose key
changed takes the entry the cache holds for it, or compiles one there,
about three seconds, and links it, pruning the entries of other keys. An
owner in no repository compiles once, unkeyed, and keeps that tree until
ops compile writes another; one whose index holds nothing to compile gets
no tree, and one in a repository git cannot read keeps what stands. The
module speaks in paths and plain shell alone, and loads the compile's plain
fragments only when it has to compile, so the structs library, whose
scalars are in the tree, loads after it.

  self__compiled__ensure
  self__compiled__entry "$PROJ" 892558680  ->  $PROJ/.ops/cache/compiled/892558680
MODULE

# CONST: Where an owner's cache holds its compiled trees, one per key, under the cache of ADR 000011.
__self__compiled__CACHE='.ops/cache/compiled'

# CONST: The entry an owner in no repository compiles into.
__self__compiled__UNKEYED='unkeyed'

: <<'PUB_FUN'
Sets __self__compiled__entry__dir to the cache entry of the owner <dir>
for the key <key>: <dir>/.ops/cache/compiled/<key>, or the unkeyed entry
for an empty key. Sets a variable rather than printing, so asking forks
nothing.

Usage: self__compiled__entry <owner> <key>
PUB_FUN
self__compiled__entry() {
  __self__compiled__entry__dir="$1/$__self__compiled__CACHE/${2:-$__self__compiled__UNKEYED}"
}

: <<'PUB_FUN'
Succeeds when the owner <dir>'s tree stands and is the entry for the key
<key>, or stands at all when the key is empty, so nothing needs laying
down; fails otherwise. A status, not a printed answer, because .envrc asks
on every shell and a printed answer is read through a fork.

Usage: self__compiled__current <owner> <key>
PUB_FUN
# shellcheck disable=SC3013  # -ef is a test every sh in use answers, and the one that costs no fork
self__compiled__current() {
  import__compiled_root "$1"
  __self__compiled__current__tree="$__import__compiled_root__path"  # private-name-check: allow -- import__compiled_root answers in this variable so nothing forks
  [ -d "$__self__compiled__current__tree" ] || return 1
  [ -n "$2" ] || return 0  # structs-lint: allow -- plain shell, loaded before structs
  self__compiled__entry "$1" "$2"
  [ "$__self__compiled__current__tree" -ef "$__self__compiled__entry__dir" ]
}

: <<'PUB_FUN'
Lays the compiled trees of shellops and of the project down where each is
missing or stands for another key, and leaves the rest alone. What .envrc
runs before the structs library reads its scalars out of the tree, and so
what every entrypoint runs, cli/install included. Fails, saying so, when
shellops' own tree cannot be laid down: its struct scalars are in it, so no
shell loads without it.

Usage: self__compiled__ensure
PUB_FUN
self__compiled__ensure() {
  if ! self__compiled__ensure_owner "$SHELLOPS_DIR"; then
    error "shellops' compiled tree could not be laid down under $SHELLOPS_DIR/.ops; 'ops compile' says why"
    return 1
  fi
  if [ "$PROJ" != "$SHELLOPS_DIR" ]; then
    self__compiled__ensure_owner "$PROJ" || return 1
  fi
}

: <<'PUB_FUN'
Lays the owner <dir>'s compiled tree down unless it stands for the sources'
key: from the cache entry for the key when one stands, by compiling into
one otherwise. An owner whose index holds nothing to compile is left alone,
and so is one in a repository git cannot read: what stands, stands.

Usage: self__compiled__ensure_owner <owner>
PUB_FUN
self__compiled__ensure_owner() {
  compile__key "$1"
  __self__compiled__ensure_owner__key="$__compile__key__key"  # private-name-check: allow -- compile__key answers in this variable so nothing forks
  __self__compiled__ensure_owner__indexed="$__compile__key__indexed"  # private-name-check: allow -- compile__key answers in this variable so nothing forks
  if [ "$__self__compiled__ensure_owner__indexed" = true ] && [ -z "$__self__compiled__ensure_owner__key" ]; then  # structs-lint: allow -- plain shell, loaded before structs
    return 0
  fi
  if [ "$__self__compiled__ensure_owner__indexed" = false ] && git__index__present "$1"; then
    return 0
  fi
  self__compiled__current "$1" "$__self__compiled__ensure_owner__key" && return 0
  self__compiled__entry "$1" "$__self__compiled__ensure_owner__key"
  if [ ! -d "$__self__compiled__entry__dir" ]; then
    __self__compiled__build "$1" "$__self__compiled__ensure_owner__key" || return 1
    [ -d "$__self__compiled__entry__dir" ] || return 0
  fi
  __self__compiled__link "$1" "$__self__compiled__ensure_owner__key"
}

: <<'PUB_FUN'
Compiles the owner <dir>'s tree afresh for the sources' key, in place of
the entry that stood for it, and links it; with nothing to compile, removes
the owner's tree. What ops compile does. Fails, leaving the standing tree as
it was, when any source does not compile.

Usage: self__compiled__rebuild <owner>
PUB_FUN
self__compiled__rebuild() {
  compile__key "$1"
  __self__compiled__rebuild__key="$__compile__key__key"  # private-name-check: allow -- compile__key answers in this variable so nothing forks
  __self__compiled__fresh "$1" "$__self__compiled__rebuild__key" || return 1
  if [ -z "$__self__compiled__fresh__dir" ]; then  # structs-lint: allow -- plain shell, loaded before structs
    __self__compiled__unlink "$1"
    return 0
  fi
  __self__compiled__replace "$__self__compiled__fresh__dir" "$1" "$__self__compiled__rebuild__key"
  __self__compiled__link "$1" "$__self__compiled__rebuild__key"
}

: <<'FUN'
Compiles the owner <dir>'s sources into a fresh directory beside the cache
entry for the key <key>, and sets __self__compiled__fresh__dir to it; sets
it empty, making nothing, when the owner has no source to compile. Fails,
leaving nothing behind, not even an empty cache, when any source does not
compile.

Usage: __self__compiled__fresh <owner> <key>
FUN
__self__compiled__fresh() {
  import "$SHELLOPS_DIR/lib/compile/lower.sh"
  __self__compiled__fresh__dir=""
  __self__compiled__fresh__sources="$(compile__sources "$1")"
  [ -n "$__self__compiled__fresh__sources" ] || return 0  # structs-lint: allow -- plain shell, loaded before structs
  self__compiled__entry "$1" "$2"
  __self__compiled__fresh__dir="$__self__compiled__entry__dir.$$"
  rm -rf "$__self__compiled__fresh__dir"
  mkdir -p "$__self__compiled__fresh__dir"
  if compile__each_source "$1" "$__self__compiled__fresh__dir" "$__self__compiled__fresh__sources"; then
    return 0
  fi
  rm -rf "$__self__compiled__fresh__dir"
  rmdir "$1/$__self__compiled__CACHE" 2>/dev/null || true
  __self__compiled__fresh__dir=""
  return 1
}

: <<'FUN'
Compiles the owner <dir>'s sources into the cache entry for the key <key>,
unless the entry appeared meanwhile, another shell's, which then stands.
Makes nothing when the owner has no source to compile. Fails, leaving
nothing behind, when any source does not compile.

Usage: __self__compiled__build <owner> <key>
FUN
__self__compiled__build() {
  __self__compiled__fresh "$1" "$2" || return 1
  [ -n "$__self__compiled__fresh__dir" ] || return 0  # structs-lint: allow -- plain shell, loaded before structs
  __self__compiled__publish "$__self__compiled__fresh__dir" "$1" "$2"
}

: <<'FUN'
Puts the fresh tree <fresh> in place as the owner <dir>'s entry for the key
<key>, unless an entry stands there already, another shell's, in which case
<fresh> is dropped. Two shells finishing in the same instant can leave one's
fresh tree inside the other's entry; that stray is removed.

Usage: __self__compiled__publish <fresh> <owner> <key>
FUN
__self__compiled__publish() {
  self__compiled__entry "$2" "$3"
  if [ -d "$__self__compiled__entry__dir" ]; then
    rm -rf "$1"
    return 0
  fi
  mv "$1" "$__self__compiled__entry__dir"
  rm -rf "${__self__compiled__entry__dir:?}/${1##*/}"
}

: <<'FUN'
Puts the fresh tree <fresh> in place as the owner <dir>'s entry for the key
<key>, in place of whatever entry stood there.

Usage: __self__compiled__replace <fresh> <owner> <key>
FUN
__self__compiled__replace() {
  self__compiled__entry "$2" "$3"
  rm -rf "$__self__compiled__entry__dir"
  mv "$1" "$__self__compiled__entry__dir"
}

: <<'FUN'
Links the owner <dir>'s tree to its cache entry for the key <key>, in place
of whatever stood there, and prunes the entries of other keys, so the cache
holds one tree per owner; an entry another shell is still building, named
with its pid, is left to it.

Usage: __self__compiled__link <owner> <key>
FUN
__self__compiled__link() {
  import__compiled_root "$1"
  __self__compiled__link__tree="$__import__compiled_root__path"  # private-name-check: allow -- import__compiled_root answers in this variable so nothing forks
  self__compiled__entry "$1" "$2"
  if [ -d "$__self__compiled__link__tree" ] && [ ! -L "$__self__compiled__link__tree" ]; then
    rm -rf "$__self__compiled__link__tree"
  fi
  ln -sfn "${__self__compiled__CACHE#.ops/}/${2:-$__self__compiled__UNKEYED}" "$__self__compiled__link__tree"
  __self__compiled__prune "$1" "$__self__compiled__entry__dir"
}

: <<'FUN'
Removes every entry of the owner <dir>'s cache but <keep> and the entries
still being built.

Usage: __self__compiled__prune <owner> <keep>
FUN
__self__compiled__prune() {
  for __self__compiled__prune__entry in "$1/$__self__compiled__CACHE"/*; do
    [ -e "$__self__compiled__prune__entry" ] || continue
    case "${__self__compiled__prune__entry##*/}" in
      *.*) continue ;;
    esac
    [ "$__self__compiled__prune__entry" = "$2" ] && continue
    rm -rf "$__self__compiled__prune__entry"
  done
}

: <<'FUN'
Removes the owner <dir>'s tree and every cache entry, for an owner whose
index holds nothing to compile.

Usage: __self__compiled__unlink <owner>
FUN
__self__compiled__unlink() {
  import__compiled_root "$1"
  rm -rf "$__import__compiled_root__path" "$1/$__self__compiled__CACHE"  # private-name-check: allow -- import__compiled_root answers in this variable so nothing forks
}
