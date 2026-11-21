#!/bin/sh

:<<'PUB_FUN'
Exits the process when a required value is empty, printing the given message
(or a generic one) to stderr.

Usage: assert_exists "$value" ["$message"]
PUB_FUN
assert_exists() {
  if [ -z "$1" ]; then
    echo "${2:-ERROR: unset variable}" >&2
    exit 1
  fi
}
