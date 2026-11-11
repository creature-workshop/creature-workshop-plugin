#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
The fifo discipline: readiness alone, the entry ready first landing first,
and two ready in the same second in the order of their iids. Reached
through lib/queue/api.sh as the plugin fifo.
FRAGMENT

: <<'PUB_FUN'
Prints <entries> ordered by the earliest .ready_at first, then the lowest
.iid. A missing readiness counts as 0.

  queue__fifo__order '[{"iid":2,"ready_at":9},{"iid":1,"ready_at":5}]'
  -> [{"iid":1,"ready_at":5},{"iid":2,"ready_at":9}]
PUB_FUN
queue__fifo__order() {
  @run_awk __queue__fifo__order__out "$SHELLOPS_DIR/lib/queue/fifo.awk" "$1" \
    --load "$SHELLOPS_DIR/lib/queue/order.awk" || return 1
  println "$__queue__fifo__order__out"
}
