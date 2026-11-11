#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/queue/_priority.sh"

:<<'DOC'
The priority discipline: a person's priority first, then readiness.
lib/queue/_priority.sh says how it orders; see lib/queue/api.sh for what
the roles mean.
DOC
@queue.priority() {
  @summary() {
    println "A person's priority first, then readiness, then the iid."
  }

  @order() {
    queue__priority__order "$1"
  }
}
