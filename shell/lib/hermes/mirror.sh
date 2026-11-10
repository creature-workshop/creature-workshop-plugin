#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$PROJ/shell/lib/mirror/api.sh"

: <<'MODULE'
The copy of Hermes Agent in the project's mirror (shell/lib/mirror), which CI
installs from instead of from GitHub and the vendor's download hosts.

A copy is one tarball for each pinned version, at
$HERMES_MIRROR_URL/<version>/hermes-<version>.tar.gz. It holds the version's
directory as the vendor installer left it under the Hermes Agent tools home,
without the parts that running `hermes` does not need. The installed tree
holds absolute paths and may use the image's own Python, so a copy only works
when it is unpacked into the same tools home it was packed from, on the same
image; CI sets HERMES_TOOL_HOME to one fixed directory, and both jobs run on
the .shellops image.

HERMES_MIRROR_URL turns the mirror on; a workstation leaves it unset and keeps
the vendor installer. MIRROR_AUTH authorises the requests, as
shell/lib/mirror describes.
MODULE

# CONST: The paths under a version's directory that running `hermes` does not need: the repository's history, the Node packages for the desktop and browser tools, and the download caches.
__hermes__mirror__PRUNE="hermes-agent/.git hermes-agent/node_modules .npm .cache"

: <<'PUB_FUN'
Prints true when HERMES_MIRROR_URL names a mirror, false otherwise.
PUB_FUN
hermes__mirror__configured() {
  @succeeds @defined "${HERMES_MIRROR_URL:-}"
}

: <<'PUB_FUN'
Prints the address of the copy of Hermes Agent version $1.

    hermes__mirror__url 2026.9.24
      ->  https://gitlab.example/api/v4/projects/40/packages/generic/hermes/2026.9.24/hermes-2026.9.24.tar.gz
PUB_FUN
hermes__mirror__url() {
  println "$HERMES_MIRROR_URL/$1/hermes-$1.tar.gz"
}

: <<'PUB_FUN'
Prints true when the mirror holds a copy of Hermes Agent version $1, false
otherwise, including when the mirror cannot be reached.
PUB_FUN
hermes__mirror__has() {
  mirror__has "$(hermes__mirror__url "$1")"
}

: <<'PUB_FUN'
Downloads the copy of Hermes Agent version $1 and unpacks it into the
directory $2, the tools home it was packed from. Fails when the mirror does
not hold it; the plugin/hermes-mirror job uploads it.
PUB_FUN
hermes__mirror__fetch() {
  mirror__fetch_tarball "$(hermes__mirror__url "$1")" "$2"
}

: <<'PUB_FUN'
Removes what running `hermes` does not need from the directory of Hermes Agent
version $1 under the tools home $2, and packs that directory into the tarball
$3.

args:
  $1  The version
  $2  The tools home that holds hermes-<version>
  $3  The tarball to write
PUB_FUN
hermes__mirror__pack() {
  __hermes__mirror__prune "$2/hermes-$1"
  tar -czf "$3" -C "$2" "hermes-$1"
}

: <<'PUB_FUN'
Uploads the tarball $2 as the copy of Hermes Agent version $1.
PUB_FUN
hermes__mirror__upload() {
  mirror__upload "$(hermes__mirror__url "$1")" "$2"
}

: <<'FUN'
Removes each path that __hermes__mirror__PRUNE names from the directory $1.
FUN
__hermes__mirror__prune() {
  for __hermes__mirror__prune__path in $__hermes__mirror__PRUNE; do
    rm -rf "${1:?}/$__hermes__mirror__prune__path"
  done
}
