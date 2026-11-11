#!/usr/bin/env bash
# shellcheck disable=SC2317  # the tool kind calls the roles; shellcheck cannot see that

import "$PROJ/shell/lib/hermes/api.sh"

: <<'DOC'
Hermes Agent as a tool plugin: the version and commit that
.ops/config/tools.yaml pins, installed into the tools home with `hermes` on the
recorded PATH. shell/lib/hermes/api.sh does the install.
DOC
@tool.hermes() {
  @summary() {
    println "Hermes Agent, hermes, at the commit .ops/config/tools.yaml pins."
  }

  @install() {
    @get __hermes__tool__version "$1" '.version' ''
    @get __hermes__tool__commit "$1" '.commit' ''
    hermes__install "$__hermes__tool__version" "$__hermes__tool__commit"
  }

  @uninstall() {
    @get __hermes__tool__version "$1" '.version' ''
    hermes__uninstall "$__hermes__tool__version"
  }

  @installed() {
    @get __hermes__tool__version "$1" '.version' ''
    hermes__installed "$__hermes__tool__version"
  }
}
