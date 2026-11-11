#!/bin/sh
# shellcheck disable=SC2044

: <<'PUB_FUN'
Loading libraries: import sources each file it is given, in order, and fails
on the first one that does not exist.

A library load is definitions, not steps, so a DEBUG trap has nothing to
report about one. Under functrace (set -T, which bats turns on so its trap can
report a stack trace) import lifts the trap for the duration of the load and
puts both back before returning; without functrace it touches nothing.

A library module is named by its path under an owner's lib/, and what is
sourced is its compiled copy under that owner's .ops/__compiled__/ when the
engine has produced one (ADR 000013, ADR 000037, ADR 000047), and the module
itself otherwise: one builtin test per import, no fork. A plugin, *.op.sh, and
a path outside a library are sourced as given.
PUB_FUN
import() {  # public-name-check: allow -- .envrc loads import into every process as the language keyword
  case "$-" in
    *T*) __import__untraced "$@" ;;
    *) __import__each "$@" ;;
  esac
}

: <<'PUB_CONST'
Set once import above is this loader. A module that may be reached without
.envrc reads it before sourcing this file, because a command lookup is also
satisfied by a binary of the same name, such as ImageMagick's.
PUB_CONST
# shellcheck disable=SC2034  # read by lib/structs/api.sh
import__DEFINED=1

# CONST: Where an owner's compiled tree stands, under the folder shellops manages (ADR 000011), derived from its sources (ADR 000047).
__import__COMPILED=".ops/__compiled__"  # private-name-check: allow -- .ops/__compiled__ is the tree's path, no name (ADR 000047)

: <<'PUB_FUN'
Sets __import__compiled_root__path to the compiled tree of the owner <dir>:
<dir>/.ops/__compiled__. Sets a variable rather than printing, so a load
forks nothing.

  import__compiled_root "$SHELLOPS_DIR"  ->  $SHELLOPS_DIR/.ops/__compiled__

Usage: import__compiled_root <owner>
PUB_FUN
import__compiled_root() {
  __import__compiled_root__path="$1/$__import__COMPILED"
}

: <<'PUB_FUN'
Sets __import__compiled_path__path to the compiled copy of the library
module <path>: <owner>/.ops/__compiled__/<path relative to the owner>, the owner
being SHELLOPS_DIR when the path sits under it and PROJ otherwise. Empty
when the path is under neither owner's lib/. Sets a variable rather than
printing, so a load forks nothing.

  import__compiled_path "$SHELLOPS_DIR/lib/git/api.sh"
    ->  $SHELLOPS_DIR/.ops/__compiled__/lib/git/api.sh

Usage: import__compiled_path <path>
PUB_FUN
import__compiled_path() {
  __import__compiled_path__path=""
  case "$1" in
    "$SHELLOPS_DIR"/lib/*)
      import__compiled_root "$SHELLOPS_DIR"
      __import__compiled_path__path="$__import__compiled_root__path/${1#"$SHELLOPS_DIR"/}"
      ;;
    "${PROJ:-/dev/null}"/lib/*)
      import__compiled_root "$PROJ"
      __import__compiled_path__path="$__import__compiled_root__path/${1#"$PROJ"/}"
      ;;
  esac
}

: <<'FUN'
Source each file in "$@" in order, each through what __import__resolve
picks for it; fail on the first that resolves to nothing.
FUN
__import__each() {
  for __import__SCRIPT in "$@"; do
    __import__resolve "$__import__SCRIPT" || return 1
    . "$__import__RESOLVE_FILE"
  done
}

: <<'FUN'
Sets __import__RESOLVE_FILE to the file import sources for <path>: a
library module's compiled copy when one exists and the module itself
otherwise, the file itself for a plugin (*.op.sh) or a path outside a
library. Fails naming the path when what it resolves to does not exist.
FUN
__import__resolve() {
  case "$1" in
    *.op.sh) __import__RESOLVE_FILE="$1" ;;
    *) __import__placed "$1" ;;
  esac
  if [ -f "$__import__RESOLVE_FILE" ]; then
    return 0
  fi
  echo "import: not found: $1" >&2
  return 1
}

: <<'FUN'
Sets __import__RESOLVE_FILE to the compiled copy of the library module
<path> when the owner's tree holds one, and to <path> otherwise.
FUN
__import__placed() {
  import__compiled_path "$1"
  if [ -n "$__import__compiled_path__path" ] && [ -f "$__import__compiled_path__path" ]; then
    __import__RESOLVE_FILE="$__import__compiled_path__path"
  else
    __import__RESOLVE_FILE="$1"
  fi
}

: <<'FUN'
Source each file in "$@" with the DEBUG trap and functrace off, then put both
back and pass the load's exit status through. Only reached with functrace on,
which no POSIX sh has, so the set -T here never runs under one.
FUN
# shellcheck disable=SC3041,SC3045,SC3047
__import__untraced() {
  __import__untraced__trap="$(trap -p DEBUG)"
  __import__untraced__status=0

  trap - DEBUG
  set +T
  __import__each "$@" || __import__untraced__status=$?
  set -T
  eval "$__import__untraced__trap"

  return "$__import__untraced__status"
}

import__glob() {
  __import__glob__dir="$1"
  __import__glob__pattern="$2"

  [ -d "$__import__glob__dir" ] || return 0

  for __import__glob__file in $(find "$__import__glob__dir" -name "$__import__glob__pattern" 2>/dev/null); do
    import "$__import__glob__file" || return $?
  done
}
