#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__private_file__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/private-file"

: <<'MODULE'
The private-file check: a file imported only by its own module is named
with a leading _.
MODULE

: <<'PUB_FUN'
Prints each library file in <files...> that is imported only from its own
directory and whose name does not begin with _. A file nothing imports is
not judged. A plugin, a template and an entrypoint are not judged.

Usage: lint__checks__shell__private_file__run <opts> <files...>

The library roots come from the options' config, or the defaults.
PUB_FUN
lint__checks__shell__private_file__run() {
  @obj __lint__checks__shell__private_file__run__obj_1
  @get __lint__checks__shell__private_file__run__get_2 "$1" '.config' "$__lint__checks__shell__private_file__run__obj_1"
  @join __lint__checks__shell__private_file__run__roots "$(lint__config__library_roots "$__lint__checks__shell__private_file__run__get_2")" ' '
  shift
  __lint__checks__shell__private_file__run__hits="$(lint__call_with_existing __lint__checks__shell__private_file__run__scan "$@")"
  @defined "$__lint__checks__shell__private_file__run__hits" || return 0

  log "$__lint__checks__shell__private_file__run__hits"
  return 1
}

: <<'FUN'
Scans <files...> for a private file whose name does not begin with _.
FUN
__lint__checks__shell__private_file__run__scan() {
  awk \
    -v root="$PROJ" \
    -v library_roots="$__lint__checks__shell__private_file__run__roots" \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/library_root.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/name_prefix.awk" \
    -f "$__lint__checks__shell__private_file__DIR/private_file.awk" \
    "$@"
}
