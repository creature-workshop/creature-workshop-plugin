#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/banner-comment/api.sh"

:<<'DOC'
The banner-comment check: one lint check plugin. See shell/lint/registry.sh
for what the roles mean. A banner is a banner in a test file too, so tests
are in scope.
DOC
@check.banner-comment() {
  @summary() {
    println "No divider or free-floating banner comments; a section boundary becomes its own file."
  }

  @languages() {
    @arr __at_out shell awk jq
    println "$__at_out"
  }

  @scopes() {
    @arr __at_out code tests
    println "$__at_out"
  }

  @hint() {
    printf '%s\n' \
      "Split the concern the banner names into its own file (banners-mean-split);" \
      "a comment must document the code directly beneath it, or fold what it" \
      "says into the file's doc comment. If the line is load-bearing data," \
      "mark it with '# banner-lint: allow' and explain why."
  }

  @run() {
    lint__checks__shell__banner_comment__run "$@"
  }
}
