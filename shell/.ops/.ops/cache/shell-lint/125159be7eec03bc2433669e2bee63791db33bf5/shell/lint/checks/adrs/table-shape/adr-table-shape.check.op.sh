#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/table-shape/api.sh"

:<<'DOC'
The adr-table-shape check: one lint check plugin. See
shell/lint/registry.sh for what the roles mean, and shell/lint/checks/adrs/_tables.sh
for what a one-page ADR's table file is.
DOC
@check.adr-table-shape() {
  @summary() {
    println "A one-page ADR's table file opens on an H1, the table's title, then a summary of a quarter to half of the page, then a Glossary section, then one table."
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
      "Give the file the table's title as its H1, say above the table why it matters within" \
      "a quarter to half of the page, and under a \"## Glossary\" heading say what each column" \
      "means and what one row is; the table comes last, and it is the only one."
  }

  @run() {
    lint__checks__adrs__table_shape__run "$@"
  }
}
