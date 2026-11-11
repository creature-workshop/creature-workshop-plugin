#!/bin/sh

:<<'MODULE'
Names the area/* label of an area, the one fact the label reconcile
(lib/labels/apply.sh) and the label establish (lib/labels/_establish.sh)
share.

Usage:
  import "$SHELLOPS_DIR/lib/labels/_names.sh"

  labels="$(labels__from_areas "$area_names")"
MODULE

:<<'PUB_FUN'
Maps a sorted, unique struct array of area names to the matching area/* label
names.

  area_names ["lib", "cli", ...]

Usage: labels__from_areas "$area_names"
PUB_FUN
labels__from_areas() {
  @map __labels__from_areas__map_1 __labels__names__to_label "$1"
  @unique __labels__from_areas__out "$__labels__from_areas__map_1"
  println "$__labels__from_areas__out"
}

:<<'FUN'
@map callback: one area name (wrapped) to its "area/<name>" label.

  $1 area name (wrapped)
FUN
__labels__names__to_label() {
  @unwrap __labels__names__to_label__unwrap_2 "$1"
  printf 'area/%s' "$__labels__names__to_label__unwrap_2"
}
