#!/usr/bin/env bash

@type.float() {
  @is() {
    printf '%s' "$1" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$' || {
      @throw "$1 is not a float"
      return 1
    }
    println "$1"
  }

  @default() {
    println 0
  }
}
