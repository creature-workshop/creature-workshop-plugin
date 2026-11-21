#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/api.sh"

: <<'MODULE'
The doc-comment check: a function's multi-line doc is a heredoc doc block,
not a run of # comments. In the --added-only mode it reads the staged blob
of each file and reports only the blocks the staged diff added.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__doc_comment__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/doc-comment"

: <<'PUB_FUN'
  Flags multi-line `#` comment doc-blocks that document a function -- a run of
  two or more `#` comment lines immediately above a function definition -- which
  the shell house style requires to be heredoc doc blocks, `: <<'PUB_FUN'` or
  `: <<'FUN'` per the function-label check.
  Heredoc bodies are exempt; a `# doc-comment-check: allow` marker on a block,
  or within three lines above it, exempts it.

  <opts> is an options object (see @obj). With `.added_only` true, only blocks
  whose first line was added in the staged diff are flagged -- the pre-commit
  mode that polices new code without blocking on the pre-existing backlog.

  Usage: lint__checks__shell__doc_comment__run <opts> <files...>

  Returns 0 when every file is clean, 1 otherwise (offenders printed to stderr).
PUB_FUN
lint__checks__shell__doc_comment__run() {
  lint__checks__shell__doc_comment__run__opts="$1"
  shift
  @option lint__checks__shell__doc_comment__run__added_only "$lint__checks__shell__doc_comment__run__opts" 'added_only' false

  if @is_true "$lint__checks__shell__doc_comment__run__added_only"; then
    lint__checks__shell__doc_comment__run__hits="$(__lint__checks__shell__doc_comment__scan_each_staged "$@")"
  else
    lint__checks__shell__doc_comment__run__hits="$(lint__call_with_existing __lint__checks__shell__doc_comment__scan_files "$@")"
  fi
  @defined "$lint__checks__shell__doc_comment__run__hits" || return 0

  log "$lint__checks__shell__doc_comment__run__hits"
  return 1
}

: <<'FUN'
Scans whole files, in one awk, for function # doc-blocks.
FUN
__lint__checks__shell__doc_comment__scan_files() {
  awk \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$__lint__checks__shell__doc_comment__DIR/doc_comment_scan.awk" \
    "$@"
}

: <<'FUN'
Prints the staged-diff findings of every file in <files...>, one file's
staged blob per awk since each is read from the index rather than the tree.
FUN
__lint__checks__shell__doc_comment__scan_each_staged() {
  for __lint__checks__shell__doc_comment__scan_each_staged__file in "$@"; do
    __lint__checks__shell__doc_comment__scan_staged "$__lint__checks__shell__doc_comment__scan_each_staged__file"
  done
}

: <<'FUN'
Scans the staged version of <file>, reporting only blocks whose first line was
added in the staged diff -- the --added-only mode.
FUN
__lint__checks__shell__doc_comment__scan_staged() {
  __lint__checks__shell__doc_comment__scan_staged__added="$(git__staged_added_lines "$1")"
  @defined "$__lint__checks__shell__doc_comment__scan_staged__added" || return 0
  __lint__checks__shell__doc_comment__scan_staged__added="$(
    printf '%s' "$__lint__checks__shell__doc_comment__scan_staged__added" \
      | tr '\n' ','
  )"

  __lint__checks__shell__doc_comment__scan_staged__indexed="$(git__index_path "$1")"
  __lint__checks__shell__doc_comment__scan_staged__blob="$(
    __lint__checks__shell__doc_comment__index_blob "$__lint__checks__shell__doc_comment__scan_staged__indexed"
  )"

  __lint__checks__shell__doc_comment__scan_blob \
    "$1" \
    "$__lint__checks__shell__doc_comment__scan_staged__added" \
    "$__lint__checks__shell__doc_comment__scan_staged__blob"
}

: <<'FUN'
Print the staged blob at <path>, where <path> is how the index spells it.
FUN
__lint__checks__shell__doc_comment__index_blob() {
  git -C "$PROJ" show ":$1"
}

: <<'FUN'
Run the detector over a staged blob, reporting only findings on the given
added line numbers. <fname> is the path printed in those findings.

Usage: __lint__checks__shell__doc_comment__scan_blob <fname> <added-csv> <blob>
FUN
__lint__checks__shell__doc_comment__scan_blob() {
  println "$3" \
    | awk \
      -v fname="$1" \
      -v added="$2" \
      -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
      -f "$__lint__checks__shell__doc_comment__DIR/doc_comment_scan.awk" \
      -
}
