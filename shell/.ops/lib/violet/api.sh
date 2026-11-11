#!/bin/sh

: <<'MODULE'
Violet legibility linter automation API.

Provides assertion and execution helpers for violet-lint, used by CI jobs
to enforce code legibility thresholds on any repository. Installation is
expected to be handled via ops.lock.
MODULE

: <<'PUB_FUN'
Asserts that violet is available on PATH. Returns 1 with a hint pointing to
the ops.lock entry needed to install it if it is missing.

  violet__assert_installed
PUB_FUN
violet__assert_installed() {
  if command -v violet >/dev/null 2>&1; then
    return 0
  fi

  error "violet is not installed"
  hint "Add it to your ops.lock to install it via 'shell/ops install':"
  hint ""
  hint '  "cargo-install": {'
  hint '    "violet-lint": {'
  hint '      "version": "<version>"'
  hint '    }'
  hint '  }'
  return 1
}

: <<'PUB_FUN'
Runs violet on one or more paths and exits non-zero on violations.
Errors with an ops.lock hint if violet is not installed.

  violet__lint .
  violet__lint src/ --quiet
  violet__lint . --config path/to/violet.yaml
PUB_FUN
violet__lint() {
  __violet__lint__path="${1:-.}"
  if [ "$#" -gt 0 ]; then
    shift
  fi

  violet__assert_installed || return 1
  violet "$__violet__lint__path" "$@"
}
