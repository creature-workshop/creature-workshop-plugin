#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
A mirror in the GitLab generic package registry: files at addresses of the
form <registry>/<package>/<version>/<file>, read and written with curl. The
module knows nothing about what a file holds; a caller such as
shell/lib/hermes/mirror.sh decides the address and the contents.

MIRROR_AUTH, when set, is the header every request sends: "JOB-TOKEN: <token>"
in a CI job, or "PRIVATE-TOKEN: <token>" elsewhere.
MODULE

: <<'PUB_FUN'
Prints true when the mirror holds a file at the address $1, false otherwise,
including when the mirror cannot be reached.
PUB_FUN
mirror__has() {
  @succeeds __mirror__curl -fsS -o /dev/null -I "$1"
}

: <<'PUB_FUN'
Downloads the gzipped tarball at the address $1 and unpacks it into the
directory $2, creating the directory. Fails, naming the address, when the
download fails.
PUB_FUN
mirror__fetch_tarball() {
  log "fetching $1"
  mkdir -p "$2"
  if ! __mirror__curl -fsSL "$1" | tar -xz -C "$2"; then
    error "mirror__fetch_tarball: could not fetch $1"
    return 1
  fi
}

: <<'PUB_FUN'
Uploads the file $2 to the address $1.
PUB_FUN
mirror__upload() {
  log "uploading $2 to $1"
  __mirror__curl -fsS -o /dev/null --upload-file "$2" "$1"
}

: <<'FUN'
Runs curl with the arguments given, sending MIRROR_AUTH as a header when it is
set.
FUN
__mirror__curl() {
  if @defined "${MIRROR_AUTH:-}"; then
    curl -H "$MIRROR_AUTH" "$@"
  else
    curl "$@"
  fi
}
