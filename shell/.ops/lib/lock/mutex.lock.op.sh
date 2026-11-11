#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/lock/_mutex.sh"

:<<'DOC'
The mutex lock: one holder at a time, a queue's lease as one ref on the
forge. lib/lock/_mutex.sh says how a lease is taken and fenced; see
lib/lock/api.sh for what the roles mean.
DOC
@lock.mutex() {
  @summary() {
    println "One holder at a time: a queue's lease, one ref on the forge, taken by a conditional push."
  }

  @needs() {
    @arr __lock_mutex__out git
    println "$__lock_mutex__out"
  }

  @acquire() {
    lock__mutex__acquire "$1"
  }

  @fence() {
    lock__mutex__fence "$@"
  }
}
