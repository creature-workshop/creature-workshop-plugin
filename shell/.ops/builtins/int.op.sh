#!/usr/bin/env bash

@type.int() {
  @is() {
    printf '%s' "$1" | grep -Eq '^-?[0-9]+$' || {
      @throw "$1 is not an integer"
      return 1
    }
    println "$1"
  }

  @default() {
    println 0
  }
}
