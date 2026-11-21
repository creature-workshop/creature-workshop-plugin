#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/imports/shell/scan.sh" \
  "$SHELLOPS_DIR/lib/testing/imports/shell/shell.imports.op.sh"

:<<'DOC'
The import provider for shellops, the shell dialect this library is written
in. `import` is a loop over `.`, so the dialect adds one word to plain
shell's and one root, SHELLOPS_DIR, the directory nearly every import is
written under. See lib/testing/imports/registry.sh for what the roles mean.

`import__glob` loads whatever a find matches when it runs, which no static
read can name, so those loads stay invisible here.
DOC
@imports.shellops() {
  :<<'FUN'
Every shell file is read as shellops: the dialect's words are a superset of
plain shell's, so a plain script reads the same either way.
FUN
  @language() {
    printf 'shell\n'
  }

  :<<'FUN'
Plain shell's loading words, and `import`.
FUN
  @loaders() {
    @push __at_out "$(shell_loaders)" import
    println "$__at_out"
  }

  :<<'FUN'
The one variable an import path is written under, bound to the directory it
stands for in this process, so "$SHELLOPS_DIR/lib/git/api.sh" in a source
file resolves to that file: the repo root when the project is shellops
itself, shell/.ops when it is a consumer. A consumer's edges into shell/.ops
then name files no area covers, and the scorecard drops them.
FUN
  @roots() {
    @obj __at_out '.SHELLOPS_DIR' "$SHELLOPS_DIR"
    println "$__at_out"
  }

  :<<'FUN'
The loads among the given shell files, read by the shell scanner with the
dialect's words and root.
FUN
  @edges() {
    testing__imports__shell__edges "$(shellops_loaders)" "$(shellops_roots)" "$1"
  }
}
