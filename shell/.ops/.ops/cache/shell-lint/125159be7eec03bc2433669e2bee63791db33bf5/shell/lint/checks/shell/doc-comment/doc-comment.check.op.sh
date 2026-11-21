#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/doc-comment/api.sh"

:<<'DOC'
The doc-comment check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.doc-comment() {
  @summary() {
    println "A function's multi-line doc is a heredoc doc block, not a run of # comments."
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
      "Convert the flagged block to a heredoc doc block above the function, opened" \
      "on PUB_FUN or FUN as the function-label check says. If a block genuinely cannot be, mark it" \
      "'# doc-comment-check: allow' and explain why."
  }

  @run() {
    lint__checks__shell__doc_comment__run "$@"
  }
}
