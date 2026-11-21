#!/bin/sh

: <<'MODULE'
The trace: which files a test touches, watched at the process level rather
than read from its source, so the answer holds in any language.

  _tracer.sh        runs a command under strace and records what it called
  _observation.sh   reads a trace back as the files, programs and addresses
                    the command touched
  location.sh       where the trace map lives, and the schema it is held to
  map.sh            every test of a file-keyed suite traced on its own, as
                    one map keyed by the commit it ran at
  audit.sh          the map checked against the static selection
MODULE

import \
  "$SHELLOPS_DIR/lib/testing/trace/_tracer.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/_observation.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/location.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/map.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/audit.sh"
