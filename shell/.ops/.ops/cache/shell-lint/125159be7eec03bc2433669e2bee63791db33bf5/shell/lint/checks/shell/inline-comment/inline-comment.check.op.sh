#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/inline-comment/api.sh"

:<<'DOC'
The inline-comment check: one lint check plugin. See shell/lint/registry.sh
for what the roles mean.
DOC
@check.inline-comment() {
  @summary() {
    println "A # comment addressed to a reader sits only above a module-root constant or variable, leading with its type; a function body carries none."
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
      "Above a root constant or variable, open the comment with # CONST:," \
      "# PUB_CONST:, # VAR: or # PUB_VAR: as the name earns, on one line; longer" \
      "text is the heredoc of the same label. Move what a body" \
      "comment says into the function's doc, or split the function. A" \
      "function's doc is a heredoc. Mark a case this rule did not foresee with" \
      "'# inline-comment-check: allow' and say why."
  }

  @run() {
    lint__checks__shell__inline_comment__run "$@"
  }
}
