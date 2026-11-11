#!/bin/sh

import "$SHELLOPS_DIR/lib/kinds/api.sh"

: <<'MODULE'
Queues: what waits, and in what order, by whichever discipline is named
(ADR.5@scheduler).

A discipline is a plugin of kind queue (lib/kinds/api.sh says how a kind
loads), a file named <name>.queue.op.sh defining @queue.<name>() with these
roles:

  @summary            How the discipline orders, in one line.
  @order <entries>    Prints the struct array <entries> in the order the
                      discipline lands them, the head first. An entry
                      carries .iid, .ready_at (seconds since the epoch when
                      it became ready) and, for a discipline that reads it,
                      .priority. Two entries a discipline scores equal keep
                      a fixed order, so a tick on an unchanged forge orders
                      the same.

The disciplines: fifo, by readiness alone, and priority, a person's
priority first and readiness second (ADR.19@global). Importing this module
loads every discipline under lib/.
MODULE

__queue__ROLES="summary order"
__queue__REQUIRED="summary order"

: <<'PUB_FUN'
Loads and registers the discipline <name>, whose plugin file has been
imported. See kinds__load.
PUB_FUN
queue__load() {
  kinds__load queue "$1" "$__queue__ROLES" "$__queue__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every discipline under <root>. See kinds__scan.
PUB_FUN
queue__load_queues() {
  kinds__scan queue "$1" "$__queue__ROLES" "$__queue__REQUIRED"
}

: <<'PUB_FUN'
Prints the names of every discipline, as a struct array, in load order.
PUB_FUN
queue__names() {
  kinds__names queue
}

: <<'PUB_FUN'
Prints the discipline <name>'s @summary: how it orders, in one line.
PUB_FUN
queue__summary() {
  kinds__call queue "$1" summary
}

: <<'PUB_FUN'
Runs the discipline <name>'s @order: prints <entries> in the order the
discipline lands them, the head first.

Usage: queue__order <name> <entries>
PUB_FUN
queue__order() {
  kinds__call queue "$1" order "$2"
}

queue__load_queues "$SHELLOPS_DIR/lib"
