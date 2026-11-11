#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/table-reference/api.sh"

:<<'DOC'
The adr-table-reference check: one lint check plugin. See
shell/lint/registry.sh for what the roles mean, and shell/lint/checks/adrs/_tables.sh
for what a one-page ADR's table file is.
DOC
@check.adr-table-reference() {
  @summary() {
    println "A one-page ADR references every table file beside it as [Table <k>: <title>](tables/<name>.md), and keeps no table in a fenced block."
  }

  @languages() {
    @arr __at_out markdown
    println "$__at_out"
  }

  @scopes() {
    @arr __at_out code
    println "$__at_out"
  }

  @hint() {
    printf '%s\n' \
      "Link each table from the record's prose with the text \"Table <k>: \" and the file's H1," \
      "numbered from 1 within the record; a table in a fenced block moves to tables/<name>.md."
  }

  @run() {
    lint__checks__adrs__table_reference__run "$@"
  }
}
