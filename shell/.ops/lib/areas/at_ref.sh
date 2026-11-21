#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/areas/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh"

:<<'MODULE'
The testing config as it stood at an earlier commit, read from git rather than
the working tree, so a caller can compare the mapping a review started from
with the one it arrives at.
MODULE

:<<'PUB_FUN'
Prints the testing config at <ref>: the same file the working tree resolves the
config from (areas__config_path), read at that commit. Prints null when the
working tree resolves no config, when the file is absent or unreadable at the
ref, when it does not parse, or when the config lived elsewhere at that commit
(an inline manifest block that has since moved to a testmap, or the reverse).

  areas__config_at_ref abc123  ->  {"areas": {...}, "suites": {...}}

args:
  $1  The commit to read at

Usage: areas__config_at_ref "$ref"
PUB_FUN
areas__config_at_ref() {
  __areas__config_at_ref__path="$(areas__config_path)"
  if ! @defined "$__areas__config_at_ref__path"; then
    @null __areas__config_at_ref__out
    println "$__areas__config_at_ref__out"
    return 0
  fi

  __areas__config_at_ref__content="$(git__show_file "$1" "$__areas__config_at_ref__path")"
  if ! @defined "$__areas__config_at_ref__content" \
    || ! @is_valid "$__areas__config_at_ref__content"; then
    @null __areas__config_at_ref__out
    println "$__areas__config_at_ref__out"
    return 0
  fi

  case "$__areas__config_at_ref__path" in
    manifest.json) __areas__at_ref__inline "$__areas__config_at_ref__content" ;;
    *) @compact __areas__config_at_ref__out "$__areas__config_at_ref__content"; println "$__areas__config_at_ref__out" ;;
  esac
}

:<<'FUN'
The inline .testing object of a manifest read at a ref, or null when the
manifest there carried no inline block.

args:
  $1  The manifest JSON at the ref
FUN
__areas__at_ref__inline() {
  case "$(__areas__testing_kind "$1")" in
    object) __areas__inline_config "$1" ;;
    *) @null __areas__at_ref__inline__out; println "$__areas__at_ref__inline__out" ;;
  esac
}
