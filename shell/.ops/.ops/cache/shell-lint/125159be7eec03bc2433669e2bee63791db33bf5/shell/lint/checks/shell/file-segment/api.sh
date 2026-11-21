#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__file_segment__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/file-segment"

: <<'MODULE'
The file-segment check: a name in a library file spells the file's stem as
a segment of its own, lint__config__load in config.sh and not
lint__config_load.
MODULE

: <<'PUB_FUN'
Prints each name in <files...> that follows its file's module path with the
file's stem and one underscore. A library file's module path is the
directories under its library root, the ones the options' config names or
the defaults, joined by __; the stem is the file's name without .sh. The
barrel api.sh, a plugin and a file that sits in a library root itself have
no stem to judge.

Usage: lint__checks__shell__file_segment__run <opts> <files...>
PUB_FUN
lint__checks__shell__file_segment__run() {
  @obj __lint__checks__shell__file_segment__run__obj_1
  @get __lint__checks__shell__file_segment__run__get_2 "$1" '.config' "$__lint__checks__shell__file_segment__run__obj_1"
  @join __lint__checks__shell__file_segment__run__roots "$(lint__config__library_roots "$__lint__checks__shell__file_segment__run__get_2")" ' '
  shift
  __lint__checks__shell__file_segment__run__hits="$(lint__call_with_existing __lint__checks__shell__file_segment__run__scan "$@")"
  @defined "$__lint__checks__shell__file_segment__run__hits" || return 0

  log "$__lint__checks__shell__file_segment__run__hits"
  return 1
}

: <<'FUN'
Scans <files...> for a name that spells its file's stem with one underscore.
FUN
__lint__checks__shell__file_segment__run__scan() {
  awk \
    -v root="$PROJ" \
    -v library_roots="$__lint__checks__shell__file_segment__run__roots" \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/library_root.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/name_prefix.awk" \
    -f "$__lint__checks__shell__file_segment__DIR/file_segment.awk" \
    "$@"
}
