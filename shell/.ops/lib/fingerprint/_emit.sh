#!/bin/sh
# shellcheck disable=SC2119  # bare @arr/@obj are the structs empty constructors

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
Delivering a report's lines: stdout always, FINGERPRINT_OUT additively, so a
step that fingerprints after another adds to the record rather than replacing
it.
FRAGMENT

:<<'FUN'
Prints the lines of <lines> and appends them to FINGERPRINT_OUT. A report of
nothing says nothing and leaves the file alone.
FUN
__fingerprint__emit() {
  if @len __fingerprint__emit__len_1 "$1"; [ "$__fingerprint__emit__len_1" -eq 0 ]; then
    return 0
  fi

  @foreach __fingerprint__print_line "$1"
  __fingerprint__append_out "$1"
}

:<<'FUN'
@foreach callback: prints <line> (wrapped).
FUN
__fingerprint__print_line() {
  @unwrap __fingerprint__print_line__out "$1"
  println "$__fingerprint__print_line__out"
}

:<<'FUN'
Appends the lines of <lines> that FINGERPRINT_OUT does not already carry,
creating its parent directory. A step that fingerprints after another one has to
add to the record rather than replace it.
FUN
__fingerprint__append_out() {
  if ! @defined "${FINGERPRINT_OUT:-}"; then
    return 0
  fi

  __fingerprint__append_out__dir="$(dirname "$FINGERPRINT_OUT")"
  mkdir -p "$__fingerprint__append_out__dir"
  touch "$FINGERPRINT_OUT"

  @foreach __fingerprint__append_line "$1"
}

:<<'FUN'
@foreach callback: appends <line> (wrapped) to FINGERPRINT_OUT unless it is
already there.
FUN
__fingerprint__append_line() {
  @unwrap __fingerprint__append_line__line "$1"

  if grep -qxF "$__fingerprint__append_line__line" "$FINGERPRINT_OUT"; then
    return 0
  fi

  println "$__fingerprint__append_line__line" >> "$FINGERPRINT_OUT"
}
