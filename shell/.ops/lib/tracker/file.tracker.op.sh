#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/tracker/_file.sh"

:<<'DOC'
The file tracker: a plan kept in a YAML file under the repository.
lib/tracker/_file.sh does the work; see lib/tracker/api.sh for what the
roles mean.
DOC
@tracker.file() {
  @plan() {
    tracker__file__plan "$1"
  }

  @states() {
    tracker__file__states "$1"
  }

  @tickets() {
    tracker__file__tickets "$1" "$2"
  }

  @ticket() {
    tracker__file__ticket "$1" "$2"
  }

  @update() {
    tracker__file__update "$1" "$2" "$3"
  }

  @link() {
    tracker__file__link "$1" "$2" "$3"
  }

  @unlink() {
    tracker__file__unlink "$1" "$2" "$3"
  }

  @create() {
    tracker__file__create "$1" "$2"
  }

  @delete() {
    tracker__file__delete "$1" "$2"
  }
}
