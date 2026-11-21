#!/bin/sh

: <<'MODULE'
Calling a function with the pieces of a text as its arguments: one per
line, or one per field at a separator. This is how a newline-separated
list -- file paths from git, names from a config file, entries from a
lock -- becomes arguments without splitting on spaces or expanding globs.

The module is plain shell and calls no structs verb: the boot splits the
lock's entries before the structs library loads.

A split sets IFS and puts it back as it found it. A caller that had IFS
unset gets it back unset, which is how a shell splits on its default
characters. A caller running under set -u can therefore read IFS after a
split exactly when it could before one.
MODULE

# CONST: The newline, which args__call_with_lines splits on.
__args__NL="
"

: <<'PUB_FUN'
Calls <fn> with <leading...> first and then one argument per line of
<lines>. Empty <lines> passes only the leading arguments. Returns what
<fn> returns.

  args__call_with_lines printf 'a
  b' '%s|'                       # a|b|

Usage: args__call_with_lines <fn> <lines> [leading...]
PUB_FUN
args__call_with_lines() {
  __args__call_with_lines__fn="$1"
  __args__call_with_lines__lines="$2"
  shift 2
  __args__call_split "$__args__call_with_lines__fn" "$__args__call_with_lines__lines" "$__args__NL" "$@"
}

: <<'PUB_FUN'
Calls <fn> with <leading...> first and then one argument per field of
<text>, split at each <separator>. An empty field between two separators
is kept, so every field keeps its position; a trailing empty field is
dropped. Returns what <fn> returns.

  args__call_with_fields printf 'a||c|' '|' '%s,'   # a,,c,

Usage: args__call_with_fields <fn> <text> <separator> [leading...]
PUB_FUN
args__call_with_fields() {
  __args__call_with_fields__fn="$1"
  __args__call_with_fields__text="$2"
  __args__call_with_fields__separator="$3"
  shift 3
  __args__call_split "$__args__call_with_fields__fn" "$__args__call_with_fields__text" "$__args__call_with_fields__separator" "$@"
}

: <<'FUN'
Calls <fn> with <leading...> first and then one argument per piece of
<text>, split at <separator>, with globbing off so that a piece spelled
like a pattern stays as written. IFS is put back as it was found before
<fn> runs.

args:
  $1  The function to call
  $2  The text to split
  $3  The separator, one character
  $@  The leading arguments, after those three
FUN
__args__call_split() {
  __args__call_split__fn="$1"
  __args__call_split__text="$2"
  __args__call_split__separator="$3"
  shift 3
  __args__call_split__ifs_was_set="${IFS+true}"
  __args__call_split__ifs="${IFS-}"
  set -f
  IFS="$__args__call_split__separator"
  # shellcheck disable=SC2086  # split at the separator, on purpose
  set -- "$@" $__args__call_split__text  # structs-lint: allow -- plain shell, loaded before structs: the split itself is what builds the list
  set +f
  __args__give_back_ifs "$__args__call_split__ifs_was_set" "$__args__call_split__ifs"
  "$__args__call_split__fn" "$@"
}

: <<'FUN'
Puts IFS back the way the caller had it before a split: set to what it
held, or unset.

args:
  $1  "true" when IFS was set before the split, empty when it was unset
  $2  What IFS held, when it was set
FUN
__args__give_back_ifs() {
  if [ -n "$1" ]; then
    IFS="$2"
  else
    unset IFS
  fi
}
