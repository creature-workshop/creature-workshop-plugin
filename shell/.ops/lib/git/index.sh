#!/bin/sh

: <<'MODULE'
A directory's git index, read in plain shell so a shell can ask before the
structs library loads (ADR 000047): whether the directory sits in a
repository at all, and the files and entries its index holds under a path.

  git__index__present "$PROJ"       ->  succeeds in a checkout
  git__index__files "$PROJ" lib     ->  lib/git/api.sh
                                        ...
  git__index__entries "$PROJ" lib   ->  100644 3f1c... 0	lib/git/api.sh
                                        ...
MODULE

: <<'PUB_FUN'
Succeeds when the directory <dir> sits in a git repository, its own or one
above it, and fails otherwise. A status, not a printed answer, and asked
with the shell's builtins alone, so a shell can ask on every start without
a fork and tell a repository git cannot read from a directory that is none.

Usage: git__index__present <dir>
PUB_FUN
git__index__present() {
  __git__index__present__dir="$1"
  while [ -n "$__git__index__present__dir" ]; do  # structs-lint: allow -- plain shell, loaded before structs
    [ -e "$__git__index__present__dir/.git" ] && return 0
    case "$__git__index__present__dir" in
      */*) __git__index__present__dir="${__git__index__present__dir%/*}" ;;
      *) return 1 ;;
    esac
  done
  return 1
}

: <<'PUB_FUN'
Prints the files the index of the repository at <dir> holds under <path>,
one per line, relative to <dir>, in the index's order. Fails, printing
nothing, where git cannot read the index.

Usage: git__index__files <dir> <path>
PUB_FUN
git__index__files() {
  git -C "$1" ls-files -- "$2" 2>/dev/null
}

: <<'PUB_FUN'
Prints the entries the index of the repository at <dir> holds under <path>,
one per line: the mode, the blob, the stage and the path, as git ls-files -s
spells them. Fails, printing nothing, where git cannot read the index.

Usage: git__index__entries <dir> <path>
PUB_FUN
git__index__entries() {
  git -C "$1" ls-files -s -- "$2" 2>/dev/null
}
