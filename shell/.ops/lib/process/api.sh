#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'MODULE'
Processes on this host: whether one is still there to be signalled.
MODULE

:<<'PUB_FUN'
Prints true when a process with pid $1 is running and this process may
signal it, false otherwise: gone, ended and waiting only to be collected, or
another user's, which to a watcher is the same as gone. Sends nothing;
kill's null signal only asks, and the process table says whether what
answers still runs.

  process__alive "$$"   -> true

args:
  $1  A process id
PUB_FUN
process__alive() {
  if @is_false "$(__process__signallable "$1")"; then
    @false __process__alive__out
    println "$__process__alive__out"
  elif @is_true "$(__process__uncollected "$1")"; then
    @false __process__alive__out
    println "$__process__alive__out"
  else
    @true __process__alive__out
    println "$__process__alive__out"
  fi
}

:<<'FUN'
Prints true when a process with pid $1 is in the process table and this
process may signal it, false otherwise. Sends nothing; kill's null signal
only asks.

args:
  $1  A process id
FUN
__process__signallable() {
  @succeeds __process__signallable__out kill -0 "$1" 2>/dev/null
  println "$__process__signallable__out"
}

:<<'FUN'
Prints true when the process $1 has ended and stays in the process table only
until its parent collects it, false otherwise. kill's null signal cannot tell
such a process from a running one, and a process whose parent has exited is
collected by whatever adopted it, which inside a container is often nothing.

  __process__uncollected 4242   -> true

args:
  $1  A process id
FUN
__process__uncollected() {
  __process__uncollected__state="$(ps -o stat= -p "$1" 2>/dev/null | tr -d '[:space:]')"
  case "$__process__uncollected__state" in
    Z*) @true __process__uncollected__out; println "$__process__uncollected__out" ;;
    *) @false __process__uncollected__out; println "$__process__uncollected__out" ;;
  esac
}
