#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/language/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/registry.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
What one file is, for the linter: its language (shell, awk, jq or markdown),
its scope (code or tests), and whether it is a file the linter reads at all.
Every check sees a file the same way because every check asks this module;
the language is the one lib/language/api.sh names, kept to the ones the
registry's checks may read.

The answer for a file is one listing line: language, scope and path, separated
by tabs. Paths with a newline or a tab in them cannot ride in that line, so
ops lint refuses them.
FRAGMENT

__lint__classify__NL="
"
__lint__classify__TAB="$(printf '\t')"

: <<'PUB_FUN'
Prints true when <path> has no newline and no tab in it, false otherwise.
PUB_FUN
lint__is_plain_path() {
  case "$1" in
    *"$__lint__classify__NL"*|*"$__lint__classify__TAB"*) @false __lint__is_plain_path__out; println "$__lint__is_plain_path__out" ;;
    *) @true __lint__is_plain_path__out; println "$__lint__is_plain_path__out" ;;
  esac
}

: <<'PUB_FUN'
Prints the language of the file at <path>: shell for .sh, .bats or a shell
shebang, awk for .awk, jq for .jq, markdown for .md. Prints nothing for any
other file. The answer is language__of_path's.
PUB_FUN
lint__language() {
  language__of_path "$1"
}

: <<'PUB_FUN'
Prints true when one of <path>'s directories is named as one of the <tree>
names, false otherwise. Only whole names count: with tree "test",
testing/x.sh and lib/test.sh are both false.

Usage: lint__is_test_path <path> [tree...]
PUB_FUN
lint__is_test_path() {
  __lint__is_test_path__path="/$1/"
  shift

  for __lint__is_test_path__tree in "$@"; do
    case "$__lint__is_test_path__path" in
      *"/$__lint__is_test_path__tree/"*)
        @true __lint__is_test_path__out
        println "$__lint__is_test_path__out"
        return 0
        ;;
    esac
  done

  @false __lint__is_test_path__out
  println "$__lint__is_test_path__out"
}

: <<'PUB_FUN'
Prints true when <rel> is one of the <prefix> directories or a path under one,
false otherwise. Only whole names count: with prefix "test", testing/x.sh is
false.

Usage: lint__rel_is_excluded <rel> [prefix...]
PUB_FUN
lint__rel_is_excluded() {
  __lint__rel_is_excluded__rel="$1"
  shift

  for __lint__rel_is_excluded__prefix in "$@"; do
    case "$__lint__rel_is_excluded__rel" in
      "$__lint__rel_is_excluded__prefix"|"$__lint__rel_is_excluded__prefix"/*)
        @true __lint__rel_is_excluded__out
        println "$__lint__rel_is_excluded__out"
        return 0
        ;;
    esac
  done

  @false __lint__rel_is_excluded__out
  println "$__lint__rel_is_excluded__out"
}

: <<'PUB_FUN'
Prints <path> relative to PROJ when it is under PROJ, and <path> unchanged
otherwise.
PUB_FUN
lint__rel_path() {
  case "$1" in
    "$PROJ"/*)
      printf '%s\n' "${1#"$PROJ"/}"
      ;;
    *)
      println "$1"
      ;;
  esac
}

: <<'PUB_FUN'
Prints the listing line for the file at <path>, or nothing when no check may
read its language. The scope is tests when the PROJ-relative path is under
one of the test <trees> (given one per line), and code otherwise. Reading the
relative path means a PROJ that itself sits under a directory named test does
not make every file a test.

    lint__classify /repo/test/x.bats test  ->  shell<TAB>tests<TAB>/repo/test/x.bats

Usage: lint__classify <path> <trees>
PUB_FUN
lint__classify() {
  __lint__classify__language="$(lint__language "$1")"
  @defined "$__lint__classify__language" || return 0
  @is_true "$(lint__registry__knows_language "$__lint__classify__language")" || return 0

  __lint__classify__rel="$(lint__rel_path "$1")"
  if @is_true "$(args__call_with_lines lint__is_test_path "$2" "$__lint__classify__rel")"; then
    __lint__classify__scope=tests
  else
    __lint__classify__scope=code
  fi

  printf '%s\t%s\t%s\n' \
    "$__lint__classify__language" \
    "$__lint__classify__scope" \
    "$1"
}
