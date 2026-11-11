#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/terraform/api.sh"

:<<'DOC'
Terraform as a tool plugin: the version ops.lock pins, fetched into the
tools home and checked against HashiCorp's published sum, with `terraform`
on the recorded PATH. See lib/toolchain/tool.sh for what the roles mean and
_install.sh beside this file for the install itself.
DOC
@tool.terraform() {
  @summary() {
    println "Terraform, at the version ops.lock pins, checked against HashiCorp's published sum."
  }

  @install() {
    @get __tool_terraform__get_1 "$1" '.version' ''
    terraform__install "$__tool_terraform__get_1"
  }

  @uninstall() {
    @get __tool_terraform__get_2 "$1" '.version' ''
    terraform__uninstall "$__tool_terraform__get_2"
  }

  @installed() {
    @get __tool_terraform__get_3 "$1" '.version' ''
    terraform__installed "$__tool_terraform__get_3"
  }
}
