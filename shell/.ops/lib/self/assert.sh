#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Asserting that ops.lock-provisioned tools are present.

Tools are pinned in ops.lock and installed by `ops install`; building them on
demand from inside an action puts an unrelated dependency tree on the critical
path of the job that needs it, and hides the pin from the lockfile that is
supposed to own it. So the functions here only assert, and every failure names
the ops.lock entry that provisions the missing tool. Domain libs wrap
self__assert_tool in a named assertion (rust__assert_cargo_tool,
node__assert_node, vercel__assert_cli) that supplies their channel and suggested
entry fields.
MODULE

: <<'PUB_FUN'
Asserts that <tool> is on PATH. On a miss, renders the standard error, the
`ops install` provision hint, the suggested ops.lock entry when <channel> is
given, and any extra hint lines, then returns 1.

args:
  $1  Tool name, as `command -v` finds it and ops.lock pins it
  $2  ops.lock channel for the suggested entry; "" skips the suggestion
  $3  Entry fields as a struct; "" renders an empty entry
  $@  Extra hint lines, rendered last

  self__assert_tool cargo-fuzz cargo-binstall "$(@obj '.version' '<version>')"
PUB_FUN
self__assert_tool() {
  __self__assert_tool__tool="${1:?usage: self__assert_tool <tool> [<channel> <entry> [hints...]]}"
  __self__assert_tool__channel="${2:-}"
  __self__assert_tool__entry="${3:-}"
  if [ $# -ge 3 ]; then
    shift 3
  else
    shift $#
  fi

  if command -v "$__self__assert_tool__tool" >/dev/null 2>&1; then
    return 0
  fi

  error "$__self__assert_tool__tool is not installed"
  hint "Provision it with: shell/ops install $__self__assert_tool__tool"

  if [ -n "$__self__assert_tool__channel" ]; then
    hint ""
    self__hint_lock_entry \
      "$__self__assert_tool__tool" \
      "$__self__assert_tool__channel" \
      "$__self__assert_tool__entry"
  fi

  for __self__assert_tool__extra in "$@"; do
    hint "$__self__assert_tool__extra"
  done

  return 1
}

: <<'PUB_FUN'
Renders the "add it to your ops.lock" hint block: the suggestion line, a blank
spacer, then the <channel>.<tool> entry carrying the fields in <entry>,
pretty-printed one hint line at a time.

args:
  $1  Tool name (the entry's key under the channel)
  $2  ops.lock channel (the entry's top-level key)
  $3  Entry fields as a struct; "" renders an empty entry

  self__hint_lock_entry vercel script "$(@obj '.version' '<version>')"
PUB_FUN
self__hint_lock_entry() {
  __self__hint_lock_entry__tool="${1:?usage: self__hint_lock_entry <tool> <channel> <entry>}"
  __self__hint_lock_entry__channel="${2:?usage: self__hint_lock_entry <tool> <channel> <entry>}"
  __self__hint_lock_entry__entry="${3:-}"
  if [ -z "$__self__hint_lock_entry__entry" ]; then
    @obj __self__hint_lock_entry__entry
  fi

  hint "To pin your own version, add it to your ops.lock:"
  hint ""

  @obj __self__hint_lock_entry__block \
      ".\"$__self__hint_lock_entry__channel\".\"$__self__hint_lock_entry__tool\"" \
      "$__self__hint_lock_entry__entry"

  # The outer braces drop so the block reads as an ops.lock fragment; @obj
  # pretty-prints at two spaces, which is also the hint indentation.
  @dump __self__hint_lock_entry__out "$__self__hint_lock_entry__block"
  println "$__self__hint_lock_entry__out" \
    | sed -e '1d' -e '$d' \
    | while IFS= read -r __self__hint_lock_entry__line; do
        hint "$__self__hint_lock_entry__line"
      done
}
