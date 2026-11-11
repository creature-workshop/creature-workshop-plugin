#!/usr/bin/env bash

# Passthrough: any value is valid.
@type.string() {
  @is() {
    @encode_string __at_out "$1"
    println "$__at_out"
  }

  @default() {
    println '""'
  }
}
