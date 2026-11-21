#!/bin/sh

:<<'FRAGMENT'
Enums: a closed set of words declared once as constants. @enum binds one
constant per member, PREFIX_MEMBER, to the member's word, so the function
that answers one and the case that dispatches on it read the same name, a
plain variable with no subshell behind it; a misspelt reference is unbound
rather than unmatched. @enum_values lists the set, @enum_check holds a word
from outside to it, and @enum_rank says where a word stands in the order the
members were declared in. A declaration runs at import in every process that
loads its module, so it is shell alone and starts no subprocess: its private
helpers hand a result back in a variable named for them, never on stdout.

An enum is a type (type.sh): a declaration registers PREFIX as one, its
from role @enum_check and its values @enum_values, so
kinds__call type PREFIX is <word> asks the set the way it asks any type.
Sourced by api.sh after type.sh, which owns the kind, and the constructor
@enum_values leans on.

  @enum __releases__TIP TAGGED RECORDED UNRELEASED
  case "$(releases__tip_state "$version")" in
    "$__releases__TIP_TAGGED") ... ;;
  esac
FRAGMENT

__structs__enum__UPPER=ABCDEFGHIJKLMNOPQRSTUVWXYZ
__structs__enum__LOWER=abcdefghijklmnopqrstuvwxyz

: <<'CONST'
The newline that joins an enum's words in the variable that keeps them. A
word may hold a space, so a space cannot be the separator; a word never
holds a newline.
CONST
__structs__enum__NL='
'

:<<'PUB_FUN'
Declare the enum PREFIX with the members that follow, binding PREFIX_MEMBER
to each member's word in the calling shell. A member is NAME, an upper-case
identifier whose word is its lower case, or NAME=word for a word of its
own, which may hold spaces when the word comes from outside, such as the
name of a Linear state. Declaring a prefix again with the same members is
harmless; with different ones it fails.

  @enum __pool__TAG FUZZ=fuzz-runner LANDING  ->  __pool__TAG_FUZZ=fuzz-runner, __pool__TAG_LANDING=landing
  @enum __board__STATE IN_REVIEW="In Review"  ->  __board__STATE_IN_REVIEW="In Review"

Usage: @enum <PREFIX> <MEMBER>[=<word>]...
PUB_FUN
@enum() {
  __structs__enum__prefix="$1"
  shift
  if ! __structs__enum__is_identifier "$__structs__enum__prefix" || [ $# -eq 0 ]; then
    error "@enum: a prefix that is an identifier and at least one member are required"
    return 1
  fi
  __structs__enum__words "$@" || return 1
  __structs__enum__declared "$__structs__enum__prefix"
  if [ -n "$__structs__enum__declared__words" ] && [ "$__structs__enum__declared__words" != "$__structs__enum__words__words" ]; then
    __structs__enum__listed "$__structs__enum__declared__words"
    error "@enum: $__structs__enum__prefix is already declared with values: $__structs__enum__listed__words"
    return 1
  fi
  __structs__enum__bind "$__structs__enum__prefix" "$@"
  eval "__structs__ENUM_VALUES__${__structs__enum__prefix}=\$__structs__enum__words__words"
  __structs__enum__declare_type "$__structs__enum__prefix"
}

:<<'FUN'
Registers the enum <prefix> as a type: defines its is, from and values
roles as the plain functions the type kind reads, <prefix>_is holding a
word to the set quietly, <prefix>_from as @enum_check and <prefix>_values
as @enum_values, then registers the name. The definitions are eval in the
calling shell, so a declaration still starts no subprocess.
FUN
__structs__enum__declare_type() {
  eval "${1}_is() { __structs__enum__is $1 \"\$1\"; }
${1}_from() { @enum_check __structs__enum__from__out $1 \"\$1\"; println \"\$__structs__enum__from__out\"; }
${1}_values() { @enum_values __structs__enum__values__out $1; println \"\$__structs__enum__values__out\"; }"
  kinds__register type "$1" "$__structs__roles__REQUIRED"
}

:<<'FUN'
Succeeds quietly when the enum <prefix> holds <word>, fails quietly
otherwise or when no enum was declared under the prefix.
FUN
__structs__enum__is() {
  __structs__enum__declared "$1"
  __structs__enum__holds "$__structs__enum__declared__words" "$2"
}

:<<'PUB_FUN'
Prints the words of the enum PREFIX as a struct array, in declaration
order. Fails naming the prefix when no enum was declared under it.

  @enum_values x __releases__TIP  ->  x=["tagged","recorded","unreleased"]
PUB_FUN
@enum_values() {
  __structs__enum_values__out="$1"
  __structs__answer_to "$__structs__enum_values__out" '' || return 1
  shift
  __structs__enum__declared "$1"
  if [ -z "$__structs__enum__declared__words" ]; then
    error "@enum_values: no enum declared as: $1"
    return 1
  fi
  __structs__enum__values_of "$__structs__enum_values__out" "$__structs__enum__declared__words"
}

:<<'FUN'
Prints the newline-joined <words> as a struct array, one element per word.
The split is on the newline alone, in the calling shell, so a word with a
space stays one element and nothing forks.
FUN
__structs__enum__values_of() {
  __structs__enum__values_of__out="$1"
  __structs__enum__values_of__ifs="$IFS"
  IFS="$__structs__enum__NL"
  # shellcheck disable=SC2086  # a word never holds a newline or a glob character, so the split is exact
  set -- $2
  IFS="$__structs__enum__values_of__ifs"
  @arr "$__structs__enum__values_of__out" "$@"
}

:<<'PUB_FUN'
Prints <word> once the enum PREFIX is known to hold it: the check at a
boundary, where a word arrives from a file, a flag or an API. A word
outside the set fails naming the set.

  @enum_check x __releases__TIP tagged  ->  x=tagged

Usage: @enum_check <result> <PREFIX> <word>
PUB_FUN
@enum_check() {
  __structs__enum_check__out="$1"
  __structs__answer_to "$__structs__enum_check__out" '' || return 1
  shift
  __structs__enum__declared "$1"
  if [ -z "$__structs__enum__declared__words" ]; then
    error "@enum_check: no enum declared as: $1"
    return 1
  fi
  if ! __structs__enum__holds "$__structs__enum__declared__words" "$2"; then
    __structs__enum__listed "$__structs__enum__declared__words"
    error "@enum_check: not a value of $1: $2 (values: $__structs__enum__listed__words)"
    return 1
  fi
  __structs__answer_to "$__structs__enum_check__out" "$2"
}

:<<'PUB_FUN'
Prints the rank of <word> in the enum PREFIX: its place in the order the
members were declared in, the first member ranking 0. An enum whose order
means something, a ladder of tiers or of severities, is compared by rank. A
word is matched whole, so a spelled word with digits, punctuation or spaces
ranks like any other, and a word outside the set fails naming the set.

  @enum_rank x versions__TIER beta  ->  x=2

Usage: @enum_rank <result> <PREFIX> <word>
PUB_FUN
@enum_rank() {
  __structs__enum_rank__out="$1"
  __structs__answer_to "$__structs__enum_rank__out" '' || return 1
  shift
  __structs__enum__declared "$1"
  if [ -z "$__structs__enum__declared__words" ]; then
    error "@enum_rank: no enum declared as: $1"
    return 1
  fi
  __structs__enum__rank_of "$__structs__enum_rank__out" "$1" "$2" "$__structs__enum__declared__words"
}

:<<'FUN'
Prints the rank of <word> among the newline-joined <words> of the enum
<prefix>, the first word ranking 0, and fails naming the prefix and the
words when <word> is not among them.

Usage: __structs__enum__rank_of <prefix> <word> <words>
FUN
__structs__enum__rank_of() {
  __structs__enum__rank_of__out="$1"
  __structs__enum__rank_of__prefix="$2"
  __structs__enum__rank_of__word="$3"
  __structs__enum__rank_of__words="$4"
  __structs__enum__rank_of__ifs="$IFS"
  IFS="$__structs__enum__NL"
  # shellcheck disable=SC2086  # a word never holds a newline or a glob character, so the split is exact
  set -- $4
  IFS="$__structs__enum__rank_of__ifs"
  __structs__enum__rank_of__rank=0
  for __structs__enum__rank_of__each in "$@"; do
    if [ "$__structs__enum__rank_of__each" = "$__structs__enum__rank_of__word" ]; then
      __structs__answer_to "$__structs__enum__rank_of__out" "$__structs__enum__rank_of__rank"
      return 0
    fi
    __structs__enum__rank_of__rank=$((__structs__enum__rank_of__rank + 1))
  done
  __structs__enum__listed "$__structs__enum__rank_of__words"
  error "@enum_rank: not a value of $__structs__enum__rank_of__prefix: $__structs__enum__rank_of__word (values: $__structs__enum__listed__words)"
  return 1
}

:<<'FUN'
Sets __structs__enum__declared__words to the words of the enum <prefix>,
newline-joined in declaration order, or to nothing when no enum was declared
under it.
FUN
__structs__enum__declared() {
  __structs__enum__declared__words=""
  if __structs__enum__is_identifier "$1"; then
    eval "__structs__enum__declared__words=\"\${__structs__ENUM_VALUES__$1:-}\""
  fi
}

:<<'FUN'
Sets __structs__enum__words__words to the words of the members "$@",
newline-joined in order, failing on the first member that is not well
formed.
FUN
__structs__enum__words() {
  __structs__enum__words__words=""
  for __structs__enum__words__member in "$@"; do
    __structs__enum__member "$__structs__enum__words__member" || return 1
    __structs__enum__words__words="$__structs__enum__words__words${__structs__enum__words__words:+$__structs__enum__NL}$__structs__enum__member__word"
  done
}

:<<'FUN'
Sets __structs__enum__listed__words to the newline-joined <words> joined
with a comma and a space instead, the form an error message lists them in,
where a word with a space would otherwise read as two.

  __structs__enum__listed "tagged<newline>recorded"  ->  tagged, recorded
FUN
__structs__enum__listed() {
  __structs__enum__listed__ifs="$IFS"
  IFS="$__structs__enum__NL"
  # shellcheck disable=SC2086  # a word never holds a newline or a glob character, so the split is exact
  set -- $1
  IFS="$__structs__enum__listed__ifs"
  __structs__enum__listed__words=""
  for __structs__enum__listed__each in "$@"; do
    __structs__enum__listed__words="$__structs__enum__listed__words${__structs__enum__listed__words:+, }$__structs__enum__listed__each"
  done
}

:<<'FUN'
Binds <prefix>_NAME to the word of each member that follows, in the calling
shell. The members are already known to be well formed.
FUN
__structs__enum__bind() {
  __structs__enum__bind__prefix="$1"
  shift
  for __structs__enum__bind__member in "$@"; do
    __structs__enum__member "$__structs__enum__bind__member"
    eval "${__structs__enum__bind__prefix}_${__structs__enum__member__name}=\$__structs__enum__member__word"
  done
}

:<<'FUN'
Sets __structs__enum__member__name and __structs__enum__member__word from the
member <spelling>, NAME or NAME=word, the word being the lower-cased name
when none is spelled. Fails naming the member when either part is not well
formed.
FUN
__structs__enum__member() {
  __structs__enum__member__name="${1%%=*}"
  __structs__enum__member__word="${1#*=}"
  if [ "$__structs__enum__member__word" = "$1" ]; then
    __structs__enum__lower "$__structs__enum__member__name"
    __structs__enum__member__word="$__structs__enum__lower__word"
  fi
  __structs__enum__require_name "$__structs__enum__member__name" || return 1
  __structs__enum__require_word "$__structs__enum__member__name" "$__structs__enum__member__word"
}

:<<'FUN'
Succeeds quietly when <name> is an upper-case identifier, the shape of a
member name; fails naming it otherwise.
FUN
__structs__enum__require_name() {
  case "$1" in
    ""|[!A-Z]*|*[!A-Z0-9_]*)
      error "@enum: not a member name: $1 (an upper-case identifier)"
      return 1
      ;;
  esac
  return 0
}

:<<'FUN'
Succeeds quietly when <word> is letters, digits, spaces and _ - . : / + =,
the shape of a member's word; fails naming the member <name> otherwise. A
newline, a tab or a glob character is outside the shape, which is what
keeps the newline-joined list exact.
FUN
__structs__enum__require_word() {
  case "$2" in
    # structs-lint: allow -- the enum's own word shape, which no type spells for it
    ""|*[!A-Za-z0-9_.:/+=' '-]*)
      error "@enum: not a member value for $1: '$2' (letters, digits, spaces and _ - . : / + =)"
      return 1
      ;;
  esac
  return 0
}

:<<'FUN'
Succeeds quietly when the newline-joined <words> hold <word>, matched whole
between two newlines, so a word that is part of another is not it.
FUN
__structs__enum__holds() {
  case "$__structs__enum__NL$1$__structs__enum__NL" in
    *"$__structs__enum__NL$2$__structs__enum__NL"*) return 0 ;;
  esac
  return 1
}

:<<'FUN'
Sets __structs__enum__lower__word to <name> in lower case, one character at a
time, so a default word costs no subprocess.

  __structs__enum__lower FUZZ_RUNNER  ->  fuzz_runner
FUN
__structs__enum__lower() {
  __structs__enum__lower__rest="$1"
  __structs__enum__lower__word=""
  while [ -n "$__structs__enum__lower__rest" ]; do
    __structs__enum__lower_char "${__structs__enum__lower__rest%"${__structs__enum__lower__rest#?}"}"
    __structs__enum__lower__word="$__structs__enum__lower__word$__structs__enum__lower_char__char"
    __structs__enum__lower__rest="${__structs__enum__lower__rest#?}"
  done
}

:<<'FUN'
Sets __structs__enum__lower_char__char to the lower case of the one character
<char>: the letter at the same offset in the lower alphabet as <char> holds in
the upper, or <char> itself when it is not an upper-case letter.
FUN
__structs__enum__lower_char() {
  __structs__enum__lower_char__char="$1"
  __structs__enum__lower_char__before="${__structs__enum__UPPER%%"$1"*}"
  if [ "$__structs__enum__lower_char__before" = "$__structs__enum__UPPER" ]; then
    return 0
  fi
  __structs__enum__lower_char__lower="$__structs__enum__LOWER"
  while [ -n "$__structs__enum__lower_char__before" ]; do
    __structs__enum__lower_char__before="${__structs__enum__lower_char__before#?}"
    __structs__enum__lower_char__lower="${__structs__enum__lower_char__lower#?}"
  done
  __structs__enum__lower_char__char="${__structs__enum__lower_char__lower%"${__structs__enum__lower_char__lower#?}"}"
}

:<<'FUN'
Succeeds quietly when <name> is a shell identifier.
FUN
__structs__enum__is_identifier() {
  case "$1" in
    ""|[0-9]*|*[!A-Za-z0-9_]*) return 1 ;;
  esac
  return 0
}
