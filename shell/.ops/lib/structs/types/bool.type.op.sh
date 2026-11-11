#!/bin/sh

:<<'DOC'
The bool type: the struct booleans, true and false, and nothing else. The
zero value is false. lib/structs/type.sh says what the roles mean.

  @bool true   ->  true
  @bool yes    ->  fails
  @bool        ->  false
DOC
@type.bool() {
  @is() {
    @is_true "$1" || @is_false "$1"
  }

  @from() {
    @is "$1" || return 1
    println "$1"
  }

  @default() {
    @false __type_bool__out
    println "$__type_bool__out"
  }

  @values() {
    @arr __type_bool__out true false
    println "$__type_bool__out"
  }
}
