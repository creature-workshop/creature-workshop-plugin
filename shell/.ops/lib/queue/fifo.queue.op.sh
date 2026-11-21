#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/queue/_fifo.sh"

:<<'DOC'
The fifo discipline: readiness alone. lib/queue/_fifo.sh says how it
orders; see lib/queue/api.sh for what the roles mean.
DOC
@queue.fifo() {
  @summary() {
    println "Readiness alone: the entry ready first lands first."
  }

  @order() {
    queue__fifo__order "$1"
  }
}
