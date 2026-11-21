#!/usr/bin/env bash

# Valid range: 1-65535.
@type.port() {
  @is() {
    @int.is "$1" || return 1
    if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
      @throw "port must be 1-65535"
      return 1
    fi
    println "$1"
  }

  @default() {
    println 80
  }
}
