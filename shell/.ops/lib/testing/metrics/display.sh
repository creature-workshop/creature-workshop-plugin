#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
The one spelling of the rollout numbers, shared by the terminal report and the
summary comment so the two cannot disagree about what "n/a" means.

Arithmetic stays in integers: tenths of a percent and whole minutes are all the
precision any of this deserves.
FRAGMENT

:<<'PUB_FUN'
A selected-of-total ratio as a percentage to one decimal place, or "n/a" when
nothing was counted.

  $1 selected count   $2 total count

Usage: testing__metrics__ratio_display "$selected" "$total"
PUB_FUN
testing__metrics__ratio_display() {
  if ! @defined "$1" || ! @defined "$2" || [ "$2" -eq 0 ]; then
    printf 'n/a\n'
    return 0
  fi

  __testing__metrics__ratio_display__tenths=$(( $1 * 1000 / $2 ))
  printf '%s.%s%%\n' \
    "$((__testing__metrics__ratio_display__tenths / 10))" \
    "$((__testing__metrics__ratio_display__tenths % 10))"
}

:<<'PUB_FUN'
A second count as whole minutes, or "n/a" when there is no count.

  $1 seconds

Usage: testing__metrics__minutes_display "$seconds"
PUB_FUN
testing__metrics__minutes_display() {
  if ! @defined "$1"; then
    printf 'n/a\n'
    return 0
  fi
  printf '%sm\n' "$(( ($1 + 30) / 60 ))"
}

:<<'PUB_FUN'
The confidence line: the streak of test runs without escaped failures, against
the gate's threshold, and what the streak runs from: the last escape, or none
recorded. Runs that widen to the full suite are filtered from the streak, so
the count names the narrowed and inert runs.

  testing__metrics__streak_display 16 2026-09-05T22:16:00Z 20
  ->  16 of 20 narrowed & inert runs in a row without missed failures since the escape at 2026-09-05T22:16:00Z

  testing__metrics__streak_display 3 "" 20
  ->  3 of 20 narrowed & inert runs in a row without missed failures, no escape recorded

  $1 clean streak   $2 last escape's start time, or nothing   $3 the gate's count

Usage: testing__metrics__streak_display "$streak" "$last_escape_at" "$goal"
PUB_FUN
testing__metrics__streak_display() {
  __testing__metrics__streak_display__count="$1 of $3 narrowed & inert runs in a row without missed failures"
  if ! @defined "$2" || [ "$2" = null ]; then
    printf '%s, no escape recorded\n' "$__testing__metrics__streak_display__count"
    return 0
  fi
  printf '%s since the escape at %s\n' "$__testing__metrics__streak_display__count" "$2"
}
