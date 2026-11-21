#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'MODULE'
Narrowing a nextest run to the packages cargo's selection picked: the whole
workspace is still built, and only the run is filtered. Shared with every
runner that drives its tests through nextest.
MODULE

:<<'FUN'
@map callback: one package name as the nextest filterset term selecting it.

args:
  $1  Package name (wrapped)
FUN
__testing__frameworks__nextest__package_term() {
  @unwrap __testing__frameworks__nextest__package_term__unwrap_1 "$1"
  printf 'package(%s)' "$__testing__frameworks__nextest__package_term__unwrap_1"
}

:<<'FUN'
The nextest filterset selecting the given packages: their package() terms
joined with |.

  __testing__frameworks__nextest__filterset '["alpha","zeta"]'  ->  package(alpha) | package(zeta)

args:
  $1  Package names (struct array)
FUN
__testing__frameworks__nextest__filterset() {
  @map __testing__frameworks__nextest__filterset__map_2 __testing__frameworks__nextest__package_term "$1"
  @join __testing__frameworks__nextest__filterset__out "$__testing__frameworks__nextest__filterset__map_2" ' | '
  println "$__testing__frameworks__nextest__filterset__out"
}

:<<'PUB_FUN'
Prints the arguments narrowing a nextest run to the given packages, one per
line (-E, then the filterset), or nothing for an empty selection, which runs
the whole workspace.

  testing__frameworks__nextest__selection_args '["alpha","zeta"]'  ->  -E
                                                    package(alpha) | package(zeta)

args:
  $1  Package names (struct array)
PUB_FUN
testing__frameworks__nextest__selection_args() {
  if @empty "$1"; then
    return 0
  fi
  printf '%s\n' -E "$(__testing__frameworks__nextest__filterset "$1")"
}
