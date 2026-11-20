#!/usr/bin/env bash

: <<'MODULE'
The state of one file in git: how the copy in the working tree differs from
the commit the checkout is on.

The module needs nothing but git, awk and a POSIX shell, because Hermes
installs the plugin without its shellops submodule. It reads PROJ, the
plugin's root, to find its awk program.
MODULE

: <<'PUB_FUN'
Prints the state in git of one file as one word, and fails when git cannot
read a repository at the folder.

The states are clean, modified, new (the commit has no copy of the file),
deleted and conflict. The word is none when git has nothing to say about
the file: git ignores it, or there is no file and the commit has none.

  git__file_state__read /home/someone/demo /home/someone/demo/.ops/config/manifest.yaml
    ->  modified

args:
  $1  A folder inside the repository
  $2  The file's path
PUB_FUN
git__file_state__read() {
  __git__file_state__read__report="$(git -C "$1" status \
    --porcelain=v2 \
    --no-renames \
    --untracked-files=all \
    --ignored=matching \
    -- \
    "$2" \
    2>/dev/null
  )" || return 1
  __git__file_state__read__exists="$(__git__file_state__exists "$2")"
  printf '%s\n' "$__git__file_state__read__report" | __git__file_state__awk "$__git__file_state__read__exists"
}

: <<'FUN'
Prints true when a file is at the path, false otherwise.

args:
  $1  The file's path
FUN
__git__file_state__exists() {
  if [ -f "$1" ]; then
    printf 'true\n'
  else
    printf 'false\n'
  fi
}

: <<'FUN'
Runs file_state.awk, which turns a porcelain v2 report for one file on
stdin into the word git__file_state__read prints.

args:
  $1  Whether the file is in the working tree: true or false
FUN
__git__file_state__awk() {
  awk -v exists="$1" -f "$PROJ/shell/lib/git/file_state/file_state.awk"
}
