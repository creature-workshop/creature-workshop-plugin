#!/bin/sh

: <<'MODULE'
What the boot settles for the structs library before it loads: SILT's
verbs, which the library's verbs run on in the calling shell. The boot
calls it once, before .envrc sources the library.

  self__structs__backend   ->  STRUCTS_BACKEND=silt, and SILT's verbs present
MODULE

: <<'PUB_FUN'
Names silt as the backend the structs library runs on, in STRUCTS_BACKEND,
and makes SILT's verbs present, since the library's verbs run on them in
the calling shell (ADR 000048). Sets a variable rather than printing, so
the boot forks nothing for it. Fails when SILT_DIR names no library.
PUB_FUN
self__structs__backend() {
  # shellcheck disable=SC2034  # read by whoever loads the library next
  STRUCTS_BACKEND="silt"
  self__structs__silt
}

: <<'PUB_FUN'
Makes SILT's verbs present in this shell, sourcing the library from the
strata tree SILT_DIR names when they are not yet. Fails, saying so, when
SILT_DIR is unset or names no library.
PUB_FUN
self__structs__silt() {
  if command -v silt__from_yaml >/dev/null 2>&1; then
    return 0
  fi
  if [ -z "${SILT_DIR:-}" ] || [ ! -f "$SILT_DIR/api.sh" ]; then  # structs-lint: allow -- plain shell, before structs loads
    error "SILT_DIR does not name the SILT library; boot fetches strata before the shell loads (ADR 000048)"
    return 1
  fi
  . "$SILT_DIR/api.sh"
}
