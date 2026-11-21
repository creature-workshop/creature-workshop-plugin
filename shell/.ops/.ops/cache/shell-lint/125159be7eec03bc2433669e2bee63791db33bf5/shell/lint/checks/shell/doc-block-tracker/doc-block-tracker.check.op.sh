#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/doc-block-tracker/api.sh"

:<<'DOC'
The doc-block-tracker check: one lint check plugin. See shell/lint/registry.sh
for what the roles mean.
DOC
@check.doc-block-tracker() {
  @summary() {
    println "A doc block carries no TODO or FIXME marker; pending work belongs in the tracker."
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
      "Open an issue for the outstanding work and take the paragraph out of the" \
      "doc."
  }

  @run() {
    lint__checks__shell__doc_block_tracker__run "$@"
  }
}
