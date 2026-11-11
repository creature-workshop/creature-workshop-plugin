#!/bin/sh

: <<'FRAGMENT'
Fixtures for the toolchain domain: a tool's library, lib/<tool>/api.sh under
an owner, laid out the way the script channel finds it and import sources
it (ADR 000038).

A fixture takes the directory it builds into and reads nothing from the
harness running it.
FRAGMENT

: <<'PUB_FUN'
Writes the library of the tool $2 under the owner directory $1 from the
definitions on stdin, so an import of the library through the owner
succeeds. Prints the library's path.

    toolchain__fixture_tool_library "$owner" faketool <<'API'
    faketool__installed() { printf 'false\n'; }
    API
      ->  $owner/lib/faketool/api.sh
PUB_FUN
toolchain__fixture_tool_library() {
  __toolchain__fixture_tool_library__owner="$1"
  __toolchain__fixture_tool_library__api="lib/$2/api.sh"

  mkdir -p "$__toolchain__fixture_tool_library__owner/lib/$2"
  cat > "$__toolchain__fixture_tool_library__owner/$__toolchain__fixture_tool_library__api"

  println "$__toolchain__fixture_tool_library__owner/$__toolchain__fixture_tool_library__api"
}
