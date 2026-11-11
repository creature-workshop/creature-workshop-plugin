#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/claude_code/api.sh"

:<<'DOC'
The Claude Code CLI as a tool plugin: the version ops.lock pins, installed
into the tools home with `claude` on the recorded PATH. See
lib/toolchain/tool.sh for what the roles mean and api.sh beside this file for
the install itself.
DOC
@tool.claude-code() {
  @summary() {
    println "The Claude Code CLI, claude, at the version ops.lock pins."
  }

  @install() {
    @get __at1 "$1" '.version' ''
    claude_code__install "$__at1"
  }

  @uninstall() {
    @get __at2 "$1" '.version' ''
    claude_code__uninstall "$__at2"
  }

  @installed() {
    @get __at3 "$1" '.version' ''
    claude_code__installed "$__at3"
  }
}
