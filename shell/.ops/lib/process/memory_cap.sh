#!/bin/sh

: <<'MODULE'
A per-process memory cap for the commands the git hooks, the CI jobs and the
test runner start, so a process that runs away dies alone, with its own error, instead
of taking the machine down with it.

The cap is an address-space limit, the one Linux enforces per process, and
every child inherits it. SHELLOPS_MEMORY_CAP_KB sets it in kilobytes and
"unlimited" turns it off. Unset, it is 4 GB: above anything a lint, a
shellcheck, a bats file or a rustc needs, and below what a workstation
cannot survive losing.
MODULE

__process__memory_cap__DEFAULT_KB=4194304

: <<'PUB_FUN'
Prints the cap in kilobytes: SHELLOPS_MEMORY_CAP_KB when set, the default
otherwise.

  SHELLOPS_MEMORY_CAP_KB=204800 process__memory_cap__kb   -> 204800
PUB_FUN
process__memory_cap__kb() {
  println "${SHELLOPS_MEMORY_CAP_KB:-$__process__memory_cap__DEFAULT_KB}"
}

: <<'PUB_FUN'
Caps the calling shell and everything it starts from here on. Fails when
the shell refuses the value, as it does for one above its hard limit.
PUB_FUN
process__memory_cap__apply() {
  # shellcheck disable=SC3045  # ulimit -v: every sh here (dash, bash) has it
  ulimit -v "$(process__memory_cap__kb)"
}

: <<'PUB_FUN'
Runs a command under the cap, in a subshell so the caller stays as it was,
and passes the command's output and exit status through.

  process__memory_cap__run sh -c 'ulimit -v'   -> 4194304

args:
  $@  The command and its arguments; a shell function serves as well as a program
PUB_FUN
process__memory_cap__run() {
  (
    process__memory_cap__apply || exit 1
    "$@"
  )
}
