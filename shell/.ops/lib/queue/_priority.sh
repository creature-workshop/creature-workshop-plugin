#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
The priority discipline: a person's priority first, then readiness, so an
urgent entry goes first whatever its shape and an old one rises rather than
starves (ADR.19@global). Two entries scored equal keep the order of their
iids, so the order is deterministic; a tie a model might break is a step of
its own with its own log, and the scorer's order stands when it does not.
Reached through lib/queue/api.sh as the plugin priority.
FRAGMENT

: <<'PUB_FUN'
Prints <entries> ordered by the highest .priority first, then the earliest
.ready_at, then the lowest .iid. A missing priority or readiness counts as 0.

  queue__priority__order '[{"iid":1,"priority":0,"ready_at":5},{"iid":2,"priority":2,"ready_at":9}]'
  -> [{"iid":2,"priority":2,"ready_at":9},{"iid":1,"priority":0,"ready_at":5}]
PUB_FUN
queue__priority__order() {
  @run_awk __queue__priority__order__out "$SHELLOPS_DIR/lib/queue/priority.awk" "$1" \
    --load "$SHELLOPS_DIR/lib/queue/order.awk" || return 1
  println "$__queue__priority__order__out"
}
