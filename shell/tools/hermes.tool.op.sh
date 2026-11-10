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
    hermes__install "$(@get "$1" '.version' '')" "$(@get "$1" '.commit' '')"
  }

  @uninstall() {
    hermes__uninstall "$(@get "$1" '.version' '')"
  }

  @installed() {
    hermes__installed "$(@get "$1" '.version' '')"
  }
}
