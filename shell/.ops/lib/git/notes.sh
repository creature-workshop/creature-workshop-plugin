#!/bin/sh

import "$SHELLOPS_DIR/lib/git/api.sh"

: <<'MODULE'
Git notes as a store keyed by commit: writing one under a ref of its own,
reading it back, listing the commits that carry one, and finding the newest
carrier on a line of history.
MODULE

: <<'PUB_FUN'
Attaches the contents of <file> to <commit> as its note under <ref>,
replacing the note the commit already carries there. Prints nothing.

  git__notes__write refs/notes/testing-trace 9fa43442 map.json

Usage: git__notes__write <ref> <commit> <file>
PUB_FUN
git__notes__write() {
  git -C "$(__git__repo)" notes --ref "$1" add -f -F "$3" "$2" >/dev/null 2>&1
}

: <<'PUB_FUN'
Prints the note <commit> carries under <ref>. Non-zero, printing nothing,
when it carries none or the ref does not exist.

Usage: git__notes__read <ref> <commit>
PUB_FUN
git__notes__read() {
  git -C "$(__git__repo)" notes --ref "$1" show "$2" 2>/dev/null
}

: <<'PUB_FUN'
Prints the commits carrying a note under <ref>, one per line, in no
particular order; nothing when the ref does not exist.

Usage: git__notes__commits <ref>
PUB_FUN
git__notes__commits() {
  git -C "$(__git__repo)" notes --ref "$1" list 2>/dev/null | cut -d' ' -f2
}

: <<'PUB_FUN'
Prints the newest commit reachable from <head> that carries a note under
<ref>, newest by history rather than by clock: the first one a walk from the
head meets. Prints nothing when no commit on that history carries one.

  git__notes__newest refs/notes/testing-trace HEAD  ->  9fa43442...

Usage: git__notes__newest <ref> <head>
PUB_FUN
git__notes__newest() {
  __git__notes__newest__noted="$(mktemp)" || return 1
  git__notes__commits "$1" > "$__git__notes__newest__noted"
  if [ ! -s "$__git__notes__newest__noted" ]; then
    rm -f "$__git__notes__newest__noted"
    return 0
  fi

  git -C "$(__git__repo)" rev-list "$2" 2>/dev/null \
    | awk -f "$SHELLOPS_DIR/lib/git/newest_noted.awk" "$__git__notes__newest__noted" -
  __git__notes__newest__status=$?
  rm -f "$__git__notes__newest__noted"
  return "$__git__notes__newest__status"
}
