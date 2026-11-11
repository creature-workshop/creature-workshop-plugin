#!/bin/sh

: <<'FRAGMENT'
Fixtures for the tectonic domain: a LaTeX document, a real file under
fixtures/.
FRAGMENT

: <<'PUB_FUN'
Copies the fixture LaTeX document into directory $1, creating it, and prints
the document's path.
PUB_FUN
tectonic__fixture_source() {
  mkdir -p "$1"
  cp "$SHELLOPS_DIR/lib/tectonic/fixtures/report.tex" "$1/report.tex"
  echo "$1/report.tex"
}
