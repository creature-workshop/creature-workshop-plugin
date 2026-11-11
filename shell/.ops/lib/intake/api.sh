#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/self/config.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The intake kind: the issue tracker that turns a mail to one of the
repository's public addresses into an issue. A tracker is a plugin of kind
intake (lib/kinds/api.sh says how a kind loads), a file named
<name>.intake.op.sh under lib/, beside the library it runs, defining
@intake.<name>() with these roles:

  @summary                   What the tracker is, in one line.
  @ready                     Succeeds quietly when the tracker can be
                             asked; otherwise says what is missing, a key
                             usually, and returns 1.
  @input <declared>          What the tracker takes for a declared intake,
                             its team and template resolved; fails naming
                             what the tracker does not have.
  @read <id>                 The intake as the tracker holds it; fails when
                             it holds none with that id.
  @drift <existing> <input>  Prints true when the intake the tracker holds
                             differs from the input, false when it matches.
  @create <input>            Makes the intake and prints its entry: its id
                             and the address the tracker generated for it.
  @update <id> <input>       Changes the intake and prints its entry.
  @entry <existing>          The entry for an intake as read.

linear is the first tracker, lib/linear/linear.intake.op.sh. A repository
declares its intakes once, each with the tracker that holds it; the file's
own system is the default for an intake that names none:

  .ops/config/intake.yaml:
    system: linear
    intakes:
      - address: docs@example.com
        team: ASK
        template: Docs feedback
        replies: true
      - address: support@example.com
        system: linear
        team: ASK

intake__system is the file's default tracker, linear when it names none;
intake__declared is the list; intake__systems every tracker the list
names. Nothing is resolved at import: a caller names the tracker in every
call, as it does for any other kind.

usage:
  import "$SHELLOPS_DIR/lib/intake/api.sh"
  intake__ready linear || exit 1
  intake__read linear "$id"
MODULE

# CONST: The tracker used when the declaration names none.
__intake__DEFAULT_SYSTEM="linear"

# CONST: The roles the kind knows.
__intake__ROLES="summary ready input read drift create update entry"

# CONST: The roles a tracker must answer.
__intake__REQUIRED="ready input read drift create update entry"

: <<'PUB_FUN'
Prints the tracker the repository's intake declaration names under system,
lowercased, or the module default when it names none. Fails, naming the
trackers there are, when it is not a loaded tracker.

    intake__system  ->  linear

usage: intake__system
PUB_FUN
intake__system() {
  __intake__system__declared="$(self__config__get intake '.system' "$__intake__DEFAULT_SYSTEM")" || return 1
  __intake__system__name="$(println "$__intake__system__declared" | tr '[:upper:]' '[:lower:]')"
  kinds__require_known intake "$__intake__system__name" || return 1
  println "$__intake__system__name"
}

: <<'PUB_FUN'
Prints the intakes the repository declares, the list under intakes of its
intake declaration, as a struct array, or the empty array when it declares
none.

usage: intake__declared
PUB_FUN
intake__declared() {
  @arr __intake__declared__arr_1
  self__config__get intake '.intakes' "$__intake__declared__arr_1"
}

: <<'PUB_FUN'
Prints every tracker the declared intakes are on, as a struct array of
lowercased names, each once: the default <default> for those that name
none, and what the others name under system.

    intake__systems linear  ->  ["linear"]

usage: intake__systems <default>
PUB_FUN
intake__systems() {
  @map __intake__systems__named __intake__system_of "$(intake__declared)" "$1"
  @push __intake__systems__push_2 "$__intake__systems__named" "$1"
  @unique __intake__systems__out "$__intake__systems__push_2"
  println "$__intake__systems__out"
}

: <<'FUN'
@map callback: prints the tracker the wrapped declared intake names under
system, lowercased, or <default> when it names none.

args:
  $1  The declared intake
  $2  The default tracker
FUN
__intake__system_of() {
  @get __intake__system_of__out "$1" '.system' "$2"
  println "$__intake__system_of__out" | tr '[:upper:]' '[:lower:]'
}

: <<'PUB_FUN'
Prints the names of every loaded tracker, as a struct array, in load order.

usage: intake__names
PUB_FUN
intake__names() {
  kinds__names intake
}

: <<'PUB_FUN'
Prints the tracker <tracker>'s @summary.

usage: intake__summary <tracker>
PUB_FUN
intake__summary() {
  kinds__call intake "$1" summary
}

: <<'PUB_FUN'
Succeeds quietly when the tracker <tracker> can be asked; otherwise says
what is missing and returns 1.

usage: intake__ready <tracker> || exit 1
PUB_FUN
intake__ready() {
  kinds__call intake "$1" ready
}

: <<'PUB_FUN'
Prints what the tracker <tracker> takes for the declared intake <declared>.

usage: intake__input <tracker> <declared>
PUB_FUN
intake__input() {
  kinds__call intake "$1" input "$2"
}

: <<'PUB_FUN'
Prints the intake with the id <id> as the tracker <tracker> holds it.

usage: intake__read <tracker> <id>
PUB_FUN
intake__read() {
  kinds__call intake "$1" read "$2"
}

: <<'PUB_FUN'
Prints true when the intake <existing>, as the tracker <tracker> holds it,
differs from <input>, and false when it matches.

usage: intake__drift <tracker> <existing> <input>
PUB_FUN
intake__drift() {
  kinds__call intake "$1" drift "$2" "$3"
}

: <<'PUB_FUN'
Makes an intake from <input> on the tracker <tracker> and prints its entry.

usage: intake__create <tracker> <input>
PUB_FUN
intake__create() {
  kinds__call intake "$1" create "$2"
}

: <<'PUB_FUN'
Changes the intake with the id <id> on the tracker <tracker> to <input> and
prints its entry.

usage: intake__update <tracker> <id> <input>
PUB_FUN
intake__update() {
  kinds__call intake "$1" update "$2" "$3"
}

: <<'PUB_FUN'
Prints the entry the lock keeps for the intake <existing>, as the tracker
<tracker> reads it.

usage: intake__entry <tracker> <existing>
PUB_FUN
intake__entry() {
  kinds__call intake "$1" entry "$2"
}

kinds__scan intake "$SHELLOPS_DIR/lib" "$__intake__ROLES" "$__intake__REQUIRED"
