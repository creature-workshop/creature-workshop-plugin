#!/bin/sh

import \
  "$SHELL_LINT_DIR/shell/lint/checks/templates/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The template-inherits-bootstrap check: one rule over a catalog's CI component templates, run
over the templates the shared templates module selects.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__templates__inherits_bootstrap__DIR="$SHELL_LINT_DIR/shell/lint/checks/templates/inherits-bootstrap"

: <<'PUB_FUN'
Reports each job in <files...> that defines its own before_script. The base
template lint.json names is exempt; files that are not templates are
skipped.

  lint__checks__templates__inherits_bootstrap__run "$opts" templates/shell--test/template.yml
    ->  templates/shell--test/template.yml:12: job '$[[ inputs.job-name ]]' defines before_script; remove it and extend the base job

Returns 0 when no job outside the base defines one, 1 otherwise.

Usage: lint__checks__templates__inherits_bootstrap__run <opts> <files...>
PUB_FUN
lint__checks__templates__inherits_bootstrap__run() {
  lint__checks__templates__inherits_bootstrap__run__base="$(lint__checks__templates__base "$1")"
  @arr lint__checks__templates__inherits_bootstrap__run__exempt "$lint__checks__templates__inherits_bootstrap__run__base"
  lint__checks__templates__inherits_bootstrap__run__files="$(lint__checks__templates__select "$@")"
  lint__checks__templates__inherits_bootstrap__run__held="$(lint__checks__templates__without \
    "$lint__checks__templates__inherits_bootstrap__run__files" \
    "$lint__checks__templates__inherits_bootstrap__run__exempt"
  )"
  lint__checks__templates__report "$__lint__checks__templates__inherits_bootstrap__DIR/inherits_bootstrap.awk" "$lint__checks__templates__inherits_bootstrap__run__held"
}
