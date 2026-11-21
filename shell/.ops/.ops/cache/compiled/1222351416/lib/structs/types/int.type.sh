#!/bin/sh
# GENERATED FILE. DO NOT EDIT.
# Lowered from lib/structs/types/int.type.op.sh by kinds__lower. Any edit here is lost at the next
# ops compile, and CI refuses the bundle while this file differs from what
# its source lowers to. Edit the source.

:<<'DOC'
The int type: a struct integer, an optional minus sign and digits with no
leading zero but zero itself. Only that spelling is one; a fraction, an
exponent, a space and the empty string are not. The zero value is 0.
lib/structs/type.sh says what the roles mean.

  @int 12   ->  12
  @int -3   ->  -3
  @int 4.5  ->  fails
  @int 007  ->  fails
DOC
int_is() {
  __int_is__digits="${1#-}"
  case "$__int_is__digits" in
    0) return 0 ;;
    ''|0*|*[!0-9]*) return 1 ;;
  esac
  return 0
}

int_from() {
  int_is "$1" || return 1
  println "$1"
}

int_default() {
  printf '0\n'
}
