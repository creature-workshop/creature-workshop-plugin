#!/bin/sh

import \
  "$SHELL_LINT_DIR/shell/lint/checks/templates/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The template-declares-inputs check: one rule over a catalog's CI component templates, run
over the templates the shared templates module selects.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__templates__declares_inputs__DIR="$SHELL_LINT_DIR/shell/lint/checks/templates/declares-inputs"

: <<'PUB_FUN'
Reports each template in <files...> that has no spec.inputs block. The
finding is on line 1, since a missing block has no line of its own. Files
that are not templates are skipped.

  lint__checks__templates__declares_inputs__run "$opts" templates/shell--lint/template.yml
    ->  templates/shell--lint/template.yml:1: no spec.inputs block; every template starts with one

Returns 0 when every template has the block, 1 otherwise.

Usage: lint__checks__templates__declares_inputs__run <opts> <files...>
PUB_FUN
lint__checks__templates__declares_inputs__run() {
  lint__checks__templates__declares_inputs__run__files="$(lint__checks__templates__select "$@")"
  lint__checks__templates__report "$__lint__checks__templates__declares_inputs__DIR/declares_inputs.awk" "$lint__checks__templates__declares_inputs__run__files"
}
