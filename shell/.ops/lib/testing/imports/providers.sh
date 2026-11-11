#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/testing/imports/registry.sh"

: <<'FRAGMENT'
Finds and loads every import provider.

A provider lives in a file named <id>.imports.op.sh somewhere under lib/.
Sourcing this file finds them all, imports each one and registers it under
the id in its filename. Nothing lists the providers anywhere: to add one, add
the file. A dialect composes over a vocabulary plugin by calling its roles
when asked, so the order the files are found in never matters.
FRAGMENT

: <<'PUB_FUN'
Finds every *.imports.op.sh under <root>, imports each and registers it under
the id its filename carries, in sorted path order. Fails when a plugin does
not load.

Usage: testing__imports__load_providers <root>
PUB_FUN
testing__imports__load_providers() {
  __testing__imports__load_providers__files="$(
    find "$1" -name '*.imports.op.sh' \
      | LC_ALL=C sort
  )"

  args__call_with_lines __testing__imports__providers__load_each "$__testing__imports__load_providers__files"
}

: <<'FUN'
Imports each plugin <file> and registers the provider it defines. Runs in the
importing shell, not a pipeline, so the functions a plugin defines stay
defined.
FUN
__testing__imports__providers__load_each() {
  for __testing__imports__providers__load_each__file in "$@"; do
    import "$__testing__imports__providers__load_each__file" || return 1
    testing__imports__load_provider "$(testing__imports__provider_id_of "$__testing__imports__providers__load_each__file")" || return 1
  done
}

: <<'PUB_FUN'
Prints the provider id a plugin <file> carries: its filename without the
directory and without the .imports.op.sh suffix.

    testing__imports__provider_id_of lib/testing/imports/shell/shell.imports.op.sh  ->  shell
PUB_FUN
testing__imports__provider_id_of() {
  __testing__imports__provider_id_of__base="${1##*/}"
  println "${__testing__imports__provider_id_of__base%.imports.op.sh}"
}

testing__imports__load_providers "$SHELLOPS_DIR/lib"
