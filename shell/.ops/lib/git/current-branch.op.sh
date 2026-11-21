#!/usr/bin/env bash

# Report the current git branch.
@operation.current-branch() {
  @out.string branch

  @do() {
    branch=$(git rev-parse --abbrev-ref HEAD)
    @out.string branch "$branch"
    @return.out
  }
}
