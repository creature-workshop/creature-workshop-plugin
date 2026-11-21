#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/versions/_increment.sh"

:<<'DOC'
The increment format: the tier, then a count of its own. lib/versions/_increment.sh
says how it spells and moves a name; see lib/versions/_format.sh for what
the roles mean.
DOC
@version_format.increment() {
  @summary() {
    println "The tier, then a count of its own: dev.9, every tier counting on its own."
  }

  @is() {
    versions__increment__is "$1"
  }

  @tier() {
    versions__increment__tier "$1"
  }

  @count() {
    versions__increment__count "$1"
  }

  @name() {
    versions__increment__name "$1" "$2"
  }

  @order() {
    versions__increment__order
  }

  @open() {
    versions__increment__open "$1"
  }

  @bump() {
    versions__increment__bump "$1" "$2"
  }

  @dev() {
    versions__increment__dev "$1" "$2" "$3"
  }

  @tag() {
    versions__increment__tag "$1" "$2"
  }
}
