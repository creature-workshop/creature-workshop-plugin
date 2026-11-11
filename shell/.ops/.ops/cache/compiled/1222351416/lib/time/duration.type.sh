#!/bin/sh
# GENERATED FILE. DO NOT EDIT.
# Lowered from lib/time/duration.type.op.sh by kinds__lower. Any edit here is lost at the next
# ops compile, and CI refuses the bundle while this file differs from what
# its source lowers to. Edit the source.

:<<'DOC'
The duration type: a length of time, held as the whole seconds it stands
for, a struct int of zero or more. Seconds are the finest grain the clocks
and the spellings here have; the readers in lib/time/api.sh cast one to
coarser units. A shell value makes one as a count of seconds, 30, or as a
duration written as counts of hours, minutes and seconds run together:
2h30m, 45m, 90s, 1h30s. A bare count after a unit (2h30), a unit with no
count (h), a unit other than h, m and s (2d), a negative number and a
fraction make none. The zero value is 0. lib/structs/type.sh says what the
roles mean.

  @duration 2h30m   ->  9000
  @duration 30      ->  30
  @duration         ->  0
  @duration 2h30    ->  fails
  @is_duration -1   ->  fails
DOC
duration_is() {
  int_is "$1" || return 1
  [ "$1" -ge 0 ]
}

duration_from() {
  if duration_is "$1"; then
    println "$1"
    return 0
  fi
  __time__duration_seconds "$1"
}

duration_default() {
  printf '0\n'
}
