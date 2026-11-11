#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
Where a headless run's state lives, and what the run options say about it:
the adaptor's own block of the options, the directory tree
<state>/<agent>/<run>/ underneath, and the ids naming each level of it.
FRAGMENT

:<<'PUB_FUN'
Checks the adaptor's block of the run options $2 against the adaptor's
options schema, failing on a key the adaptor does not understand rather than
dropping it.

args:
  $1  The adaptor's context
  $2  The run options
PUB_FUN
agents__headless__check_options() {
  @get __agents__headless__check_options__id "$1" '.id'
  @get __agents__headless__check_options__schema "$1" '.schema'
  @obj __agents__headless__check_options__obj_1
  @get __agents__headless__check_options__block "$2" ".\"$__agents__headless__check_options__id\"" "$__agents__headless__check_options__obj_1"
  if ! @validate "$__agents__headless__check_options__block" "$__agents__headless__check_options__schema" >/dev/null; then
    error "$__agents__headless__check_options__id: the options' .$__agents__headless__check_options__id block does not fit $__agents__headless__check_options__schema"
    return 1
  fi
}

:<<'PUB_FUN'
Prints the option $3 of the adaptor's own block of the run options $2, or
the default $4 when the block leaves it out.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The option's key
  $4  The default
PUB_FUN
agents__headless__option() {
  @get __agents__headless__option__id "$1" '.id'
  @get __agents__headless__option__out "$2" ".\"$__agents__headless__option__id\".$3" "$4"
  println "$__agents__headless__option__out"
}

:<<'PUB_FUN'
Prints the directory runs keep their state under for the run options $2: the
block's state_dir, else .ops/cache/agents/<id> under the project.

args:
  $1  The adaptor's context
  $2  The run options
PUB_FUN
agents__headless__state_dir() {
  @get __agents__headless__state_dir__get_2 "$1" '.id'
  agents__headless__option "$1" "$2" state_dir "${PROJ:-$PWD}/.ops/cache/agents/$__agents__headless__state_dir__get_2"
}

:<<'PUB_FUN'
Prints the directory the CLI works in for the run options $2: the block's
workspace, else the options' repo when it is a directory on this machine,
else the working directory. A repository URL means nothing to a process that
runs where the checkout already is.

args:
  $1  The adaptor's context
  $2  The run options
PUB_FUN
agents__headless__workspace() {
  __agents__headless__workspace__dir="$(agents__headless__option "$1" "$2" workspace '')"
  if @defined "$__agents__headless__workspace__dir"; then
    println "$__agents__headless__workspace__dir"
    return 0
  fi
  @get __agents__headless__workspace__repo "$2" '.repo' ''
  if [ -d "$__agents__headless__workspace__repo" ]; then
    println "$__agents__headless__workspace__repo"
  else
    println "$PWD"
  fi
}

:<<'PUB_FUN'
Prints the key the run options $2 carry. Fails, naming the adaptor's
variable, when they carry none: the CLI would stop to ask for a login that
nobody is there to give.

args:
  $1  The adaptor's context
  $2  The run options
PUB_FUN
agents__headless__require_key() {
  @get __agents__headless__require_key__key "$2" '.api_key' ''
  if ! @defined "$__agents__headless__require_key__key"; then
    @get __agents__headless__require_key__get_3 "$1" '.id'
    @get __agents__headless__require_key__get_4 "$1" '.token_env'
    error "$__agents__headless__require_key__get_3: no key in the options; set $__agents__headless__require_key__get_4"
    return 1
  fi
  println "$__agents__headless__require_key__key"
}

:<<'PUB_FUN'
Prints the directory of the agent $3 under the run options $2's state.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
PUB_FUN
agents__headless__agent_dir() {
  printf '%s/%s\n' "$(agents__headless__state_dir "$1" "$2")" "$3"
}

:<<'PUB_FUN'
Prints the directory of the run $4 on the agent $3 under the run options
$2's state.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
  $4  The run id
PUB_FUN
agents__headless__run_dir() {
  printf '%s/%s/%s\n' "$(agents__headless__state_dir "$1" "$2")" "$3" "$4"
}

:<<'PUB_FUN'
Prints the id the next run on the agent $3 takes under the run options $2's
state: run-<n>, one past the runs already there.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
PUB_FUN
agents__headless__next_run() {
  agents__headless__next_run_id "$(agents__headless__agent_dir "$1" "$2" "$3")"
}

:<<'FUN'
Prints the directory of the run $4 on the agent $3, failing when no such run
was started.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
  $4  The run id
FUN
__agents__headless__require_run_dir() {
  __agents__headless__require_run_dir__dir="$(agents__headless__run_dir "$1" "$2" "$3" "$4")"
  if [ ! -d "$__agents__headless__require_run_dir__dir" ]; then
    @get __agents__headless__require_run_dir__get_5 "$1" '.id'
    error "$__agents__headless__require_run_dir__get_5: no run $4 on agent $3 under $(agents__headless__state_dir "$1" "$2")"
    return 1
  fi
  println "$__agents__headless__require_run_dir__dir"
}

:<<'PUB_FUN'
Makes the state for the agent $3, records the display name $4 in it, and
prints the agent's id, so a listing can name it later.

args:
  $1  The adaptor's context
  $2  The run options
  $3  The agent id
  $4  The agent's display name
PUB_FUN
agents__headless__new_agent() {
  __agents__headless__new_agent__dir="$(agents__headless__agent_dir "$1" "$2" "$3")"
  mkdir -p "$__agents__headless__new_agent__dir"
  println "$4" > "$__agents__headless__new_agent__dir/name"
  println "$3"
}

:<<'FUN'
Prints the display name recorded for the agent directory $1, nothing when
none was.
FUN
__agents__headless__agent_name() {
  if [ -f "$1/name" ]; then
    cat "$1/name"
  fi
}

:<<'PUB_FUN'
Prints the id the next run on the agent directory $1 takes: run-<n>, one
past the runs already there.

  agents__headless__next_run_id /state/chat-1  ->  run-3
PUB_FUN
agents__headless__next_run_id() {
  __agents__headless__next_run_id__count="$(__agents__headless__run_ids "$1" | wc -l | tr -d ' ')"
  printf 'run-%s\n' "$(( __agents__headless__next_run_id__count + 1 ))"
}

:<<'FUN'
Prints the run ids under the agent directory $1, one per line, newest
first; nothing when it holds none or does not exist.
FUN
__agents__headless__run_ids() {
  if [ ! -d "$1" ]; then
    return 0
  fi
  find "$1" -mindepth 1 -maxdepth 1 -type d -name 'run-*' \
    | sed 's#.*/##' \
    | sort -t - -k 2,2nr
}

:<<'FUN'
Prints the agent ids under the run options $2's state, one per line, newest
first; nothing when there are none.

args:
  $1  The adaptor's context
  $2  The run options
FUN
__agents__headless__agent_ids() {
  __agents__headless__agent_ids__dir="$(agents__headless__state_dir "$1" "$2")"
  if [ ! -d "$__agents__headless__agent_ids__dir" ]; then
    return 0
  fi
  ls -1t "$__agents__headless__agent_ids__dir"
}
