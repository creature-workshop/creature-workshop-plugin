#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/agents/headless/api.sh" \
  "$SHELLOPS_DIR/lib/process/api.sh"

:<<'FRAGMENT'
What only the Cursor CLI needs: the context the headless base runs it under,
the chat an agent is, the headless command line a run takes, and the models
the account has.

The Cursor CLI is told which directory to work in rather than being started
in it, so a run's own working directory is the one the caller already had.
FRAGMENT

__agents__cursor_cli__CONTEXT="$(agents__headless__context cursor-cli CURSOR_API_KEY)"
__agents__cursor_cli__HERE="."
__agents__cursor_cli__NO_MODELS="No models"
__agents__cursor_cli__CREATE_CHAT_POLLS=300

:<<'FUN'
Prints the option $2 of the run options $1's cursor-cli block, or the default
$3 when the block leaves it out.

args:
  $1  The run options
  $2  The option's key
  $3  The default
FUN
__agents__cursor_cli__option() {
  agents__headless__option "$__agents__cursor_cli__CONTEXT" "$1" "$2" "$3"
}

:<<'FUN'
Prints the Cursor CLI executable the run options $1 name, agent by default.
FUN
__agents__cursor_cli__command() {
  __agents__cursor_cli__option "$1" command agent
}

:<<'FUN'
Creates a chat through the CLI with the key $2 and prints its id, which is
the agent's; the agent's directory is created with the name $3 recorded in
it. Fails when the CLI cannot create one.

The CLI prints the id and then keeps a connection open instead of exiting,
so the id on its first line is taken as the chat created and the CLI is
ended; it is handed no stdin either, since it reads that to its end too.

args:
  $1  The run options
  $2  The key
  $3  The agent's display name
FUN
__agents__cursor_cli__create_chat() {
  __agents__cursor_cli__create_chat__command="$(__agents__cursor_cli__command "$1")"
  __agents__cursor_cli__create_chat__id="$(__agents__cursor_cli__created_chat_id "$__agents__cursor_cli__create_chat__command" "$2")" || {
    error "cursor-cli: $__agents__cursor_cli__create_chat__command create-chat could not create a chat"
    return 1
  }
  agents__headless__new_agent "$__agents__cursor_cli__CONTEXT" "$1" "$__agents__cursor_cli__create_chat__id" "$3"
}

:<<'FUN'
Runs the CLI $1's create-chat under the key $2 and prints the first line it
writes, the chat's id, then ends the CLI and whatever it started. Waits for
that line one poll at a time up to __agents__cursor_cli__CREATE_CHAT_POLLS; fails
when the CLI ends without writing one or the polls run out.
  __agents__cursor_cli__created_chat_id agent "$key"  ->  1e7bc390-cc2f-4a16-bd36-f51dc8e84f79
args:
  $1  The CLI command
  $2  The key
FUN
__agents__cursor_cli__created_chat_id() {
  __agents__cursor_cli__created_chat_id__out="$(mktemp)"
  # setsid puts the CLI in its own group, so ending it ends what it started.
  if command -v setsid >/dev/null 2>&1; then
    CURSOR_API_KEY="$2" setsid "$1" create-chat </dev/null >"$__agents__cursor_cli__created_chat_id__out" 2>/dev/null &
  else
    CURSOR_API_KEY="$2" "$1" create-chat </dev/null >"$__agents__cursor_cli__created_chat_id__out" 2>/dev/null &
  fi
  __agents__cursor_cli__created_chat_id__pid="$!"
  __agents__cursor_cli__created_chat_id__polls=0
  while ! @defined "$(__agents__cursor_cli__first_line "$__agents__cursor_cli__created_chat_id__out")" \
    && @is_true "$(process__alive "$__agents__cursor_cli__created_chat_id__pid")" \
    && [ "$__agents__cursor_cli__created_chat_id__polls" -lt "$__agents__cursor_cli__CREATE_CHAT_POLLS" ]; do
    sleep 0.2
    __agents__cursor_cli__created_chat_id__polls=$((__agents__cursor_cli__created_chat_id__polls + 1))
  done
  __agents__cursor_cli__end "$__agents__cursor_cli__created_chat_id__pid"
  __agents__cursor_cli__created_chat_id__id="$(__agents__cursor_cli__first_line "$__agents__cursor_cli__created_chat_id__out")"
  rm -f "$__agents__cursor_cli__created_chat_id__out"
  if ! @defined "$__agents__cursor_cli__created_chat_id__id"; then
    return 1
  fi
  println "$__agents__cursor_cli__created_chat_id__id"
}

:<<'FUN'
Prints the first line of the file $1 once that line is complete, nothing
before, so a line still being written is never read in part.
args:
  $1  A file a process writes lines to
FUN
__agents__cursor_cli__first_line() {
  if [ "$(wc -l < "$1" | tr -d ' ')" -ge 1 ]; then
    head -n 1 "$1"
  fi
}

:<<'FUN'
Ends the process $1 and the group it leads, quietly when it is already gone.
args:
  $1  A process id
FUN
__agents__cursor_cli__end() {
  kill -TERM -- "-$1" 2>/dev/null || true
  kill -TERM "$1" 2>/dev/null || true
}

:<<'FUN'
Starts the run $3 on the agent $2 for the run options $1 with the prompt $4,
under the key $5: the CLI is started headless over the agent's chat in the
workspace, allowed to act when the options say so and on the model they name.
Prints nothing; the run directory is where its state appears.

args:
  $1  The run options
  $2  The agent id
  $3  The run id
  $4  The prompt
  $5  The key
FUN
__agents__cursor_cli__start() {
  @obj __agents__cursor_cli__start__run \
    '.dir'    "$(agents__headless__run_dir "$__agents__cursor_cli__CONTEXT" "$1" "$2" "$3")" \
    '.prompt' "$4" \
    '.cwd'    "$__agents__cursor_cli__HERE" \
    '.key'    "$5"
  agents__headless__start \
    "$__agents__cursor_cli__CONTEXT" \
    "$__agents__cursor_cli__start__run" \
    "$(__agents__cursor_cli__argv "$1" "$2" "$4")"
}

:<<'FUN'
Prints the headless command line the run options $1 take over the chat $2
with the prompt $3, as an array: the CLI, the flags that make it answer
without a terminal, the chat it resumes, and the prompt last.

  __agents__cursor_cli__argv "$options" chat-1 "Land the queue"
  ->  ["agent","-p","--trust","--output-format","text","--workspace","/src","--resume","chat-1","--force","Land the queue"]

args:
  $1  The run options
  $2  The chat the run resumes
  $3  The prompt
FUN
__agents__cursor_cli__argv() {
  __agents__cursor_cli__argv__command="$(__agents__cursor_cli__command "$1")"
  __agents__cursor_cli__argv__workspace="$(agents__headless__workspace "$__agents__cursor_cli__CONTEXT" "$1")"
  @wrap __agents__cursor_cli__argv__wrap_1 "$__agents__cursor_cli__argv__command"
  @wrap __agents__cursor_cli__argv__wrap_2 "$__agents__cursor_cli__argv__workspace"
  @wrap __agents__cursor_cli__argv__wrap_3 "$2"
  @arr __agents__cursor_cli__argv__args \
    "$__agents__cursor_cli__argv__wrap_1" \
    -p --trust --output-format text \
    --workspace "$__agents__cursor_cli__argv__wrap_2" \
    --resume "$__agents__cursor_cli__argv__wrap_3"
  __agents__cursor_cli__argv__args="$(__agents__cursor_cli__with_force "$__agents__cursor_cli__argv__args" "$1")"
  __agents__cursor_cli__argv__args="$(agents__headless__with_model "$__agents__cursor_cli__argv__args" "$1")"
  @wrap __agents__cursor_cli__argv__wrap_4 "$3"
  @push __agents__cursor_cli__argv__out "$__agents__cursor_cli__argv__args" '.' "$__agents__cursor_cli__argv__wrap_4"
  println "$__agents__cursor_cli__argv__out"
}

:<<'FUN'
Prints the argument list $1 with --force appended when the run options $2
leave the CLI free to act, which a headless run needs in order to do
anything.

args:
  $1  The arguments so far
  $2  The run options
FUN
__agents__cursor_cli__with_force() {
  agents__headless__with_switch "$1" "$__agents__cursor_cli__CONTEXT" "$2" force --force
}

:<<'FUN'
Prints the models the CLI lists for the key $2 through the run options $1's
command, as an array of id; empty when the account has none, which the CLI
says in a sentence rather than an empty list.

args:
  $1  The run options
  $2  The key
FUN
__agents__cursor_cli__models() {
  @arr __agents__cursor_cli__models__ids
  __agents__cursor_cli__models__lines="$(CURSOR_API_KEY="$2" "$(__agents__cursor_cli__command "$1")" models)" || return 1
  for __agents__cursor_cli__models__line in $__agents__cursor_cli__models__lines; do
    @obj __agents__cursor_cli__models__obj_5 '.id' "$__agents__cursor_cli__models__line"
    @push __agents__cursor_cli__models__ids "$__agents__cursor_cli__models__ids" "$__agents__cursor_cli__models__obj_5"
  done
  case "$__agents__cursor_cli__models__lines" in
    "$__agents__cursor_cli__NO_MODELS"*) @arr __agents__cursor_cli__models__out; println "$__agents__cursor_cli__models__out" ;;
    *) printf '%s\n' "$__agents__cursor_cli__models__ids" ;;
  esac
}
