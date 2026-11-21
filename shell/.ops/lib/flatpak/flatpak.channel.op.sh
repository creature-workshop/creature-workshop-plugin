#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/flatpak/api.sh"

: <<'DOC'
Channel plugin for Flathub applications, installed with `flatpak install
--user` into the user's own installation (lib/flatpak/api.sh). A tool of
the channel is named by its application id, and its launcher of that name
goes on PATH through the installation's exports directory.

Every tool of the channel needs flatpak, which the system channel provides.

Requirements:
  version   the application version the install must end at; Flathub serves
            its current build, and the install fails when that is another
            version
  commit    optional, the commit to install, which holds an older build
DOC

: <<'FUN'
Installs the application $1 at the version its requirements $2 pin, and at
their commit when they name one.
FUN
__flatpak__channel__install() {
  @get __flatpak__channel__install__get_1 "$2" '.version'
  @get __flatpak__channel__install__get_2 "$2" '.commit' ''
  flatpak__install "$1" "$__flatpak__channel__install__get_1" "$__flatpak__channel__install__get_2"
}

: <<'FUN'
Removes the application $1.
FUN
__flatpak__channel__uninstall() {
  flatpak__uninstall "$1"
}

: <<'FUN'
Prints true when the application $1 is installed at the version its
requirements $2 pin.

  __flatpak__channel__installed no.mifi.losslesscut '{"version":"3.69.0"}'  ->  true
FUN
__flatpak__channel__installed() {
  @get __flatpak__channel__installed__get_3 "$2" '.version'
  flatpak__installed "$1" "$__flatpak__channel__installed__get_3"
}

:<<'DOC'
The flatpak channel: one channel plugin. See lib/toolchain/channel.sh for
what the roles mean.
DOC
@channel.flatpak() {
  @summary() {
    println "Flathub applications, in the user's own Flatpak installation."
  }

  @install_tool() {
    __flatpak__channel__install "$@"
  }

  @uninstall_tool() {
    __flatpak__channel__uninstall "$@"
  }

  @probe() {
    __flatpak__channel__installed "$@"
  }

  @dependency() {
    printf 'flatpak\n'
  }

  @dependency_default() {
    @obj __channel_flatpak__out '.channel' system '.version' latest
    println "$__channel_flatpak__out"
  }
}
