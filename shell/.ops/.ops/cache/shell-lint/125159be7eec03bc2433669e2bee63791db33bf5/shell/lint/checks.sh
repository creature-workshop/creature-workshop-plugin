#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/config.sh" \
  "$SHELL_LINT_DIR/shell/lint/registry.sh"

: <<'FRAGMENT'
Finds and loads every lint check.

A check lives in a file named <name>.check.op.sh. Sourcing this file finds
every check under shell/lint here and under shellops' lib, whose modules
ship the checks that police them, imports each one and registers it under
the name in its filename. lint__load_project_checks then adds the checks a
repository keeps under the directories its lint.json names. Nothing lists
the checks anywhere: to add one, add the file. Within one root the files
load in sorted path order, so the checks run and --list prints in the same
order on every machine. A name that is already registered keeps its first
plugin, and a later file of that name is left unread.
FRAGMENT

: <<'PUB_FUN'
Finds every *.check.op.sh under <root>, imports each whose name is not yet
registered and registers it under the name its filename carries, in sorted
path order. Fails when a plugin does not load.

Usage: lint__load_checks <root>
PUB_FUN
lint__load_checks() {
  __lint__load_checks__files="$(
    find "$1" -name '*.check.op.sh' \
      | LC_ALL=C sort
  )"

  args__call_with_lines __lint__checks__load_each "$__lint__load_checks__files"
}

: <<'FUN'
Imports each plugin <file> and registers the check it defines. Runs in the
importing shell, not a pipeline, so the functions a plugin defines stay
defined.
FUN
__lint__checks__load_each() {
  for __lint__checks__load_each__file in "$@"; do
    __lint__checks__load_each__name="$(lint__check_name_of "$__lint__checks__load_each__file")"
    if @is_true "$(lint__check_registered "$__lint__checks__load_each__name")"; then
      continue
    fi
    import "$__lint__checks__load_each__file" || return 1
    lint__load_check "$__lint__checks__load_each__name" || return 1
  done
}

: <<'PUB_FUN'
Loads the checks a repository keeps: every *.check.op.sh under each directory
<config> lists under `checks`, relative to PROJ, in the order listed. A
directory that does not exist loads nothing. Fails when a plugin does not
load.

Usage: lint__load_project_checks <config>
PUB_FUN
lint__load_project_checks() {
  __lint__load_project_checks__roots="$(lint__config__check_roots "$1")"
  @foreach __lint__checks__load_root "$__lint__load_project_checks__roots"
}

: <<'FUN'
@foreach callback: loads the checks under the wrapped <root>, relative to
PROJ, when the directory exists.
FUN
__lint__checks__load_root() {
  @unwrap __lint__checks__load_root__unwrap_1 "$1"
  __lint__checks__load_root__dir="$PROJ/$__lint__checks__load_root__unwrap_1"
  [ -d "$__lint__checks__load_root__dir" ] || return 0
  lint__load_checks "$__lint__checks__load_root__dir"
}

: <<'PUB_FUN'
Prints the check name a plugin <file> carries: its filename without the
directory and without the .check.op.sh suffix.

    lint__check_name_of shell/lint/doc-comment.check.op.sh  ->  doc-comment
PUB_FUN
lint__check_name_of() {
  __lint__check_name_of__base="${1##*/}"
  println "${__lint__check_name_of__base%.check.op.sh}"
}

lint__load_checks "$SHELL_LINT_DIR/shell/lint"
lint__load_checks "$SHELLOPS_DIR/lib"
