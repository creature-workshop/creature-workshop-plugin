#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/self/boot.sh" \
  "$SHELLOPS_DIR/lib/self/lock/api.sh"

: <<'MODULE'
The seed an owner's OPX ids are drawn from: the doc seed of the two that
are its corpus's identity (ADR.11@strata). The seeds live in the lock,
.ops/lock, which init writes and keeps them in through every rewrite
(ADR 000049); a repository that has not converted still carries them in
its boot, .ops/boot, and the seed is read from there when the lock has none
(ADR 000047). This interim writer draws from the doc seed alone until
Strata reads the header. It speaks in paths and plain shell alone.
MODULE

: <<'PUB_FUN'
Prints a fresh seed: a number drawn from the system's randomness, or the
clock where there is none to draw from.

  opx__seed__mint  ->  2931084477
PUB_FUN
opx__seed__mint() {
  if [ -r /dev/urandom ]; then
    od -An -N4 -tu4 /dev/urandom | tr -d ' '
    return
  fi
  date +%s
}

: <<'PUB_FUN'
Prints PROJ's seed, the doc seed its boot carries, or nothing when PROJ
has no boot or its boot carries none.

  opx__seed__of_owner  ->  2931084477
PUB_FUN
opx__seed__of_owner() {
  __opx__seed__of_owner__seed="$(self__lock__seed doc "$PROJ")"
  if @defined "$__opx__seed__of_owner__seed"; then
    println "$__opx__seed__of_owner__seed"
  else
    self__boot__doc_seed "$PROJ"
  fi
}
