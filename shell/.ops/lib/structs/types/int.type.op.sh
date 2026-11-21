#!/bin/sh

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
@type.int() {
  @is() {
    __int_is__digits="${1#-}"
    case "$__int_is__digits" in
      0) return 0 ;;
      ''|0*|*[!0-9]*) return 1 ;;
    esac
    return 0
  }

  @from() {
    @is "$1" || return 1
    println "$1"
  }

  @default() {
    printf '0\n'
  }
}
