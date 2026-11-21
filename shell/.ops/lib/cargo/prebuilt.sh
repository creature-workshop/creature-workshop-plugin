#!/bin/sh

import "$SHELLOPS_DIR/lib/http/api.sh"

: <<'MODULE'
A crate's prebuilt binary, installed from the archive its GitHub release
publishes. A tool entry names the archive by a URL template written the
way cargo-binstall writes a pkg-url: `{ version }` stands for the crate
version and `{ target }` for the Rust target triple. The archive is
fetched through http__download, which is where OPS_DOWNLOAD_MIRROR and
GITHUB_TOKEN apply, and the one file in it named after the binary lands in
the bin directory, executable. cargo-binstall never runs: its own HTTP
client refuses a plain http:// mirror, and the archive is the same one it
would fetch.
MODULE

: <<'PUB_FUN'
Prints the archive URL that template $1 names for version $2 and target
$3.

  cargo__prebuilt__url 'https://github.com/o/r/releases/download/v{ version }/t-{ target }.tar.gz' 1.2.3 x86_64-unknown-linux-musl
    ->  https://github.com/o/r/releases/download/v1.2.3/t-x86_64-unknown-linux-musl.tar.gz

args:
  $1  The URL template, with { version } and { target } placeholders
  $2  The crate version
  $3  The target triple
PUB_FUN
cargo__prebuilt__url() {
  println "$1" | sed -e "s|{ version }|$2|g" -e "s|{ target }|$3|g"
}

: <<'PUB_FUN'
Installs the binary <bin> from the release archive at <url> into <bin_dir>:
downloads the archive, unpacks it, and moves the one file named <bin> out of
it, wherever the archive places it, executable. tar reads the compression
off the archive itself, so a .tar.gz, a .tgz and a .tar.xz all unpack; the
last needs xz on the host. Fails when the download fails or the archive
holds no file of that name.

  cargo__prebuilt__install cargo-nextest "$url" /p/.ops/cache/tools/cargo/bin

args:
  $1  The binary's name
  $2  The archive URL
  $3  The directory the binary lands in
PUB_FUN
cargo__prebuilt__install() {
  __cargo__prebuilt__install__bin="$1"
  __cargo__prebuilt__install__url="$2"
  __cargo__prebuilt__install__bin_dir="$3"
  __cargo__prebuilt__install__work="$(mktemp -d)"

  if ! __cargo__prebuilt__fetch_and_unpack "$__cargo__prebuilt__install__url" "$__cargo__prebuilt__install__work"; then
    rm -rf "$__cargo__prebuilt__install__work"
    return 1
  fi

  __cargo__prebuilt__install__found="$(__cargo__prebuilt__find_binary "$__cargo__prebuilt__install__work" "$__cargo__prebuilt__install__bin")"
  if ! @defined "$__cargo__prebuilt__install__found"; then
    error "cargo__prebuilt__install: the archive at $__cargo__prebuilt__install__url holds no file named $__cargo__prebuilt__install__bin"
    rm -rf "$__cargo__prebuilt__install__work"
    return 1
  fi

  mkdir -p "$__cargo__prebuilt__install__bin_dir"
  mv "$__cargo__prebuilt__install__found" "$__cargo__prebuilt__install__bin_dir/$__cargo__prebuilt__install__bin"
  chmod +x "$__cargo__prebuilt__install__bin_dir/$__cargo__prebuilt__install__bin"
  rm -rf "$__cargo__prebuilt__install__work"
}

: <<'FUN'
Downloads the archive at <url> into <work> and unpacks it there, under a
directory of its own so the archive file is never mistaken for a binary.

args:
  $1  The archive URL
  $2  The work directory
FUN
__cargo__prebuilt__fetch_and_unpack() {
  __cargo__prebuilt__fetch_and_unpack__archive="$2/release-archive"
  __cargo__prebuilt__fetch_and_unpack__tree="$2/tree"

  if ! http__download "$1" "$__cargo__prebuilt__fetch_and_unpack__archive"; then
    return 1
  fi

  mkdir -p "$__cargo__prebuilt__fetch_and_unpack__tree"
  tar -xf "$__cargo__prebuilt__fetch_and_unpack__archive" -C "$__cargo__prebuilt__fetch_and_unpack__tree"
}

: <<'FUN'
Prints the path of the first file named <bin> under the unpacked tree in
<work>, nothing when there is none.

args:
  $1  The work directory
  $2  The binary's name
FUN
__cargo__prebuilt__find_binary() {
  find "$1/tree" -type f -name "$2" | head -n 1
}
