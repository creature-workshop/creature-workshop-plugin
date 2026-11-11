#!/bin/sh

:<<'DOC'
The regex type: a POSIX extended regular expression as a struct string, one
that grep -E compiles. Any expression that compiles makes one; one that
does not, such as an unclosed group, is refused. A regex has no zero value,
so the constructor with no argument refuses. lib/regex/api.sh composes one
from parts; lib/structs/type.sh says what the roles mean.

  @regex '[0-9]+'             ->  "[0-9]+"
  @regex '('                  ->  fails
  @is_regex "$(@wrap 'a|b')"  ->  succeeds
  @is_regex 'a|b'             ->  fails
DOC
@type.regex() {
  @is() {
    string_is "$1" || return 1
    @unwrap __regex_is__expression "$1"
    @is_true "$(regex__is_valid "$__regex_is__expression")"
  }

  @from() {
    @is_true "$(regex__is_valid "$1")" || return 1
    @wrap __type_regex__out "$1"
    println "$__type_regex__out"
  }
}
