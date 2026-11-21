#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/checks/adrs/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/checks/adrs/form.sh" \
  "$SHELLOPS_DIR/lib/markdown/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The adr-table-shape check: the shape of a table file beside a one-page
decision record, for a repository that names the form
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

The record's references to its tables are the adr-table-reference check. In
a repository that names no form, this check passes every file.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__adrs__table_shape__DIR="$SHELL_LINT_DIR/shell/lint/checks/adrs/table-shape"

: <<'PUB_FUN'
Prints a finding for each part of the table shape a table file among
<files...> is missing: the H1, the summary within its budget, the glossary,
the one table after it. A file that is not a table file is passed over.

  lint__checks__adrs__table_shape__run "$opts" adrs/000007-fragments/tables/kinds.md
    ->  adrs/000007-fragments/tables/kinds.md:1: the summary is followed by a "## Glossary" section

Returns 0 when every table file has the shape, 1 otherwise.

Usage: lint__checks__adrs__table_shape__run <opts> <files...>
PUB_FUN
lint__checks__adrs__table_shape__run() {
  @is_true "$(lint__checks__adrs__form__is_named "$1")" || return 0
  @obj __lint__checks__adrs__table_shape__run__obj_1
  @get __lint__checks__adrs__table_shape__run__config "$1" '.config' "$__lint__checks__adrs__table_shape__run__obj_1"
  __lint__checks__adrs__table_shape__run__folder="$(lint__checks__adrs__folder "$1")"
  __lint__checks__adrs__table_shape__run__words="$(
    lint__config__decisions_page_words "$__lint__checks__adrs__table_shape__run__config"
  )"
  shift

  __lint__checks__adrs__table_shape__run__tables="$(
    println "$@" | markdown__tables_among "$__lint__checks__adrs__table_shape__run__folder"
  )"
  @defined "$__lint__checks__adrs__table_shape__run__tables" || return 0

  args__call_with_lines \
    lint__checks__adrs__awk \
    "$__lint__checks__adrs__table_shape__run__tables" \
    "$__lint__checks__adrs__table_shape__DIR/adr_table_shape.awk" \
    -v page_words="$__lint__checks__adrs__table_shape__run__words" \
    >&2
}
