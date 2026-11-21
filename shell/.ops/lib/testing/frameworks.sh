#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh"

: <<'MODULE'
Finds and loads every test framework runner.

A runner lives in lib/testing/frameworks/<id>/<id>.runner.op.sh as a
@runner.<id> plugin. Sourcing this file finds them all, imports each one and
loads it under the id its filename carries. Nothing lists the runners
anywhere: to add one, add the file. The files load in sorted path order, so
the registry reads the same on every machine.
MODULE

: <<'PUB_FUN'
Finds every *.runner.op.sh under <root>, imports each and loads the runner it
defines under the id its filename carries, in sorted path order. Fails when a
plugin does not load.

Usage: testing__load_runners <root>
PUB_FUN
testing__load_runners() {
  __testing__load_runners__files="$(
    find "$1" -name '*.runner.op.sh' \
      | LC_ALL=C sort
  )"

  args__call_with_lines __testing__frameworks__load_each "$__testing__load_runners__files"
}

: <<'FUN'
Imports each plugin <file> and loads the runner it defines. Runs in the
importing shell, not a pipeline, so the functions a plugin defines stay
defined.
FUN
__testing__frameworks__load_each() {
  for __testing__frameworks__load_each__file in "$@"; do
    import "$__testing__frameworks__load_each__file" || return 1
    testing__load_runner "$(testing__runner_id_of "$__testing__frameworks__load_each__file")" || return 1
  done
}

: <<'PUB_FUN'
Prints the runner id a plugin <file> carries: its filename without the
directory and without the .runner.op.sh suffix.

    testing__runner_id_of lib/testing/frameworks/nextest/nextest.runner.op.sh  ->  nextest
PUB_FUN
testing__runner_id_of() {
  __testing__runner_id_of__base="${1##*/}"
  println "${__testing__runner_id_of__base%.runner.op.sh}"
}

testing__load_runners "$SHELLOPS_DIR/lib/testing/frameworks"
