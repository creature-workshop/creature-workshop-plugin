#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Enforcement for a repository's decision records, the numbered markdown files
under the folder lint.json names, docs/decisions by default. What a record
is, by its path, is lib/markdown's to say (markdown__is_record).

A record's number is how every other file cites it, so a number belongs to one
record. Two branches that each take the next free number both look right until
the second one lands; the check here says so on the branch, by reading the
default branch as well as the working tree.

What the checks on decision records share is here: the folder, the awk
runner with the markdown libraries loaded, and the listing of the numbers
the tree and the default branch hold. shell/lint/checks/adrs/form.sh holds a
record to the one-page form, in a repository that asks for it, and each
check is a module under shell/lint/checks.
MODULE

: <<'PUB_FUN'
Prints the folder <opts>.config keeps the repository's decision records in,
relative to the repository root.

  lint__checks__adrs__folder "$(@obj)"  ->  docs/decisions
PUB_FUN
lint__checks__adrs__folder() {
  @obj __lint__checks__adrs__folder__obj_1
  @get __lint__checks__adrs__folder__get_2 "$1" '.config' "$__lint__checks__adrs__folder__obj_1"
  lint__config__decisions_folder "$__lint__checks__adrs__folder__get_2"
}

: <<'PUB_FUN'
Runs the awk program at the path <program> with the libraries a decisions
detector reads loaded ahead of it: lib/path/paths.awk, and lib/markdown's
lines.awk and records.awk for what a line of markdown is and what a record's
name and number are. The arguments after <program> go to awk as they are.

Usage: lint__checks__adrs__awk "$dir/number_taken.awk" -v folder=docs/decisions
PUB_FUN
lint__checks__adrs__awk() {
  __lint__checks__adrs__awk__program="$1"
  shift

  awk \
    -f "$SHELLOPS_DIR/lib/path/paths.awk" \
    -f "$SHELLOPS_DIR/lib/markdown/lines.awk" \
    -f "$SHELLOPS_DIR/lib/markdown/records.awk" \
    -f "$__lint__checks__adrs__awk__program" \
    "$@"
}

: <<'PUB_FUN'
Prints a "taken" line for every record under the folder <folder> that holds
its number: each one in PROJ's working tree, and each one the default branch
has added since HEAD forked from it.

Usage: lint__checks__adrs__taken_lines <folder>
PUB_FUN
lint__checks__adrs__taken_lines() {
  {
    find "$PROJ/$1" -name '*.md' 2>/dev/null
    GIT_REPO="$PROJ" git__added_upstream \
      "origin/$(GIT_REPO="$PROJ" git__default_branch)" \
      "$1"
  } | LC_ALL=C sort | lint__checks__adrs__tagged taken
}

: <<'PUB_FUN'
Reads paths on stdin and prints each as "<tag><TAB><path>".

Usage: lint__checks__adrs__tagged <tag>
PUB_FUN
lint__checks__adrs__tagged() {
  while IFS= read -r __lint__checks__adrs__tagged__path; do
    printf '%s\t%s\n' "$1" "$__lint__checks__adrs__tagged__path"
  done
}
