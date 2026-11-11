#!/bin/sh
# GENERATED FILE. DO NOT EDIT.
# Lowered from lib/structs/types/number.type.op.sh by kinds__lower. Any edit here is lost at the next
# ops compile, and CI refuses the bundle while this file differs from what
# its source lowers to. Edit the source.

:<<'DOC'
The number type: a struct number, an integer as the int type reads one,
with an optional fraction and an optional exponent. Only that spelling is
one; a trailing point, a bare exponent, a space and the empty string are
not. The zero value is 0. The integer part is read with the int type's is,
int_is, so both types are loaded before a number is checked.
lib/structs/type.sh says what the roles mean.

  @number 1.5    ->  1.5
  @number -2e-3  ->  -2e-3
  @number 1.     ->  fails
DOC
number_is() {
  __number_is__mantissa="$1"
  case "$1" in
    *[eE]*)
      __number_is__mantissa="${1%[eE]*}"
      __structs__types__number__is_exponent "${1##*[eE]}" || return 1
      ;;
  esac
  case "$__number_is__mantissa" in
    *.*)
      __structs__types__number__is_digits "${__number_is__mantissa#*.}" || return 1
      __number_is__mantissa="${__number_is__mantissa%%.*}"
      ;;
  esac
  int_is "$__number_is__mantissa"
}

number_from() {
  number_is "$1" || return 1
  println "$1"
}

number_default() {
  printf '0\n'
}

# What follows the e: an optional sign and digits.
__structs__types__number__is_exponent() {
  __structs__types__number__is_digits "${1#[+-]}"
}

# One or more digits, as a fraction or an exponent is made of.
__structs__types__number__is_digits() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac
  return 0
}
