#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
The record shape, and the two places it is enforced: on write, because a
malformed record is worse than none once the aggregate absorbs it, and on read,
because a record can reach the directory from a CI artifact this code never saw.
FRAGMENT

__testing__metrics__SCHEMA="$SHELLOPS_DIR/schema/testing-metrics.schema.json"

:<<'FUN'
Prints true when <record> satisfies the record schema, false when it does not.
The validator's own errors go to stderr either way.

  $1 record
FUN
__testing__metrics__valid() {
  @succeeds __testing__metrics__valid__out @validate "$1" "$__testing__metrics__SCHEMA"
  println "$__testing__metrics__valid__out"
}

:<<'FUN'
Prints the record at <path>, and returns non-zero without printing when the file
does not parse or the schema rejects it.

  $1 path
FUN
__testing__metrics__read() {
  @load __testing__metrics__read__out "$1" "$__testing__metrics__SCHEMA" 2>/dev/null || return 1
  println "$__testing__metrics__read__out"
}

:<<'FUN'
Writes a record to a file as JSON, and fails without saying so when the
record is not a struct or the file cannot be written.

  $1 record   $2 path
FUN
__testing__metrics__write() {
  @dump __testing__metrics__write__text "$1" 2>/dev/null || return 1
  println "$__testing__metrics__write__text" > "$2" 2>/dev/null
}
