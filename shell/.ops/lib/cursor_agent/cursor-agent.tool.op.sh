#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/cursor_agent/api.sh"

:<<'DOC'
The Cursor CLI as a tool plugin: the version ops.lock pins, fetched into the
tools home with `agent` on the recorded PATH. See lib/toolchain/tool.sh for
what the roles mean and api.sh beside this file for the install itself.
DOC
@tool.cursor-agent() {
  @summary() {
    println "The Cursor CLI, agent, at the version ops.lock pins."
  }

  @install() {
    @get __at1 "$1" '.version' ''
    cursor_agent__install "$__at1"
  }

  @uninstall() {
    @get __at2 "$1" '.version' ''
    cursor_agent__uninstall "$__at2"
  }

  @installed() {
    @get __at3 "$1" '.version' ''
    cursor_agent__installed "$__at3"
  }
}
