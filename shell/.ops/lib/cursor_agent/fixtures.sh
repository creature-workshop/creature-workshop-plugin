#!/bin/sh

: <<'FRAGMENT'
Fixtures for the cursor-agent domain: a package shaped the way Cursor ships
the CLI, one enclosing directory holding the `cursor-agent` executable and
its bundle, as a tarball. The executable is a real script under fixtures/.
FRAGMENT

: <<'PUB_FUN'
Prints the version the fixture executable answers `--version` with.

    cursor_agent__fixture_version  ->  2026.09.15-d2fe57e
PUB_FUN
cursor_agent__fixture_version() {
  "$SHELLOPS_DIR/lib/cursor_agent/fixtures/cursor-agent" --version
}

: <<'PUB_FUN'
Builds the package tarball under directory $1, creating it, and prints the
tarball's path.

    cursor_agent__fixture_package "$tmp"  ->  $tmp/agent-cli-package.tar.gz
PUB_FUN
cursor_agent__fixture_package() {
  mkdir -p "$1/dist-package"
  cp "$SHELLOPS_DIR/lib/cursor_agent/fixtures/cursor-agent" "$1/dist-package/cursor-agent"
  chmod +x "$1/dist-package/cursor-agent"
  printf '// the bundle\n' > "$1/dist-package/1.index.js"

  tar -czf "$1/agent-cli-package.tar.gz" -C "$1" dist-package
  println "$1/agent-cli-package.tar.gz"
}
