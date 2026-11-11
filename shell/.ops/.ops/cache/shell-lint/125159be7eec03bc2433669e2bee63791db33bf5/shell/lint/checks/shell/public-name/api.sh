#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__public_name__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/public-name"

: <<'MODULE'
The public-name check: a public name in a library file begins with that
file's module path.
MODULE

: <<'PUB_FUN'
Prints each public definition in <files...> that does not begin with the
file's module path. A library file's module path is the directories under
its library root, the ones the options' config names or the defaults,
joined by __, and api is never a segment of it. A name that begins with __
is private, and one that begins with @ is a role.

Usage: lint__checks__shell__public_name__run <opts> <files...>
PUB_FUN
lint__checks__shell__public_name__run() {
  @obj __lint__checks__shell__public_name__run__obj_1
  @get __lint__checks__shell__public_name__run__get_2 "$1" '.config' "$__lint__checks__shell__public_name__run__obj_1"
  @join __lint__checks__shell__public_name__run__roots "$(lint__config__library_roots "$__lint__checks__shell__public_name__run__get_2")" ' '
  shift
  __lint__checks__shell__public_name__run__hits="$(lint__call_with_existing __lint__checks__shell__public_name__run__scan "$@")"
  @defined "$__lint__checks__shell__public_name__run__hits" || return 0

  log "$__lint__checks__shell__public_name__run__hits"
  return 1
}

: <<'FUN'
Scans <files...> for a public definition outside its module path.
FUN
__lint__checks__shell__public_name__run__scan() {
  awk \
    -v root="$PROJ" \
    -v library_roots="$__lint__checks__shell__public_name__run__roots" \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/library_root.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/name_prefix.awk" \
    -f "$__lint__checks__shell__public_name__DIR/public_name.awk" \
    "$@"
}
