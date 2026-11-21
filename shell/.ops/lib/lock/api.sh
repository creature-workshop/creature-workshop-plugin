#!/bin/sh

import "$SHELLOPS_DIR/lib/kinds/api.sh"

: <<'MODULE'
Locks: what keeps one tick writing to a queue at a time, by whichever
discipline is named.

A lock is a plugin of kind lock (lib/kinds/api.sh says how a kind loads), a
file named <name>.lock.op.sh defining @lock.<name>() with these roles:

  @summary                 What the discipline admits, in one line.
  @acquire <options>       Tries to make the calling tick a holder. Prints
                           the lease as it stands afterwards, with .held true
                           when this tick holds it and false when another
                           does, and fails when the forge could not be asked.
  @fence <lease> <refspec...>
                           Pushes the tick's git writes in one atomic push
                           with its lease, so they land only while the tick
                           still holds it and none lands otherwise. Prints
                           true when they landed, false when the forge
                           refused them, and fails when it could not be asked.

The mutex admits one holder at a time (lib/lock/_mutex.sh); a semaphore
admits a counted number. Importing this module loads every lock under lib/.
MODULE

__lock__ROLES="summary acquire fence"
__lock__REQUIRED="summary acquire fence"

: <<'PUB_FUN'
Loads and registers the lock <name>, whose plugin file has been imported.
See kinds__load.
PUB_FUN
lock__load() {
  kinds__load lock "$1" "$__lock__ROLES" "$__lock__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every lock under <root>. See kinds__scan.
PUB_FUN
lock__load_locks() {
  kinds__scan lock "$1" "$__lock__ROLES" "$__lock__REQUIRED"
}

: <<'PUB_FUN'
Prints the names of every lock, as a struct array, in load order.
PUB_FUN
lock__names() {
  kinds__names lock
}

: <<'PUB_FUN'
Prints the lock <name>'s @summary: what its discipline admits, in one line.
PUB_FUN
lock__summary() {
  kinds__call lock "$1" summary
}

: <<'PUB_FUN'
Runs the lock <name>'s @acquire with <options>: the calling tick tries to become
a holder, and the lease as it stands afterwards is printed.

Usage: lock__acquire <name> <options>
PUB_FUN
lock__acquire() {
  kinds__call lock "$1" acquire "$2"
}

: <<'PUB_FUN'
Runs the lock <name>'s @fence: the tick's git writes, each a <refspec>, are
pushed in one atomic push with <lease>.

Usage: lock__fence <name> <lease> <refspec...>
PUB_FUN
lock__fence() {
  __lock__fence__name="$1"
  shift
  kinds__call lock "$__lock__fence__name" fence "$@"
}

lock__load_locks "$SHELLOPS_DIR/lib"
