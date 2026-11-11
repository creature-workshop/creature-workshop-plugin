#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/checks/adrs/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/checks/adrs/form.sh" \
  "$SHELLOPS_DIR/lib/markdown/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The adr-table-reference check: the references a one-page decision record
keeps to the table files beside it, for a repository that names the form
(shell/lint/checks/adrs/form.sh).

A table is a figure: a file of its own beside the record's adr.md, at
<folder>/<number>-<slug>/tables/<name>.md, and never a record. Its first line
is an H1, the table's title. A summary follows, saying why the table matters,
within a quarter to half of the page the record itself has. A "## Glossary"
section follows the summary, saying what each column means and what one row
is, and one Markdown table follows the glossary. The record beside the file
references every table file it holds as a link whose text is "Table <k>: "
and the table's title and whose target is tables/<name>.md, and keeps no
table of its own in a fenced block.

The shape of a table file is the adr-table-shape check. In a repository that
names no form, this check passes every file.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__adrs__table_reference__DIR="$SHELL_LINT_DIR/shell/lint/checks/adrs/table-reference"

: <<'PUB_FUN'
Prints a finding for each table file beside a record among <files...> that
the record does not reference as [Table <k>: <the table's title>](tables/<name>.md),
for each such link to no table file or with another text, and for each table
the record keeps in a fenced block. A table file among <files...> brings the
record beside it under check. A file that is neither is passed over.

  lint__checks__adrs__table_reference__run "$opts" adrs/000007-fragments/adr.md
    ->  adrs/000007-fragments/adr.md:1: the record references its table: [Table <k>: The kinds of change](tables/kinds.md)

Returns 0 when every record references its tables, 1 otherwise.

Usage: lint__checks__adrs__table_reference__run <opts> <files...>
PUB_FUN
lint__checks__adrs__table_reference__run() {
  @is_true "$(lint__checks__adrs__form__is_named "$1")" || return 0
  __lint__checks__adrs__table_reference__run__folder="$(lint__checks__adrs__folder "$1")"
  shift

  __lint__checks__adrs__table_reference__run__records="$(
    println "$@" \
      | __lint__checks__adrs__table_reference__records_of "$__lint__checks__adrs__table_reference__run__folder"
  )"
  args__call_with_lines \
    __lint__checks__adrs__table_reference__run_each \
    "$__lint__checks__adrs__table_reference__run__records"
}

: <<'FUN'
Reads paths on stdin and prints, once each and sorted, the record each path
under <folder> belongs to: a record named adr.md is its own, and a table file
belongs to the adr.md beside its tables directory. Other paths print nothing.
One awk, record_of.awk, answers for the whole list.
FUN
__lint__checks__adrs__table_reference__records_of() {
  lint__checks__adrs__awk "$__lint__checks__adrs__table_reference__DIR/record_of.awk" \
    -v folder="$1" \
    | LC_ALL=C sort -u
}

: <<'FUN'
Checks the references of each record among <records...>. Returns 1 when any
record has a finding.
FUN
__lint__checks__adrs__table_reference__run_each() {
  __lint__checks__adrs__table_reference__run_each__status=0
  for __lint__checks__adrs__table_reference__run_each__record in "$@"; do
    __lint__checks__adrs__table_reference__run_one "$__lint__checks__adrs__table_reference__run_each__record" \
      || __lint__checks__adrs__table_reference__run_each__status=1
  done

  return "$__lint__checks__adrs__table_reference__run_each__status"
}

: <<'FUN'
Runs the detector over the table files beside <record>, then
<record> itself when the file exists, and sends what it prints to stderr.
With nothing to read, prints nothing and returns 0.
FUN
__lint__checks__adrs__table_reference__run_one() {
  __lint__checks__adrs__table_reference__run_one__files="$(__lint__checks__adrs__table_reference__files_beside "$1")"
  if [ -f "$1" ]; then
    __lint__checks__adrs__table_reference__run_one__files="$(
      printf '%s\n%s\n' "$__lint__checks__adrs__table_reference__run_one__files" "$1"
    )"
  fi
  @defined "$__lint__checks__adrs__table_reference__run_one__files" || return 0

  args__call_with_lines \
    lint__checks__adrs__awk \
    "$__lint__checks__adrs__table_reference__run_one__files" \
    "$__lint__checks__adrs__table_reference__DIR/adr_table_reference.awk" \
    -v record="$1" \
    >&2
}

: <<'FUN'
Prints the table files beside <record>, sorted, one per line; nothing when
the record has no tables directory.
FUN
__lint__checks__adrs__table_reference__files_beside() {
  find "${1%/adr.md}/tables" -name '*.md' 2>/dev/null | LC_ALL=C sort
}
