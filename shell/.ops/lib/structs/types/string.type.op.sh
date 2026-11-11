#!/bin/sh

:<<'DOC'
The string type: a struct string, a shell value wrapped the way @wrap does,
so its struct spelling is quoted where its shell spelling is bare. Any
shell value makes one; only the wrapped spelling is one. The zero value is
the empty string. lib/structs/type.sh says what the roles mean.

  @string a b            ->  "a b"
  @is_string "$(@wrap x)" ->  succeeds
  @is_string x           ->  fails
  @string                ->  ""
DOC
@type.string() {
  @is() {
    case "$1" in
      \") return 1 ;;
      \"*\") return 0 ;;
    esac
    return 1
  }

  @from() {
    @wrap __type_string__out "$1"
    println "$__type_string__out"
  }

  @default() {
    printf '""\n'
  }
}
