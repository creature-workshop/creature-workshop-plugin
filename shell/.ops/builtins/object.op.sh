#!/usr/bin/env bash

@type.object() {
  @is() {
    @typeof __at_type "$1"
    if [ "$__at_type" != object ]; then
      @throw "'$1' is not a valid JSON object"
      return 1
    fi

    @to_json __at_out "$1"
    println "$__at_out"
  }

  @default() {
    println '{}'
  }
}
