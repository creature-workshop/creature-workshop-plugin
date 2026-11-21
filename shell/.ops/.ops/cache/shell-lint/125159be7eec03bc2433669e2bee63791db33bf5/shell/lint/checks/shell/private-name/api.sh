#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__private_name__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/private-name"

: <<'MODULE'
The private-name check: a private name in a library file is fully qualified: a function or a
constant begins with the module path, so a caller outside the module cannot
spell it, and a function's variable begins with the module path and then the
function's own name, so no two functions can collide.
MODULE

: <<'PUB_FUN'
Prints each private name in <files...> that is not fully qualified. A
library file's module path is the directories under its library root, the
ones the options' config names or the defaults, joined by __, and the
barrel's stem, api, is never a segment of it. A variable assigned in a
function begins with __<module>__<function>__, the function's own name once
the module's spelling is dropped; a plugin role's begins with
__<plugin>_<role>__. A variable read in a function may be any of the
module's.

Usage: lint__checks__shell__private_name__run <opts> <files...>
PUB_FUN
lint__checks__shell__private_name__run() {
  @obj __lint__checks__shell__private_name__run__obj_1
  @get __lint__checks__shell__private_name__run__get_2 "$1" '.config' "$__lint__checks__shell__private_name__run__obj_1"
  @join __lint__checks__shell__private_name__run__roots "$(lint__config__library_roots "$__lint__checks__shell__private_name__run__get_2")" ' '
  shift
  __lint__checks__shell__private_name__run__hits="$(lint__call_with_existing __lint__checks__shell__private_name__run__scan "$@")"
  @defined "$__lint__checks__shell__private_name__run__hits" || return 0

  log "$__lint__checks__shell__private_name__run__hits"
  return 1
}

: <<'FUN'
Scans <files...> for a private name outside its module path.
FUN
__lint__checks__shell__private_name__run__scan() {
  awk \
    -v root="$PROJ" \
    -v library_roots="$__lint__checks__shell__private_name__run__roots" \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/library_root.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/name_prefix.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/scope.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/words.awk" \
    -f "$__lint__checks__shell__private_name__DIR/private_name.awk" \
    "$@"
}
