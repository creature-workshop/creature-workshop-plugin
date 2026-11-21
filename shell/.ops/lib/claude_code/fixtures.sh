#!/bin/sh

: <<'FRAGMENT'
Fixtures for the claude-code domain: an npm that installs the package the way
the real one does, the platform binary at bin/claude.exe under the prefix's
node_modules. Both the npm and the binary are real scripts under fixtures/.
FRAGMENT

: <<'PUB_FUN'
Prints the version the fixture binary answers `--version` with.

    claude_code__fixture_version  ->  2.1.274
PUB_FUN
claude_code__fixture_version() {
  "$SHELLOPS_DIR/lib/claude_code/fixtures/claude.exe" --version | cut -d' ' -f1
}

: <<'PUB_FUN'
Lays the fixture npm out under directory $1, creating it, and prints the bin
directory a test puts on PATH so the install runs that npm. The binary the
npm installs sits in a package directory beside that bin, where the npm
looks for it.

    claude_code__fixture_npm "$tmp"  ->  $tmp/bin
PUB_FUN
claude_code__fixture_npm() {
  mkdir -p "$1/bin" "$1/package"
  cp "$SHELLOPS_DIR/lib/claude_code/fixtures/npm" "$1/bin/npm"
  cp "$SHELLOPS_DIR/lib/claude_code/fixtures/claude.exe" "$1/package/claude.exe"
  chmod +x "$1/bin/npm" "$1/package/claude.exe"

  println "$1/bin"
}
