#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/doc-spacing/api.sh"

:<<'DOC'
The doc-spacing check: one lint check plugin. See shell/lint/registry.sh
for what the roles mean.
DOC
@check.doc-spacing() {
  @summary() {
    println "A doc block or a typed comment sits below a blank line, so the eye finds where the entry above it ends."
  }

  @languages() {
    @arr __at_out shell
    println "$__at_out"
  }

  @scopes() {
    @arr __at_out code
    println "$__at_out"
  }

  @hint() {
    printf '%s\n' \
      "Put a blank line above the doc block or the # CONST:/# VAR: line. The" \
      "first line of the file and a doc below a directive need none. Mark a" \
      "case this rule did not foresee with '# doc-spacing-check: allow' and" \
      "say why."
  }

  @run() {
    lint__checks__shell__doc_spacing__run "$@"
  }
}
