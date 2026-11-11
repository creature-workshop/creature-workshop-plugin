#!/bin/sh

:<<'MODULE'
Operating-system path helpers: what exists on disk, and where.
MODULE

:<<'PUB_FUN'
Prints the nearest existing directory at or above <path>, so a path that is not
on disk yet resolves to a real ancestor a command can run in. An existing
directory prints as itself, a path with no existing ancestor short of the root
prints /, and an empty path prints nothing.

  os__existing_dir /repo/new/deeper/file.txt   # -> /repo, when only /repo exists

Usage: os__existing_dir <path>
PUB_FUN
os__existing_dir() {
  __os__existing_dir__dir="$1"
  while [ -n "$__os__existing_dir__dir" ] \
    && [ "$__os__existing_dir__dir" != / ] \
    && [ ! -d "$__os__existing_dir__dir" ]; do
    __os__existing_dir__dir="$(dirname -- "$__os__existing_dir__dir")"
  done
  println "$__os__existing_dir__dir"
}
