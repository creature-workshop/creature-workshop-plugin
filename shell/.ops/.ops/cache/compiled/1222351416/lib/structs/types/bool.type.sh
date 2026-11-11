#!/bin/sh
# GENERATED FILE. DO NOT EDIT.
# Lowered from lib/structs/types/bool.type.op.sh by kinds__lower. Any edit here is lost at the next
# ops compile, and CI refuses the bundle while this file differs from what
# its source lowers to. Edit the source.

:<<'DOC'
The bool type: the struct booleans, true and false, and nothing else. The
zero value is false. lib/structs/type.sh says what the roles mean.

  @bool true   ->  true
  @bool yes    ->  fails
  @bool        ->  false
DOC
bool_is() {
  @is_true "$1" || @is_false "$1"
}

bool_from() {
  bool_is "$1" || return 1
  println "$1"
}

bool_default() {
  @false __type_bool__out
  println "$__type_bool__out"
}

bool_values() {
  @arr __type_bool__out true false
  println "$__type_bool__out"
}
