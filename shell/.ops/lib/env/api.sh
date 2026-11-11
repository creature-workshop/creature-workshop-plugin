#!/bin/sh
# shellcheck disable=SC2119  # bare @arr/@obj are the structs empty constructors

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Environment preflight API.

Asserts required environment variables before a job spends any work,
naming every missing one instead of failing on the first.
MODULE

: <<'PUB_FUN'
Asserts that every named variable is set and non-empty, reporting each
missing one before failing.

usage: env__require VERCEL_TOKEN VERCEL_ORG_ID
PUB_FUN
env__require() {
  @arr __env__require__arr_1 "$@"
  @arr __env__require__arr_2
  @reduce __env__require__missing __env__collect_missing \
      "$__env__require__arr_1" \
      "$__env__require__arr_2"

  if @len __env__require__len_3 "$__env__require__missing"; [ "$__env__require__len_3" -eq 0 ]; then
    return 0
  fi

  @foreach __env__report_missing "$__env__require__missing"
  return 1
}

: <<'FUN'
@reduce callback: appends the variable name to the accumulator when the
environment leaves it unset or empty.

args:
  $1  The accumulator (array of missing variable names)
  $2  The variable name (wrapped)
FUN
__env__collect_missing() {
  @unwrap __env__collect_missing__name "$2"

  if @defined "$(printenv "$__env__collect_missing__name" || true)"; then
    println "$1"
    return
  fi

  @push __env__collect_missing__out "$1" "$2"
  println "$__env__collect_missing__out"
}

__env__report_missing() {
  @unwrap __env__report_missing__unwrap_4 "$1"
  error "$__env__report_missing__unwrap_4 is not set"
}
