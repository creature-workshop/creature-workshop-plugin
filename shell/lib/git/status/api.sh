#!/usr/bin/env bash

: <<'MODULE'
The state of a git repository, the way a shell prompt shows it: the branch,
how far it is ahead of and behind its upstream, and how many paths are
staged, modified, untracked or in conflict.

The module needs nothing but git, awk and a POSIX shell, because Hermes
installs the plugin without its shellops submodule; it prints its answer
as JSON for that reason, where a shellops module would build a structs
value. It reads PROJ, the plugin's root, to find its awk program.
MODULE

: <<'PUB_FUN'
Prints the state of the repository at a path as one line of JSON, and fails
when git cannot read the repository there.

  git__status__read /home/someone/demo
    ->  {"branch": "main", "detached": false, "upstream": true, "ahead": 1, "behind": 0,
         "staged": 1, "modified": 0, "untracked": 3, "conflicted": 0}

args:
  $1  A folder inside the repository
PUB_FUN
git__status__read() {
  __git__status__read__report="$(git -C "$1" status --porcelain=v2 --branch 2>/dev/null)" || return 1
  printf '%s\n' "$__git__status__read__report" | __git__status__awk
}

: <<'FUN'
Runs status.awk, which turns a porcelain v2 report on stdin into the JSON
that git__status__read prints.
FUN
__git__status__awk() {
  awk -f "$PROJ/shell/lib/git/status/status.awk"
}
