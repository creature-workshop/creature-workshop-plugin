#!/bin/sh

: <<'MODULE'
What every check shares: the call that drops the files that do not exist
before a scanner runs, and the form a scanner takes a flag in. A check is a
module under shell/lint/checks, one folder each, holding its plugin, its
driver, its detector and its fixtures; what a family of checks shares beyond
this is in comments/, decisions/ and templates/, and the awk libraries a
detector loads are under lib/.

Note: structs API enforcement (rejecting raw jq/opx) lives with the module it
polices, in shellops' lib/structs/lint/api.sh.
MODULE

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/config.sh"

: <<'PUB_FUN'
Calls <fn> with the files among <paths...> that exist, in their order, so a
scanner runs once over every file rather than once per file. A path that is
not a file is dropped, as a single-file scan drops it. With no file left,
<fn> is not called at all: an awk given no file reads stdin and waits.

Usage: lint__call_with_existing <fn> <paths...>
PUB_FUN
lint__call_with_existing() {
  __lint__call_with_existing__fn="$1"
  shift
  __lint__call_with_existing__count=$#
  __lint__call_with_existing__i=0
  while [ "$__lint__call_with_existing__i" -lt "$__lint__call_with_existing__count" ]; do
    if [ -f "$1" ]; then
      set -- "$@" "$1"
    fi
    shift
    __lint__call_with_existing__i=$((__lint__call_with_existing__i + 1))
  done

  [ "$#" -gt 0 ] || return 0
  "$__lint__call_with_existing__fn" "$@"
}

: <<'PUB_FUN'
Echoes 1 for the boolean true and 0 for anything else -- the form the scanners
take a flag in through -v.
PUB_FUN
lint__awk_flag() {
  case "$1" in
    true) echo 1 ;;
    *) echo 0 ;;
  esac
}

: <<'PUB_FUN'
  Checks Go files for formatting issues using gofmt.

  Usage: lint__go [files...]

  If no files are provided, checks all Go files under go/.
  Returns 0 if all files are formatted, 1 otherwise.
PUB_FUN
lint__go() {
  __lint__go__repo_root="$(git rev-parse --show-toplevel)"

  if [ "$#" -eq 0 ]; then
    set -- "$__lint__go__repo_root/go/"
  fi

  __lint__go__unformatted="$(gofmt -l "$@" 2>/dev/null || true)"

  if @defined "$__lint__go__unformatted"; then
    echo "The following Go files need formatting:"
    echo "$__lint__go__unformatted"
    echo ""
    echo "Run 'gofmt -w go/' to fix."
    return 1
  fi

  return 0
}

: <<'PUB_FUN'
  Checks Rust files for formatting issues using rustfmt.

  Usage: lint__rust

  Checks all Rust files in the crates workspace.
  Returns 0 if all files are formatted, 1 otherwise.
PUB_FUN
lint__rust() {
  __lint__rust__repo_root="$(git rev-parse --show-toplevel)"

  if ! cargo fmt --manifest-path "$__lint__rust__repo_root/crates/Cargo.toml" --all -- --check; then
    echo ""
    echo "Run 'cargo fmt --manifest-path crates/Cargo.toml --all' to fix."
    return 1
  fi

  return 0
}
