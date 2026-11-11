#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/versions/_counter.sh"

:<<'DOC'
The counter format: one counter per version, then the tier (ADR.17@global).
lib/versions/_counter.sh says how it spells and moves a name; see
lib/versions/_format.sh for what the roles mean.
DOC
@version_format.counter() {
  @summary() {
    println "One counter per version, then the tier: 3.alpha, and the trunk holds the tier alone."
  }

  @is() {
    versions__counter__is "$1"
  }

  @tier() {
    versions__counter__tier "$1"
  }

  @count() {
    versions__counter__count "$1"
  }

  @name() {
    versions__counter__name "$1" "$2"
  }

  @order() {
    versions__counter__order
  }

  @open() {
    versions__counter__open "$1"
  }

  @bump() {
    versions__counter__bump "$1" "$2"
  }

  @dev() {
    versions__counter__dev "$1" "$2" "$3"
  }

  @tag() {
    versions__counter__tag "$1" "$2"
  }

  @trunk() {
    versions__counter__trunk "$1" "$2"
  }
}
