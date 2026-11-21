#!/usr/bin/env bash

# Matches lib/versions/api.sh's pattern; prerelease allowed.
@type.semver() {
  @is() {
    printf '%s' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z]+(\.[0-9]+)?)?$' || {
      @throw "'$1' is not valid semver"
      return 1
    }
    println "\"$1\""
  }
}
