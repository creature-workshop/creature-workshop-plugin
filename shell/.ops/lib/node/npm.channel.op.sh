#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/node/api.sh"

: <<'DOC'
Channel plugin for installing npm packages with `npm install --prefix`, one
home per tool (lib/node/packages.sh).

A library package is as much a tool here as a CLI: the channel's probe
answers installed when the pinned version sits under the tool's home, so
`ops install` skips a package that is there and `ops install --check` sees
one that puts nothing on PATH.

Requirements:
  version   package version to install
  pkg       optional npm package name when it differs from the tool name
  bin       optional script inside the package the tool's executable runs;
            given, a shim of the tool's name goes onto PATH
DOC

__node__npm_channel__install() {
  __node__npm_channel__install__tool="$1"
  __node__npm_channel__install__package="$(__node__npm_channel__package "$1" "$2")"
  @get __node__npm_channel__install__version "$2" '.version'
  @get __node__npm_channel__install__bin "$2" '.bin' ''

  node__package_install \
    "$__node__npm_channel__install__tool" \
    "$__node__npm_channel__install__package" \
    "$__node__npm_channel__install__version" \
    || return 1

  if @defined "$__node__npm_channel__install__bin"; then
    node__package_shim \
      "$__node__npm_channel__install__tool" \
      "$__node__npm_channel__install__package" \
      "$__node__npm_channel__install__bin"
  fi
}

__node__npm_channel__uninstall() {
  node__package_uninstall "$1"
}

: <<'FUN'
Prints true when the pinned version of the tool's package is installed.

  __node__npm_channel__installed puppeteer-core '{"version":"25.9.0"}'  ->  true
FUN
__node__npm_channel__installed() {
  @get __node__npm_channel__installed__get_1 "$2" '.version'
  node__package_installed "$1" "$(__node__npm_channel__package "$1" "$2")" "$__node__npm_channel__installed__get_1"
}

: <<'FUN'
Prints the npm package a tool entry installs: its pkg when given, the tool
name otherwise.

  __node__npm_channel__package prettier '{"version":"3.6.2"}'                  ->  prettier
  __node__npm_channel__package tsc '{"version":"5.9.2","pkg":"typescript"}'    ->  typescript
FUN
__node__npm_channel__package() {
  @get __node__npm_channel__package__out "$2" '.pkg' "$1"
  println "$__node__npm_channel__package__out"
}

:<<'DOC'
The npm channel: one channel plugin. See lib/toolchain/channel.sh for what
the roles mean.
DOC
@channel.npm() {
  @summary() {
    println "npm packages, one home per tool, with the npm Node bundles."
  }

  @install_tool() {
    __node__npm_channel__install "$@"
  }

  @uninstall_tool() {
    __node__npm_channel__uninstall "$@"
  }

  @probe() {
    __node__npm_channel__installed "$@"
  }

  @dependency() {
    printf 'node\n'
  }
}
