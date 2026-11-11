#!/bin/sh
# General-purpose string utilities for shellops.

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'PUB_FUN'
Returns 0 if text contains the given substring, 1 otherwise.

Usage: string__contains "$text" "$substring"
PUB_FUN
string__contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

:<<'PUB_FUN'
Returns 0 if text starts with the given prefix, 1 otherwise.

Usage: string__starts_with "$text" "$prefix"
PUB_FUN
string__starts_with() {
  case "$1" in
    "$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

:<<'PUB_FUN'
Returns 0 if text ends with the given suffix, 1 otherwise.

Usage: string__ends_with "$text" "$suffix"
PUB_FUN
string__ends_with() {
  case "$1" in
    *"$2") return 0 ;;
    *) return 1 ;;
  esac
}

:<<'PUB_FUN'
Prints a tab. POSIX shell has no escape for one inside a string, so a caller
that needs the character asks here rather than spelling printf '\t' itself.

Usage: tab="$(string__tab)"
PUB_FUN
string__tab() {
  printf '\t'
}

:<<'PUB_FUN'
Prints TEXT with trailing newlines removed.

Usage: string__trim_newlines "$text"
PUB_FUN
string__trim_newlines() {
  __string__trim_newlines__text="$1"
  __string__trim_newlines__nl="$(printf '\n')"
  while [ -n "$__string__trim_newlines__text" ] \
    && [ "${__string__trim_newlines__text%"$__string__trim_newlines__nl"}" != "$__string__trim_newlines__text" ]
  do
    __string__trim_newlines__text="${__string__trim_newlines__text%"$__string__trim_newlines__nl"}"
  done
  printf '%s' "$__string__trim_newlines__text"
}

:<<'FUN'
Replaces every literal occurrence of a marker in text with a replacement,
preserving empty segments (leading, trailing, and adjacent matches round-trip
exactly, e.g. ",a," with marker "," -> "-a-"). Pure POSIX parameter expansion,
so it sidesteps @split/@join (whose backend drops empty segments). Internal
helper; callers should go through string__replace / string__replace_json.

Usage: __string__replace_all "$text" "$marker" "$replacement"
FUN
__string__replace_all() {
  __string__replace_all__rest="$1"
  __string__replace_all__marker="$2"
  __string__replace_all__replacement="$3"
  __string__replace_all__out=""

  while :; do
    case "$__string__replace_all__rest" in
      *"$__string__replace_all__marker"*)
        __string__replace_all__out="$__string__replace_all__out${__string__replace_all__rest%%"$__string__replace_all__marker"*}$__string__replace_all__replacement"
        __string__replace_all__rest="${__string__replace_all__rest#*"$__string__replace_all__marker"}"
        ;;
      *)
        println "$__string__replace_all__out$__string__replace_all__rest"
        return 0
        ;;
    esac
  done
}

:<<'PUB_FUN'
Replaces every occurrence of a literal marker with a plain string.
Markers are exact substrings, not patterns.

Usage: string__replace "$text" "$marker" "$replacement"
PUB_FUN
string__replace() {
  __string__replace__text="$1"
  __string__replace__marker="$2"
  __string__replace__replacement="$3"
  @encode_string __string__replace__encode_string_1 "$__string__replace__replacement"
  string__replace_json "$__string__replace__text" "$__string__replace__marker" "$__string__replace__encode_string_1"
}

:<<'PUB_FUN'
Replaces every occurrence of a literal marker with a JSON value. JSON strings
are inserted as raw text; structured values (objects, arrays, numbers, booleans,
null) are serialized to compact JSON first.

Usage: string__replace_json "$text" "$marker" "$value_json"
PUB_FUN
string__replace_json() {
  __string__replace_json__text="$1"
  __string__replace_json__marker="$2"
  __string__replace_json__value_json="$3"

  if [ -z "$__string__replace_json__marker" ]; then
    fatal "string__replace_json: marker must be non-empty"
    return 1
  fi

  if ! @is_valid "$__string__replace_json__value_json"; then
    fatal "string__replace_json: value must be valid JSON"
    return 1
  fi

  @obj __string__replace_json__obj_2 '.compact' true
  @unwrap __string__replace_json__rendered "$__string__replace_json__value_json" "$__string__replace_json__obj_2"
  __string__replace_all "$__string__replace_json__text" "$__string__replace_json__marker" "$__string__replace_json__rendered"
}

:<<'PUB_FUN'
Reads a file and applies one marker substitution (same rules as
string__replace_json). Writes the result to stdout.

Usage: string__replace_file "$path" "$marker" "$value_json"
PUB_FUN
string__replace_file() {
  __string__replace_file__path="$1"
  __string__replace_file__marker="$2"
  __string__replace_file__value_json="$3"

  if [ ! -f "$__string__replace_file__path" ]; then
    fatal "string__replace_file: file not found: $__string__replace_file__path"
    return 1
  fi

  string__replace_json "$(cat "$__string__replace_file__path")" "$__string__replace_file__marker" "$__string__replace_file__value_json"
}
