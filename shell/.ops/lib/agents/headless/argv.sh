#!/bin/sh

import "$SHELLOPS_DIR/lib/agents/headless/state.sh"

:<<'FRAGMENT'
Growing a CLI's argument list from the run options, one option at a time. An
adaptor starts from the arguments its CLI always takes and hands the list
through a helper per optional flag, so an option that is not set adds
nothing and the order the flags appear in is the order the calls are written
in.

  args="$(@arr "$command" -p)"
  args="$(agents__headless__with_model "$args" "$options")"
FRAGMENT

:<<'PUB_FUN'
Prints the argument list $1 with --model and the run options $2's model
appended, unchanged when the options name none. The model is the neutral
core's, not the adaptor's block: it is the one provider setting every caller
names per run.

args:
  $1  The arguments so far
  $2  The run options
PUB_FUN
agents__headless__with_model() {
  @get __agents__headless__with_model__model "$2" '.model' ''
  if ! @defined "$__agents__headless__with_model__model"; then
    println "$1"
    return 0
  fi
  @wrap __agents__headless__with_model__wrap_1 "$__agents__headless__with_model__model"
  @push __agents__headless__with_model__out "$1" '.' --model "$__agents__headless__with_model__wrap_1"
  println "$__agents__headless__with_model__out"
}

:<<'PUB_FUN'
Prints the argument list $1 with the flag $5 and the value of the adaptor's
option $4 appended, unchanged when the options $3 leave that option out.

args:
  $1  The arguments so far
  $2  The adaptor's context
  $3  The run options
  $4  The option's key
  $5  The flag that carries it
PUB_FUN
agents__headless__with_option() {
  __agents__headless__with_option__value="$(agents__headless__option "$2" "$3" "$4" '')"
  if ! @defined "$__agents__headless__with_option__value"; then
    println "$1"
    return 0
  fi
  @wrap __agents__headless__with_option__wrap_2 "$__agents__headless__with_option__value"
  @push __agents__headless__with_option__out "$1" '.' "$5" "$__agents__headless__with_option__wrap_2"
  println "$__agents__headless__with_option__out"
}

:<<'PUB_FUN'
Prints the argument list $1 with the flag $5 appended when the adaptor's
option $4 is on, unchanged when the options $3 turn it off. An option a
headless run needs is on unless it is asked for off, so the default is true.

args:
  $1  The arguments so far
  $2  The adaptor's context
  $3  The run options
  $4  The option's key
  $5  The flag it turns on
PUB_FUN
agents__headless__with_switch() {
  if ! @is_true "$(agents__headless__option "$2" "$3" "$4" true)"; then
    println "$1"
    return 0
  fi
  @push __agents__headless__with_switch__out "$1" '.' "$5"
  println "$__agents__headless__with_switch__out"
}
