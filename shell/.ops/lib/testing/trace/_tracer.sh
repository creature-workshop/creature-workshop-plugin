#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
Recording which files a command touches by watching its processes: strace
follows every process the command starts and records every call that names
a file, every connect and every fork. Where the kernel allows a seccomp
filter the other calls are not stopped at all, which keeps the cost near the
untraced run. Private to lib/testing/trace.
FRAGMENT

: <<'CONST'
The calls the tracer records: every call that takes a filename, the
connects, and the forks that let a child's working directory be placed.
CONST
__testing__trace__SYSCALLS="%file,connect,clone,clone3,fork,vfork"

: <<'CONST'
The longest string argument the tracer writes before cutting it, raised
from strace's 32 characters to a path's length so no test file is cut in an
execve's arguments and its runner can be told by it. A filename strace
writes whole regardless.
CONST
__testing__trace__STRING_LIMIT=4096

: <<'CONST'
The flag that filters the untraced calls in the kernel; strace refuses it
where the kernel does.
CONST
__testing__trace__FILTER_FLAG="--seccomp-bpf"

: <<'CONST'
The tracer flags this host takes, found once per shell: the filter flag
when the kernel allows it, nothing when only a plain trace runs, and the
word none when the host cannot trace. Empty until the first probe.
CONST
__testing__trace__FLAGS=""

: <<'CONST'
Set once this shell has probed the host, so the probe runs once.
CONST
__testing__trace__PROBED=""

: <<'FUN'
Prints true when this host can trace a command, false when it cannot: no
strace on the PATH, or a kernel or container that refuses ptrace. Probed
once per shell, by tracing the true command.

Usage: if @is_true "$(__testing__trace__permitted)"; then ... fi
FUN
__testing__trace__permitted() {
  __testing__trace__probe
  @fails __testing__trace__permitted__out [ "$__testing__trace__FLAGS" = none ]
  println "$__testing__trace__permitted__out"
}

: <<'FUN'
Settles __testing__trace__FLAGS, on the first call only: the filter flag
when a filtered trace of true runs, nothing when only an unfiltered one
does, none when neither does or strace is missing.
FUN
__testing__trace__probe() {
  if @defined "$__testing__trace__PROBED"; then
    return 0
  fi
  __testing__trace__PROBED=1

  if ! command -v strace >/dev/null 2>&1; then
    __testing__trace__FLAGS=none
    return 0
  fi
  if __testing__trace__runs "$__testing__trace__FILTER_FLAG"; then
    __testing__trace__FLAGS="$__testing__trace__FILTER_FLAG"
    return 0
  fi
  if __testing__trace__runs; then
    __testing__trace__FLAGS=""
    return 0
  fi
  __testing__trace__FLAGS=none
}

: <<'FUN'
Succeeds quietly when strace with the given flags traces the true command
to the end.

args:
  $@  Extra strace flags
FUN
__testing__trace__runs() {
  __testing__trace__strace "/dev/null" "$@" -- true >/dev/null 2>&1
}

: <<'FUN'
Runs a command under the tracer and writes the trace to a file, returning
the command's own status. The command's output passes through untouched.
Fails, naming why, when the host cannot trace.

  __testing__trace__record trace.txt bats test/string.api.bats

args:
  $1  The file to write the trace to
  $@  The command and its arguments
FUN
__testing__trace__record() {
  __testing__trace__record__out="$1"
  shift

  if @is_false "$(__testing__trace__permitted)"; then
    error "testing/trace: this host cannot trace: strace is missing, or ptrace is not permitted here."
    return 1
  fi

  if @defined "$__testing__trace__FLAGS"; then
    __testing__trace__strace "$__testing__trace__record__out" "$__testing__trace__FLAGS" -- "$@"
  else
    __testing__trace__strace "$__testing__trace__record__out" -- "$@"
  fi
}

: <<'FUN'
The strace invocation: every process followed, the recorded calls named,
signals and the attach and exit notices left out, the trace written to $1.
The flags and the command follow.

args:
  $1  The file to write the trace to
  $@  Extra strace flags, then -- and the command
FUN
__testing__trace__strace() {
  __testing__trace__strace__out="$1"
  shift
  strace \
    -f \
    -qq \
    -e "trace=$__testing__trace__SYSCALLS" \
    -e signal=none \
    -s "$__testing__trace__STRING_LIMIT" \
    -o "$__testing__trace__strace__out" \
    "$@"
}
