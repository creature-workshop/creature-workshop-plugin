#!/usr/bin/env bash

# Engine masks the value in logs; any string is accepted.
@type.secret() {
  @is() {
    @encode_string __at_out "$1"
    println "$__at_out"
  }

  @default() {
    println '""'
  }
}
