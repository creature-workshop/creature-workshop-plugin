#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'MODULE'
API for date/time values, and the duration type: a length of time held as
whole seconds, with the readers that cast one to minutes and hours.
MODULE

@load_types "$SHELLOPS_DIR/lib/time"

:<<'PUB_FUN'
Returns the current UTC date/time as a struct of display-ready fields:
year, month (name), day, day_suffix, hours_24, hours_12, ampm, minutes,
seconds, and timezone.

Usage: date_struct="$(time__get_date)"
PUB_FUN
time__get_date() {
  __time__get_date__year="$(date -u +%Y)"
  __time__get_date__month_name="$(date -u +%B)"
  __time__get_date__day="$(date -u +%-d)"
  __time__get_date__hours_24="$(date -u +%-H)"
  __time__get_date__minutes="$(date -u +%M)"
  __time__get_date__seconds="$(date -u +%S)"

  @obj __time__get_date__out \
    '.year' "$__time__get_date__year" \
    '.month' "$__time__get_date__month_name" \
    '.day' "$__time__get_date__day" \
    '.day_suffix' "$(__time__day_suffix "$__time__get_date__day")" \
    '.hours_24' "$__time__get_date__hours_24" \
    '.hours_12' "$(__time__hours_12 "$__time__get_date__hours_24")" \
    '.ampm' "$(__time__ampm "$__time__get_date__hours_24")" \
    '.minutes' "$__time__get_date__minutes" \
    '.seconds' "$__time__get_date__seconds" \
    '.timezone' "UTC"
  println "$__time__get_date__out"
}

:<<'PUB_FUN'
Returns the current UTC time as an ISO-8601 second-precision timestamp
(2026-08-16T22:03:01Z) -- the machine-readable sibling of time__get_date, for a
value another program reads rather than a human.

Usage: stamp="$(time__utc_timestamp)"
PUB_FUN
time__utc_timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

:<<'PUB_FUN'
Returns the current time as whole seconds since the epoch, for measuring an
elapsed duration by subtraction.

Usage: started="$(time__epoch_seconds)"
PUB_FUN
time__epoch_seconds() {
  date -u +%s
}

:<<'PUB_FUN'
Returns the whole seconds since the epoch of <stamp>, a timestamp another
system reported, so a duration it bounds is arithmetic like any other.
Non-zero when <stamp> is no timestamp, so an unreadable one is never read as
the epoch itself.

  time__epoch_of 2026-09-24T23:36:37Z  ->  1790293

Usage: seconds="$(time__epoch_of "$stamp")"
PUB_FUN
time__epoch_of() {
  @defined "$1" || return 1

  date -u -d "$1" +%s 2>/dev/null
}

:<<'PUB_FUN'
Prints the whole minutes a duration holds, the seconds past the last whole
minute dropped: the cast of a duration to the coarser unit.

  time__duration_minutes "$(@duration 2h30m)"  ->  150
  time__duration_minutes "$(@duration 90s)"    ->  1

Usage: minutes="$(time__duration_minutes "$duration")"
PUB_FUN
time__duration_minutes() {
  println "$(($1 / 60))"
}

:<<'PUB_FUN'
Prints the whole hours a duration holds, the minutes past the last whole
hour dropped.

  time__duration_hours "$(@duration 2h30m)"  ->  2

Usage: hours="$(time__duration_hours "$duration")"
PUB_FUN
time__duration_hours() {
  println "$(($1 / 3600))"
}

:<<'FUN'
Prints the whole seconds a duration stands for, written as counts of hours,
minutes and seconds run together: 2h30m, 45m, 90s, 1h30s. Fails quietly for
anything written another way: a bare count after a unit (2h30), a unit with
no count (h), a unit other than h, m and s (2d), and the empty string. The
duration type reads a shell value through it.

  __time__duration_seconds 2h30m  ->  9000
FUN
__time__duration_seconds() {
  __time__duration_seconds__rest="$1"
  __time__duration_seconds__total=0
  @defined "$__time__duration_seconds__rest" || return 1

  while @defined "$__time__duration_seconds__rest"; do
    __time__duration_seconds__count="${__time__duration_seconds__rest%%[!0-9]*}"
    __time__duration_seconds__rest="${__time__duration_seconds__rest#"$__time__duration_seconds__count"}"
    __time__duration_seconds__unit="${__time__duration_seconds__rest%"${__time__duration_seconds__rest#?}"}"
    __time__duration_seconds__rest="${__time__duration_seconds__rest#?}"
    __time__duration_seconds__part="$(__time__duration_part_seconds \
      "$__time__duration_seconds__count" \
      "$__time__duration_seconds__unit"
    )" || return 1
    __time__duration_seconds__total=$((__time__duration_seconds__total + __time__duration_seconds__part))
  done

  println "$__time__duration_seconds__total"
}

:<<'FUN'
Prints the seconds one part of a duration stands for: <count> of the unit
<unit>, h, m or s. Fails quietly when the count is empty or the unit is
none of the three.

  __time__duration_part_seconds 2 h  ->  7200
FUN
__time__duration_part_seconds() {
  @defined "$1" || return 1
  __time__duration_part_seconds__factor="$(__time__unit_seconds "$2")" || return 1
  println "$(($1 * __time__duration_part_seconds__factor))"
}

:<<'FUN'
Returns the seconds in one of a duration's units: h, m or s. Fails for any
other unit.

  __time__unit_seconds m  ->  60
FUN
__time__unit_seconds() {
  case "$1" in
    h) println 3600 ;;
    m) println 60 ;;
    s) println 1 ;;
    *) return 1 ;;
  esac
}

:<<'PUB_FUN'
Returns the UTC time a number of days before now, as the timestamp
time__utc_timestamp spells, for a window that ends at the present.

  time__utc_timestamp_days_ago 30  ->  2026-08-16T04:19:21Z  (on 2026-09-15T04:19:21Z)

Usage: since="$(time__utc_timestamp_days_ago 30)"
PUB_FUN
time__utc_timestamp_days_ago() {
  __time__utc_timestamp_days_ago__now="$(time__epoch_seconds)"
  __time__utc_timestamp_days_ago__epoch="$((__time__utc_timestamp_days_ago__now - $1 * 86400))"
  date -u -d "@$__time__utc_timestamp_days_ago__epoch" +%Y-%m-%dT%H:%M:%SZ
}

__time__day_suffix() {
  __time__day_suffix__day="$1"

  if [ "$__time__day_suffix__day" -ge 11 ] && [ "$__time__day_suffix__day" -le 13 ]; then
    echo "th"
    return 0
  fi

  case $((__time__day_suffix__day % 10)) in
    1) echo "st" ;;
    2) echo "nd" ;;
    3) echo "rd" ;;
    *) echo "th" ;;
  esac
}

__time__ampm() {
  if [ "$1" -lt 12 ]; then
    echo "AM"
  else
    echo "PM"
  fi
}

__time__hours_12() {
  __time__hours_12__hours="$(($1 % 12))"
  if [ "$__time__hours_12__hours" -eq 0 ]; then
    __time__hours_12__hours=12
  fi

  echo "$__time__hours_12__hours"
}

:<<'PUB_FUN'
Prints the wait after one more failure: twice the wait before it, at most
<cap>. A caller starts from its base interval and feeds each answer back in,
so the waits run base, twice, four times, up to the cap, and it resets to the
base itself once an attempt succeeds.

  time__backoff 120 600   -> 240
  time__backoff 480 600   -> 600

args:
  $1  The wait before this failure, in seconds
  $2  The most to wait, in seconds
PUB_FUN
time__backoff() {
  __time__backoff__next=$(($1 * 2))

  if [ "$__time__backoff__next" -gt "$2" ]; then
    println "$2"
  else
    println "$__time__backoff__next"
  fi
}
