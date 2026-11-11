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

: <<'PUB_FUN'
Prints the paths of the dependencies the built tree carries a copy of, one
per line, relative to the project root. The tracked tree has each as a
submodule, which Hermes Agent does not install, and the built tree carries
each one's files, including the parts its own .gitignore leaves out.
PUB_FUN
built__vendored() {
  println shell/.ops
}
