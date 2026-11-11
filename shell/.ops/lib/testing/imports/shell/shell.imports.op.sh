#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'DOC'
The vocabulary of plain shell: a file is loaded by `.` or `source`, and no
variable stands for a root, so only a path written out in full resolves. It
names no language, so it reads no files itself; the shellops provider
composes over it. See lib/testing/imports/registry.sh for what the roles
mean.
DOC
@imports.shell() {
  :<<'FUN'
The two words that load a file in any POSIX shell or bash.
FUN
  @loaders() {
    @arr __at_out . source
    println "$__at_out"
  }
}
