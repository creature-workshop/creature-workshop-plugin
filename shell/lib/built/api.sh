#!/bin/sh

: <<'MODULE'
The tree Hermes installs, which shell/actions/hermes/build writes and
shell/actions/hermes/deploy commits on the built branch.
MODULE

: <<'PUB_FUN'
Prints the paths of the files the generators write, one per line, relative to
the project root. The tracked tree ignores them and the built tree carries
them.
PUB_FUN
built__generated() {
  printf '%s\n' plugin.yaml dashboard/manifest.json desktop/plugin.js
}
