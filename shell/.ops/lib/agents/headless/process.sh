#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/process/api.sh"

:<<'FRAGMENT'
Starting a headless run's process and reading it back: the CLI goes into the
background under the recorder beside this file, detached where the system
allows it, and what the run directory holds afterwards says whether it is
still going, finished, failed or was stopped.
FRAGMENT

__agents__headless__RECORDED="$SHELLOPS_DIR/lib/agents/headless/recorded"

:<<'PUB_FUN'
Starts the CLI over the run, keeping the prompt beside it: the run directory
is made, the prompt written into it, and the arguments $3 run in the
background with the key in the environment. Prints nothing; the run directory
is where the run's state appears.

args:
  $1  The adaptor's context
  $2  The run ({dir, prompt, cwd, key})
  $3  The command and its arguments, as an array
PUB_FUN
agents__headless__start() {
  @get __agents__headless__start__dir "$2" '.dir'
  mkdir -p "$__agents__headless__start__dir"
  @get __agents__headless__start__get_1 "$2" '.prompt'
  println "$__agents__headless__start__get_1" > "$__agents__headless__start__dir/prompt"
  @apply __agents__headless__spawn "$1" "$2" "$3"
}

:<<'FUN'
Runs the command given after the run in the background under the recorder,
with the run directory as its state, the adaptor's key variable carrying the
key, and the run's own working directory for the command. Detaches from this
shell's session where setsid allows, so a cancel can end the whole process
group. Writes the pid the recorder overwrites with its own the moment it
starts.

args:
  $1  The adaptor's context
  $2  The run ({dir, prompt, cwd, key})
  $3+ The command and its arguments
FUN
__agents__headless__spawn() {
  @get __agents__headless__spawn__dir "$2" '.dir'
  @get __agents__headless__spawn__cwd "$2" '.cwd'
  @get __agents__headless__spawn__get_2 "$1" '.token_env'
  @get __agents__headless__spawn__get_3 "$2" '.key'
  __agents__headless__spawn__key="$__agents__headless__spawn__get_2=$__agents__headless__spawn__get_3"
  shift 2
  set -- "$__agents__headless__RECORDED" "$__agents__headless__spawn__dir" "$__agents__headless__spawn__cwd" "$@"
  if command -v setsid >/dev/null 2>&1; then
    set -- setsid "$@"
  fi
  env "$__agents__headless__spawn__key" "$@" </dev/null >/dev/null 2>&1 &
  println "$!" > "$__agents__headless__spawn__dir/pid"
}

:<<'FUN'
Prints the pid recorded for the run directory $1, nothing when none is.
FUN
__agents__headless__pid() {
  if [ -f "$1/pid" ]; then
    tr -d '[:space:]' < "$1/pid"
  fi
}

:<<'FUN'
Prints the status of the run directory $1 in the contract's vocabulary:
CANCELLED once a cancel marked it, else FINISHED or ERROR by the recorded
exit code, else RUNNING while the process lives, ERROR when it died without
recording an exit, and CREATING before it was started.

  __agents__headless__status /state/chat-1/run-1  ->  RUNNING
FUN
__agents__headless__status() {
  if [ -f "$1/cancelled" ]; then
    printf 'CANCELLED\n'
  elif [ -f "$1/exit" ]; then
    __agents__headless__exit_status "$1"
  else
    __agents__headless__live_status "$1"
  fi
}

:<<'FUN'
Prints FINISHED when the run directory $1 recorded a zero exit code, ERROR
otherwise.
FUN
__agents__headless__exit_status() {
  if [ "$(__agents__headless__exit_code "$1")" = 0 ]; then
    printf 'FINISHED\n'
  else
    printf 'ERROR\n'
  fi
}

:<<'FUN'
Prints the status of the run directory $1 that recorded no exit: RUNNING
while its process lives, ERROR when it had one that died, CREATING when it
was never started.
FUN
__agents__headless__live_status() {
  __agents__headless__live_status__pid="$(__agents__headless__pid "$1")"
  if ! @defined "$__agents__headless__live_status__pid"; then
    printf 'CREATING\n'
  elif @is_true "$(process__alive "$__agents__headless__live_status__pid")"; then
    printf 'RUNNING\n'
  else
    printf 'ERROR\n'
  fi
}

:<<'FUN'
Prints the exit code the run directory $1 recorded, nothing before it
recorded one.
FUN
__agents__headless__exit_code() {
  if [ -f "$1/exit" ]; then
    tr -d '[:space:]' < "$1/exit"
  fi
}

:<<'FUN'
Ends the run directory $1's process and everything it started, and marks the
run cancelled so its record says so. Quiet when nothing is running.
FUN
__agents__headless__kill() {
  __agents__headless__kill__pid="$(__agents__headless__pid "$1")"
  if @defined "$__agents__headless__kill__pid"; then
    kill -TERM -- "-$__agents__headless__kill__pid" 2>/dev/null || true
    kill -TERM "$__agents__headless__kill__pid" 2>/dev/null || true
  fi
  : > "$1/cancelled"
}
