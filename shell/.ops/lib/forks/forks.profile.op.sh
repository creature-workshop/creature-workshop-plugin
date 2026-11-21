#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/forks/api.sh"

:<<'DOC'
The forks profiler: one profile plugin. See lib/profile/api.sh for what the
roles mean.
DOC
@profile.forks() {
  @summary() {
    println "Measures how many subprocesses a command spawns."
  }

  @needs() {
    @arr __profile_forks__out strace
    println "$__profile_forks__out"
  }

  @run() {
    forks__trace "$@"
  }

  @report() {
    forks__table "$1"
  }

  @totals() {
    forks__totals "$1"
  }
}
