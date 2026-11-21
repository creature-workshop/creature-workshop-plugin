#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/schema.sh"

:<<'FRAGMENT'
Writing the escape check's verdict into the record of the run it judged.

A run's record is written when the run finishes, before the full suite it is
judged against has, so the record cannot carry the verdict then; the escape
check puts it on afterwards, in place. A record without one has no verdict,
and the rollup counts its run as neither clean nor an escape.
FRAGMENT

:<<'PUB_FUN'
Puts <escapes> on the record at <file> as its verdict, and each selector's
own escapes beside it when given, and writes the record back. A record that
cannot be read, that the schema rejects with the verdict on it, or that
cannot be written is left as it was, with a warning: the verdict already
reached the review, and a record without it reads as unjudged rather than
wrong.

  testing__metrics__record_verdict .ops/testing-metrics/20260905T221600Z-31234.json '["test/b.bats"]' '{"areas": [], "trace": ["test/b.bats"]}'

args:
  $1  The record file
  $2  The escapes (struct array of join keys), empty for a clean run
  $3  The escapes per selector ({<id>: [keys]}), optional
PUB_FUN
testing__metrics__record_verdict() {
  __testing__metrics__record_verdict__record="$(__testing__metrics__read "$1")" || {
    warn "testing/metrics: cannot read $1; no verdict written."
    return 0
  }

  @set __testing__metrics__record_verdict__set_1 "$__testing__metrics__record_verdict__record" '.escapes' "$2"
  @patch __testing__metrics__record_verdict__judged \
    "$__testing__metrics__record_verdict__set_1" \
    '.selector_escapes' "${3:-}"
  if ! @is_true "$(__testing__metrics__valid "$__testing__metrics__record_verdict__judged")"; then
    error "testing/metrics: refusing to write a verdict the schema rejects (errors above)."
    return 0
  fi

  if ! __testing__metrics__write "$__testing__metrics__record_verdict__judged" "$1"; then
    warn "testing/metrics: cannot write $1; no verdict written."
    return 0
  fi
  log "testing/metrics: wrote the verdict to $1"
}
