#!/bin/sh

import "$SHELLOPS_DIR/lib/agents/claude-cli/options.sh"

:<<'FRAGMENT'
What only the Claude Code CLI needs in order to be started: the session id an
agent is, what one run is told, and the headless command line it takes.

The CLI is started in the workspace rather than told where it is, so the run
sees the checkout as its working directory the way a person at a terminal
there would.
FRAGMENT

__agents__claude_cli__ARGV="$SHELLOPS_DIR/lib/agents/claude-cli/argv.awk"
__agents__claude_cli__KERNEL_UUID="/proc/sys/kernel/random/uuid"

:<<'FUN'
Prints a fresh session id, which is an agent's id: uuidgen where it is
installed, else the one the kernel hands out. Fails when neither answers,
since a session the caller cannot name again is a session it cannot follow
up on.
FUN
__agents__claude_cli__session_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
    return 0
  fi
  if [ -r "$__agents__claude_cli__KERNEL_UUID" ]; then
    cat "$__agents__claude_cli__KERNEL_UUID"
    return 0
  fi
  error "claude-cli: no uuidgen and no $__agents__claude_cli__KERNEL_UUID; cannot name a session"
  return 1
}

:<<'FUN'
Opens a session for the run options $1 and prints its id, which is the agent's:
a fresh session id, with the agent's state made under the options' state
directory and the display name $2 recorded in it, so a later listing can name
it. Fails when the machine can name no session.

args:
  $1  The run options
  $2  The agent's display name
FUN
__agents__claude_cli__open_session() {
  __agents__claude_cli__open_session__id="$(__agents__claude_cli__session_id)" || return 1
  agents__headless__new_agent "$__agents__claude_cli__CONTEXT" "$1" "$__agents__claude_cli__open_session__id" "$2"
}

:<<'FUN'
Prints what a run that has started tells its caller: the session as the agent,
the run, and the file the CLI's output is appearing in as the url.

  __agents__claude_cli__started "$options" 4c47 run-1
  ->  {"agent_id":"4c47","run_id":"run-1","url":"/state/4c47/run-1/out"}

args:
  $1  The run options
  $2  The agent id
  $3  The run id
FUN
__agents__claude_cli__started() {
  @obj __agents__claude_cli__started__out \
    '.agent_id' "$2" \
    '.run_id'   "$3" \
    '.url'      "$(agents__headless__run_dir "$__agents__claude_cli__CONTEXT" "$1" "$2" "$3")/out"
  println "$__agents__claude_cli__started__out"
}

:<<'FUN'
Prints what one run is told, which __agents__claude_cli__start and the command line
both read: the session $1 it belongs to and the flag $5 that names that session
on the command line, the run $2 its state goes under, the prompt $3 it is
given, and the key $4 it runs under. The flag is the difference between a run
that opens a session and one that takes up the session already there.

  __agents__claude_cli__new_start 4c47 run-1 "Land the queue" sk-key --session-id
  ->  {"agent":"4c47","run":"run-1","prompt":"Land the queue","key":"sk-key","session_flag":"--session-id"}

args:
  $1  The session the run belongs to, which is the agent's id
  $2  The run id
  $3  The prompt
  $4  The key
  $5  The flag the command line names the session with
FUN
__agents__claude_cli__new_start() {
  @obj __agents__claude_cli__new_start__out \
    '.agent'        "$1" \
    '.run'          "$2" \
    '.prompt'       "$3" \
    '.key'          "$4" \
    '.session_flag' "$5"
  println "$__agents__claude_cli__new_start__out"
}

:<<'FUN'
Starts a run on the options $1, from the start $2, and prints nothing; the
run directory is where its state appears.

args:
  $1  The run options
  $2  The start ({agent, run, prompt, key, session_flag})
FUN
__agents__claude_cli__start() {
  @get __agents__claude_cli__start__agent "$2" '.agent'
  @get __agents__claude_cli__start__id "$2" '.run'
  __agents__claude_cli__start__dir="$(agents__headless__run_dir "$__agents__claude_cli__CONTEXT" "$1" "$__agents__claude_cli__start__agent" "$__agents__claude_cli__start__id")"
  @get __agents__claude_cli__start__get_1 "$2" '.prompt'
  @get __agents__claude_cli__start__get_2 "$2" '.key'
  @obj __agents__claude_cli__start__run \
    '.dir'    "$__agents__claude_cli__start__dir" \
    '.prompt' "$__agents__claude_cli__start__get_1" \
    '.cwd'    "$(agents__headless__workspace "$__agents__claude_cli__CONTEXT" "$1")" \
    '.key'    "$__agents__claude_cli__start__get_2"
  __agents__claude_cli__start__argv="$(__agents__claude_cli__argv "$1" "$2")"
  agents__headless__start "$__agents__claude_cli__CONTEXT" "$__agents__claude_cli__start__run" "$__agents__claude_cli__start__argv"
}

:<<'FUN'
Prints the headless command line the run options $1 take for the start $2, as
an array: the CLI, the flags that make it answer without a terminal, what the
options add, the session the run belongs to, and the prompt last.

The whole line is one pass of argv.awk over the options laid on the defaults
__agents__claude_cli__new_options names, rather than a call per flag: this CLI takes
seven optional flags, and asking the options once costs one read however many
of them a caller named.

  __agents__claude_cli__argv "$options" "$start"
  ->  ["claude","-p","--output-format","text","--permission-mode","bypassPermissions","--bare","--session-id","4c47...","Land the queue"]

args:
  $1  The run options
  $2  The start ({agent, run, prompt, key, session_flag})
FUN
__agents__claude_cli__argv() {
  @run_awk __agents__claude_cli__argv__out "$__agents__claude_cli__ARGV" "$1" \
    --with "$(__agents__claude_cli__new_options)" \
    --with "$2" || return 1
  println "$__agents__claude_cli__argv__out"
}
