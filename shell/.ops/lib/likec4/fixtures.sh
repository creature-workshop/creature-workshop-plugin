#!/bin/sh

: <<'FRAGMENT'
The on-disk shapes a test of the LikeC4 module needs: a project directory
holding a sample's sources, and a stand-in CLI in a directory a test puts on
its PATH. Paths are given, never read from a harness variable.

The samples sit beside this file: figures.fixture.c4 has one figure view and
one working view, and no_figures.fixture.c4 has a working view alone.
stand_in_cli.fixture.sh says what the stand-in does.
FRAGMENT

__likec4__FIXTURES="$SHELLOPS_DIR/lib/likec4"

: <<'PUB_FUN'
Makes <dir> a LikeC4 project holding the sample <sample> as model.c4. Prints
<dir>.

  likec4__fixture_project "$tmp/figures" figures  ->  $tmp/figures

Usage: likec4__fixture_project <dir> <sample>
PUB_FUN
likec4__fixture_project() {
  mkdir -p "$1"
  cp "$__likec4__FIXTURES/$2.fixture.c4" "$1/model.c4"
  println "$1"
}

: <<'PUB_FUN'
Installs the stand-in LikeC4 CLI as <bin-dir>/likec4, the way ops install
puts a locked tool's executable in a directory on the PATH. Prints <bin-dir>,
which the caller puts on its PATH.

Usage: PATH="$(likec4__fixture_cli "$tmp/bin"):$PATH"
PUB_FUN
likec4__fixture_cli() {
  mkdir -p "$1"
  cp "$__likec4__FIXTURES/stand_in_cli.fixture.sh" "$1/likec4"
  chmod +x "$1/likec4"
  println "$1"
}
