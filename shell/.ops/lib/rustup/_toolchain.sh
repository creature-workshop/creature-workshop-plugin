#!/bin/sh

import "$SHELLOPS_DIR/shell/.logs/shell/log/api.sh"

: <<'FRAGMENT'
Whether the pinned toolchain is whole, and what to do when it is not. A CI
cache keeps the rustup home between jobs, and a job interrupted while
rustup was writing a toolchain leaves a directory with no manifest, which
every later job restores. The script channel asks rustup__installed before
it skips the install, and the warm path in lib/rustup/api.sh removes a
toolchain whose rustc cannot run before it installs it again. Reached
through lib/rustup/api.sh.
FRAGMENT

: <<'PUB_FUN'
Prints true when rustup is on PATH and the toolchain the requirements name
is whole: its rustc runs, and every component the requirements name is
installed on it. Prints false otherwise, which includes a toolchain whose
installation was interrupted before a cache kept it: rustup is on PATH,
the toolchain's directory exists, and its rustc cannot run. The script
channel asks this before it skips the install, so a broken toolchain is
installed again rather than carried from job to job.

  rustup__installed 1.28.2 '{"toolchain":"1.95.0","components":["rustfmt"]}'  ->  true

The components are checked one by one in plain shell, because this runs
while cli/install may still be on the awk structs backend, which answers no
jq-expression verb; component names are single tokens, so the word split
is safe.

args:
  $1  The rustup version pinned; not checked, because rustup keeps itself
      current and the toolchain is what a job runs
  $2  The requirements: the toolchain, and the components it needs
PUB_FUN
rustup__installed() {
  @get __rustup__installed__toolchain "$2" '.toolchain' 'stable'
  @arr __rustup__installed__arr_1
  @get __rustup__installed__get_2 "$2" '.components' "$__rustup__installed__arr_1"
  @join __rustup__installed__components "$__rustup__installed__get_2" " "

  if ! command -v rustup >/dev/null 2>&1; then
    @false __rustup__installed__out
    println "$__rustup__installed__out"
    return 0
  fi

  __rustup__export_homes
  if ! __rustup__toolchain_whole "$__rustup__installed__toolchain"; then
    @false __rustup__installed__out
    println "$__rustup__installed__out"
    return 0
  fi

  for __rustup__installed__component in $__rustup__installed__components; do
    if ! __rustup__component_installed "$__rustup__installed__component" "$__rustup__installed__toolchain"; then
      @false __rustup__installed__out
      println "$__rustup__installed__out"
      return 0
    fi
  done

  @true __rustup__installed__out
  println "$__rustup__installed__out"
}

: <<'FUN'
Succeeds quietly when the toolchain $1 is installed and its rustc runs.
Fails when the toolchain is absent or its installation was interrupted,
which rustup reports as a missing manifest. rustup is told not to install
the toolchain on the way, so asking changes nothing.

args:
  $1  The toolchain
FUN
__rustup__toolchain_whole() {
  RUSTUP_AUTO_INSTALL=0 rustup run "$1" rustc -vV >/dev/null 2>&1
}

: <<'FUN'
Succeeds quietly when the component $1 is installed on the toolchain $2.
Matches on the component's bare name, so `llvm-tools` is satisfied by the
target-suffixed `llvm-tools-x86_64-unknown-linux-gnu` rustup lists.

args:
  $1  The component
  $2  The toolchain
FUN
__rustup__component_installed() {
  rustup component list --installed --toolchain "$2" 2>/dev/null | grep -q "^$1"
}

: <<'FUN'
Removes the toolchain $1 when rustup has a directory for it and its rustc
cannot run, so that the install that follows starts from nothing. Leaves a
whole toolchain, and an absent one, alone.

args:
  $1  The toolchain
FUN
__rustup__remove_broken_toolchain() {
  if __rustup__toolchain_whole "$1"; then
    return 0
  fi
  if ! __rustup__toolchain_present "$1"; then
    return 0
  fi
  warn "rustup toolchain $1 is half-installed; removing it before installing it again"
  rustup toolchain uninstall "$1"
}

: <<'FUN'
Succeeds quietly when rustup lists a toolchain whose name starts with $1,
whether or not it is whole.

args:
  $1  The toolchain
FUN
__rustup__toolchain_present() {
  rustup toolchain list 2>/dev/null | grep -q "^$1"
}
