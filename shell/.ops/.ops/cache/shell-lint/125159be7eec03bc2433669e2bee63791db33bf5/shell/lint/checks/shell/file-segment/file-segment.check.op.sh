#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/file-segment/api.sh"

:<<'DOC'
The file-segment check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.file-segment() {
  @summary() {
    println "A name in a library file spells the file's stem as a segment of its own: lint__config__load in config.sh, not lint__config_load."
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
      "A file inside a module adds a segment. Follow the module path with the" \
      "file's stem and a double underscore, then the rest of the name:" \
      "lint__config__load, and __lint__config__load__file for its variables." \
      "The barrel api.sh, a plugin and a file at a library root have no stem." \
      "Mark a line the rule does not fit with '# file-segment-check: allow'" \
      "and say why."
  }

  @run() {
    lint__checks__shell__file_segment__run "$@"
  }
}
