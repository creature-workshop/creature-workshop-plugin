#!/bin/sh

: <<'MODULE'
Resolving the binary a test framework runner executes.

Every runner prefers copies it can pin — the project's vendored or
package-managed copy first — over whatever PATH happens to hold. This
is that preference order as a single primitive, so each runner states
only its candidate list.
MODULE

: <<'PUB_FUN'
Echoes the first executable among the candidate paths, falling back to a
PATH lookup of the name; echoes nothing and returns 1 when none resolves.

  testing__resolve_binary vitest "$PROJ/node_modules/.bin/vitest"
    ->  /proj/node_modules/.bin/vitest

args:
  $1    The binary name for the PATH fallback.
  $2..  Candidate paths, most preferred first.
PUB_FUN
testing__resolve_binary() {
  __testing__resolve_binary__name="$1"
  shift

  for __testing__resolve_binary__candidate in "$@"; do
    if [ -x "$__testing__resolve_binary__candidate" ]; then
      printf '%s' "$__testing__resolve_binary__candidate"
      return 0
    fi
  done

  if command -v "$__testing__resolve_binary__name" >/dev/null 2>&1; then
    command -v "$__testing__resolve_binary__name"
    return 0
  fi
  return 1
}
