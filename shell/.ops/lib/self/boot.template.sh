#!/bin/sh
set -e

: <<'VAR'
This repository's boot: the hand-off to shellops, whose init installs,
compiles and puts ops on the path. The same in every repository (ADR.21@global),
and written by shellops' init, which rewrites it when its shape changes;
not for hands (ADR 000047). This is the repository's root.
VAR
here="$(cd "$(dirname "$0")/.." && pwd)"
git -C "$here" submodule update --init -- '@@SHELLOPS@@'
exec "$here/@@SHELLOPS@@/init" "$@"
