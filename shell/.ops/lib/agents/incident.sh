#!/bin/sh

import "$SHELLOPS_DIR/lib/linear/api.sh"

:<<'MODULE'
The incident procedure for a failure nothing else stops on: one Linear ticket
per streak, found by its title, opened by the first failure and, where the
caller asks for it, closed by the first success after it with the span it
covered. An automation that cannot start and a forge whose run comes back red
both go unwatched otherwise; the ticket is how each says so.

  agents__incident_open  OPS "Shepherd: cannot run" "$why" "$linear_options"
  agents__incident_close OPS "Shepherd: cannot run" "$linear_options"
MODULE

:<<'PUB_FUN'
Prints the open issue titled $2 on the team keyed $1, nothing when there is
none.
PUB_FUN
agents__incident_find() {
  linear__find_open_issue_by_title "$2" "$1" "$3"
}

:<<'PUB_FUN'
Opens the incident titled $2 on the team keyed $1 with the body $3, unless
one is already open, and prints the issue either way. A streak of failures
makes one ticket.

Usage: agents__incident_open <team_key> <title> <body> <linear_options>
PUB_FUN
agents__incident_open() {
  __agents__incident_open__existing="$(agents__incident_find "$1" "$2" "$4")" || return 1
  if @defined "$__agents__incident_open__existing"; then
    @get __agents__incident_open__get_1 "$__agents__incident_open__existing" '.identifier'
    log "incident: $__agents__incident_open__get_1 is already open for '$2'"
    println "$__agents__incident_open__existing"
    return 0
  fi
  __agents__incident_open__team="$(__agents__incident__team_id "$1" "$4")" || return 1
  __agents__incident_open__issue="$(linear__create_issue "$__agents__incident_open__team" "$2" "$3" "$4")" || return 1
  @get __agents__incident_open__get_2 "$__agents__incident_open__issue" '.identifier'
  log "incident: opened $__agents__incident_open__get_2 for '$2'"
  println "$__agents__incident_open__issue"
}

:<<'PUB_FUN'
Closes the incident titled $2 on the team keyed $1 when one is open,
commenting the span it covered, and prints it; prints nothing when none is
open.

Usage: agents__incident_close <team_key> <title> <linear_options>
PUB_FUN
agents__incident_close() {
  __agents__incident_close__existing="$(agents__incident_find "$1" "$2" "$3")" || return 1
  if ! @defined "$__agents__incident_close__existing"; then
    return 0
  fi
  @get __agents__incident_close__id "$__agents__incident_close__existing" '.id'
  @get __agents__incident_close__since "$__agents__incident_close__existing" '.createdAt' ''
  __agents__incident_close__done="$(__agents__incident__done_state "$1" "$3")" || return 1
  linear__add_comment "$__agents__incident_close__id" "$(__agents__incident__span_note "$__agents__incident_close__since")" "$3" >/dev/null || return 1
  linear__update_issue_state "$__agents__incident_close__id" "$__agents__incident_close__done" "$3" >/dev/null || return 1
  @get __agents__incident_close__get_3 "$__agents__incident_close__existing" '.identifier'
  log "incident: closed $__agents__incident_close__get_3"
  println "$__agents__incident_close__existing"
}

:<<'FUN'
Prints the closing comment for an incident first seen at $1.

  __agents__incident__span_note 2026-09-10T02:00:00.000Z
  ->  Resolved: a run started at 2026-09-11T02:10:04Z, the first since the failure of 2026-09-10T02:00:00.000Z.
FUN
__agents__incident__span_note() {
  printf 'Resolved: a run started at %s, the first since the failure of %s.\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1"
}

:<<'FUN'
Prints the id of the team keyed $1, failing when the workspace has none.
FUN
__agents__incident__team_id() {
  __agents__incident__team_id__teams="$(linear__list_teams "$2")" || return 1
  @filter __agents__incident__team_id__filter_4 "$__agents__incident__team_id__teams" silt__text_is .key "$1"
  @first __agents__incident__team_id__team "$__agents__incident__team_id__filter_4"
  if ! @defined "$__agents__incident__team_id__team"; then
    error "incident: no Linear team with key '$1'"
    return 1
  fi
  @get __agents__incident__team_id__out "$__agents__incident__team_id__team" '.id'
  println "$__agents__incident__team_id__out"
}

:<<'FUN'
Prints the id of the Done state on the team keyed $1, failing when it has
none.
FUN
__agents__incident__done_state() {
  __agents__incident__done_state__teams="$(linear__list_teams "$2")" || return 1
  __agents__incident__done_state__id="$(linear__find_done_state "$__agents__incident__done_state__teams" "$1")"
  if ! @defined "$__agents__incident__done_state__id"; then
    error "incident: team '$1' has no Done state"
    return 1
  fi
  println "$__agents__incident__done_state__id"
}
