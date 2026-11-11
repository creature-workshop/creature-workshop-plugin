#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/linear/intake.sh"

:<<'DOC'
Linear as an intake tracker: one intake plugin, over the Linear intake
library (lib/linear/intake.sh). See lib/intake/api.sh for what the roles
mean.
DOC
@intake.linear() {
  @summary() {
    println "Linear: an Asks email intake per address, with replies synced to the issue."
  }

  @ready() {
    linear__intake__ready
  }

  @input() {
    __linear_input__options="$(linear__intake__options)"
    linear__intake__resolve "$1" "$__linear_input__options"
  }

  @read() {
    __linear_read__options="$(linear__intake__options)"
    linear__intake__get "$1" "$__linear_read__options"
  }

  @drift() {
    linear__intake__drift "$1" "$2"
  }

  @create() {
    __linear_create__options="$(linear__intake__options)"
    __linear_create__made="$(linear__intake__create "$1" "$__linear_create__options")" || return 1
    linear__intake__lock_entry "$__linear_create__made"
  }

  @update() {
    __linear_update__options="$(linear__intake__options)"
    __linear_update__changed="$(linear__intake__update "$1" "$2" "$__linear_update__options")" || return 1
    linear__intake__lock_entry "$__linear_update__changed"
  }

  @entry() {
    linear__intake__lock_entry "$1"
  }
}
