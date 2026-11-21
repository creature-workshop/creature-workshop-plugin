#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/linear/_tracker.sh"

:<<'DOC'
The linear tracker: a Linear team and one of its projects, through Linear's
API. lib/linear/_tracker.sh does the work; see lib/tracker/api.sh for what
the roles mean.
DOC
@tracker.linear() {
  @plan() {
    linear__tracker__plan "$1"
  }

  @states() {
    linear__tracker__states "$1"
  }

  @tickets() {
    linear__tracker__tickets "$1" "$2"
  }

  @ticket() {
    linear__tracker__ticket "$1" "$2"
  }

  @update() {
    linear__tracker__update "$1" "$2" "$3"
  }

  @link() {
    linear__tracker__link "$1" "$2" "$3"
  }

  @unlink() {
    linear__tracker__unlink "$1" "$2" "$3"
  }

  @create() {
    linear__tracker__create "$1" "$2"
  }

  @delete() {
    linear__tracker__delete "$1" "$2"
  }
}
