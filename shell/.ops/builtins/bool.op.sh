#!/usr/bin/env bash

@type.bool() {
  @is() {
    case "$1" in
      true|false) printf '%s\n' "$1" ;;
      *) @throw "$1 is not a bool"; return 1 ;;
    esac
  }

  @default() {
    println 'false'
  }
}
