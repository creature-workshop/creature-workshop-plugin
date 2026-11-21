#!/bin/sh

: <<'FRAGMENT'
The SILT backend: the structs verbs run on strata's SILT library, in the
calling shell (ADR 000048).

api.sh imports this fragment with SILT's verbs present already: the boot
sources strata's library before the structs library loads
(lib/self/structs.sh). A path is keys and list indexes, and a verb refuses
one that is anything else.

What a value looks like under this backend:

  a map or a list   a SILT document, one node per line
  a scalar          its JSON spelling: "text", 3, true, null

A scalar keeps its JSON spelling because that is what a SILT leaf holds
after its "=", and what every caller compares against. A verb reads a
value in any argument as SILT, as SILT on one line, or as JSON, so a
value read from a file or a forge needs no translating by its caller.
Reading JSON that holds a map or a list starts one awk. The verbs that
strata itself runs in awk, among them @unique, @keys, @merge and
@validate, start one too. Every other verb runs in the calling shell.

  @obj x .name bats       ->  x=0."name":str="bats"
  @get x "$doc" .name     ->  x=bats
  @typeof x "$doc" .name  ->  x=string
FRAGMENT

# CONST: What is left of the path __structs__silt__plain_path is reading, which its segment helpers consume.
__structs__silt__PATH_REST=""


: <<'FUN'
Sets __structs__silt__as_json__text to <text> as a tool that reads JSON
reads it: a SILT document translated to one line of JSON, and anything
else as written.

  __structs__silt__as_json '0."a":int=1'  ->  {"a":1}
FUN
__structs__silt__as_json() {
  __structs__silt__as_json__text="$1"
  __structs__silt__is_document "$1"
  if [ "$__structs__RESULT" != true ]; then
    return 0
  fi
  if ! silt__read __structs__silt__as_json__doc "$1"; then
    return 0
  fi
  silt__to_json __structs__silt__as_json__text "$__structs__silt__as_json__doc"
}

: <<'FUN'
Prints true when <text> opens as a SILT line, digits and a dot followed
by a quote, a colon, or digits and a colon, and false otherwise. A JSON
value never opens so: the number 0.5 has no colon after its digits.

  __structs__silt__is_document '0."a":int=1'  ->  true
  __structs__silt__is_document '{"a":1}'      ->  false
FUN
__structs__silt__is_document() {
  __structs__silt__is_document__rest="${1#"${1%%[!0-9]*}"}"
  if [ "$__structs__silt__is_document__rest" = "$1" ]; then
    __structs__RESULT=false
    return 0
  fi
  case "$__structs__silt__is_document__rest" in
    '."'* | '.:'*)
      __structs__RESULT=true
      ;;
    .[0-9]*)
      __structs__silt__is_document__index "$__structs__silt__is_document__rest"
      ;;
    *)
      __structs__RESULT=false
      ;;
  esac
}

: <<'FUN'
Prints true when <rest>, a dot and digits onward, is a list member's
line: the digits are followed by a colon, as in .0:int=1. Prints false
for a number's fraction, as in .5.
FUN
__structs__silt__is_document__index() {
  __structs__silt__is_document__index__after="${1#.}"
  __structs__silt__is_document__index__after="${__structs__silt__is_document__index__after#"${__structs__silt__is_document__index__after%%[!0-9]*}"}"
  case "$__structs__silt__is_document__index__after" in
    :*) __structs__RESULT=true ;;
    *) __structs__RESULT=false ;;
  esac
}

: <<'FUN'
Keeps the caller's IFS aside before a split: what it held, and whether it
was set at all, since a caller may have unset it to split on the shell's
default characters. __structs__silt__give_back_ifs puts it back. No
callback runs between the two, so one pair of registers serves.
FUN
__structs__silt__keep_ifs() {
  __structs__silt__IFS_WAS="${IFS+set}"
  __structs__silt__IFS_VALUE="${IFS-}"
}

: <<'FUN'
Puts the caller's IFS back as __structs__silt__keep_ifs found it, unset
when it was unset.
FUN
__structs__silt__give_back_ifs() {
  if [ "$__structs__silt__IFS_WAS" = set ]; then
    IFS="$__structs__silt__IFS_VALUE"
  else
    unset IFS
  fi
}

: <<'FUN'
Sets __structs__silt__read__doc to the document the struct <value>
spells. Fails, naming the verb <who>, when <value> is no struct.

Usage: __structs__silt__read "@sum" "$value" || return 1
FUN
__structs__silt__read() {
  if ! silt__read __structs__silt__read__doc "$2"; then
    fatal "$1: not a struct: $2"
    return 1
  fi
}

: <<'FUN'
Sets __structs__silt__value__doc to the document an argument of @set or
@push stands for: the value it spells when it is SILT or JSON, and a str
holding its text otherwise.

  __structs__silt__value 'lib/a.sh'  ->  0.:str="lib/a.sh"
  __structs__silt__value '3'         ->  0.:int=3
FUN
__structs__silt__value() {
  if ! silt__read __structs__silt__value__doc "$1"; then
    silt__str __structs__silt__value__doc "$1"
  fi
}

: <<'FUN'
Sets __structs__silt__list_of__doc to a list of the documents the
arguments stand for, each read as __structs__silt__value reads it, in
their order. No arguments give the empty list.

Usage: __structs__silt__list_of <text>...
FUN
__structs__silt__list_of() {
  __structs__silt__list_of__count=$#
  __structs__silt__list_of__i=0
  while [ "$__structs__silt__list_of__i" -lt "$__structs__silt__list_of__count" ]; do
    __structs__silt__value "$1"
    shift
    set -- "$@" "$__structs__silt__value__doc"
    __structs__silt__list_of__i=$((__structs__silt__list_of__i + 1))
  done
  silt__arr __structs__silt__list_of__doc "$@"
}

: <<'FUN'
Sets __structs__silt__struct__text to the document <doc> as a struct
value: a map or a list with members as the document, an empty map or
list and a scalar in their JSON spelling, so an empty collection prints
as @obj and @arr print it. A scalar is the one keyless line; every other
document is a collection, one line or many.

  __structs__silt__struct '0.:str="bats"'  ->  "bats"
  __structs__silt__struct '0.:list'        ->  []
FUN
__structs__silt__struct() {
  case "$1" in
    0.:null) __structs__silt__struct__text=null ;;
    0.:map) __structs__silt__struct__text='{}' ;;
    0.:list) __structs__silt__struct__text='[]' ;;
    0.:*) silt__scalar __structs__silt__struct__text "$1" ;;
    *) __structs__silt__struct__text="$1" ;;
  esac
}

: <<'FUN'
Sets __structs__silt__raw__text to the document <doc> as text: a str as
its text, another scalar in its spelling, a null as the word, and a map or
a list as the document.

  __structs__silt__raw '0.:str="a b"'  ->  a b
FUN
__structs__silt__raw() {
  case "$1" in
    0.:str=*) silt__unwrap __structs__silt__raw__text "${1#0.:str=}" ;;
    *)
      __structs__silt__struct "$1"
      __structs__silt__raw__text="$__structs__silt__struct__text"
      ;;
  esac
}

: <<'FUN'
Prints the document <doc> as a struct value, and null for the empty
string, which is what an end of an empty list answers.
FUN
__structs__silt__element() {
  if [ -z "$1" ]; then
    __structs__RESULT=null
    return 0
  fi
  __structs__silt__struct "$1"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
Sets __structs__silt__at__value to the document the struct <value>
spells and __structs__silt__at__doc to the document at <path> inside it.
Both are the empty string when <value> is no struct, and the second is
when the path holds nothing.

Usage: __structs__silt__at <value> <path>
FUN
__structs__silt__at() {
  __structs__silt__at__doc=''
  if ! silt__read __structs__silt__at__value "$1"; then
    __structs__silt__at__value=''
    return 0
  fi
  silt__get __structs__silt__at__doc "$__structs__silt__at__value" "$2" 2>/dev/null \
    || __structs__silt__at__doc=''
}

: <<'FUN'
Sets __structs__silt__kind__name to the name of the kind of the
document <doc>: object, array, string, number, boolean or null. The empty
string, which is what a path nothing holds answers, is null.

  __structs__silt__kind '0."a":int=1'  ->  object
FUN
__structs__silt__kind() {
  __structs__silt__kind__name=null
  if [ -z "$1" ]; then
    return 0
  fi
  silt__type __structs__silt__kind__silt "$1" || return 1
  case "$__structs__silt__kind__silt" in
    map) __structs__silt__kind__name=object ;;
    list) __structs__silt__kind__name=array ;;
    str | time-rfc3339-utc) __structs__silt__kind__name=string ;;
    int | float) __structs__silt__kind__name=number ;;
    bool) __structs__silt__kind__name=boolean ;;
  esac
}

: <<'FUN'
Fails, naming the verb <who>, unless the struct
<value> is of the kind <kind>, object or array. Leaves the registers of
__structs__silt__at set for the caller.

Usage: __structs__silt__require_root "@sum" "$value" array || return 1
FUN
__structs__silt__require_root() {
  __structs__silt__at "$2" .
  __structs__silt__kind "$__structs__silt__at__doc"
  if [ "$__structs__silt__kind__name" != "$3" ]; then
    fatal "$1: expected $3, got '$__structs__silt__kind__name'"
    return 1
  fi
}

: <<'FUN'
Fails, naming the verb <who>, unless the struct
<value> holds a list at <path>. Leaves the registers of
__structs__silt__at set for the caller.

Usage: __structs__silt__require_list_at append "$value" '.tags' || return 1
FUN
__structs__silt__require_list_at() {
  __structs__silt__at "$2" "$3"
  __structs__silt__kind "$__structs__silt__at__doc"
  if [ "$__structs__silt__kind__name" != array ]; then
    fatal "$1: expected array at '$3', got '$__structs__silt__kind__name'"
    return 1
  fi
}

: <<'FUN'
Sets __structs__silt__plain_path__answer to true when <path> is one SILT
reads, the root "." or a run of segments, each a bare key (.name), a
quoted key (."a key"), or a list index (.[3] or [3]), and to false for
anything else: a pipe, a function, an iteration or a slice. A setter
rather than a predicate, since every @get
asks it and the answer must cost no fork.

  __structs__silt__plain_path '.a."b-c".[0]'  ->  true
  __structs__silt__plain_path '.a | length'   ->  false
FUN
__structs__silt__plain_path() {
  __structs__silt__plain_path__answer=true
  __structs__silt__PATH_REST="$1"
  if [ "$__structs__silt__PATH_REST" = . ]; then
    return 0
  fi
  while [ -n "$__structs__silt__PATH_REST" ]; do
    if ! __structs__silt__plain_path__segment; then
      __structs__silt__plain_path__answer=false
      return 0
    fi
  done
}

: <<'FUN'
Strips one path segment off __structs__silt__PATH_REST, the register the
segment helpers share with __structs__silt__plain_path: a quoted
key, a bare key or a list index. Fails when what is there is none of
them.
FUN
__structs__silt__plain_path__segment() {
  case "$__structs__silt__PATH_REST" in
    .\"*) __structs__silt__plain_path__quoted_key ;;
    .[A-Za-z0-9_-]*) __structs__silt__plain_path__bare_key ;;
    .\[[0-9]*\]* | \[[0-9]*\]*) __structs__silt__plain_path__index ;;
    *) return 1 ;;
  esac
}

: <<'FUN'
Strips a quoted key, ."...", off __structs__silt__PATH_REST.
Fails when the quote never closes.
FUN
__structs__silt__plain_path__quoted_key() {
  __structs__silt__PATH_REST="${__structs__silt__PATH_REST#.\"}"
  case "$__structs__silt__PATH_REST" in
    *\"*) __structs__silt__PATH_REST="${__structs__silt__PATH_REST#*\"}" ;;
    *) return 1 ;;
  esac
}

: <<'FUN'
Strips a bare key, .name, off __structs__silt__PATH_REST.
FUN
__structs__silt__plain_path__bare_key() {
  __structs__silt__PATH_REST="${__structs__silt__PATH_REST#.}"
  __structs__silt__PATH_REST="${__structs__silt__PATH_REST#"${__structs__silt__PATH_REST%%[!A-Za-z0-9_-]*}"}"
}

: <<'FUN'
Strips a list index, .[3] or [3], off __structs__silt__PATH_REST.
Fails when the brackets hold no digits, as an iteration .[] does.
FUN
__structs__silt__plain_path__index() {
  __structs__silt__PATH_REST="${__structs__silt__PATH_REST#.}"
  __structs__silt__PATH_REST="${__structs__silt__PATH_REST#\[}"
  __structs__silt__plain_path__index__digits="${__structs__silt__PATH_REST%%[!0-9]*}"
  if [ -z "$__structs__silt__plain_path__index__digits" ]; then
    return 1
  fi
  __structs__silt__PATH_REST="${__structs__silt__PATH_REST#"$__structs__silt__plain_path__index__digits"}"
  __structs__silt__PATH_REST="${__structs__silt__PATH_REST#\]}"
}

: <<'FUN'
Sets __structs__silt__plain_paths__answer to true when every path among
<path>... is one SILT reads, and to false when one is not.

Usage: __structs__silt__plain_paths <path>...
FUN
__structs__silt__plain_paths() {
  __structs__silt__plain_paths__answer=true
  for __structs__silt__plain_paths__path in "$@"; do
    __structs__silt__plain_path "$__structs__silt__plain_paths__path"
    if [ "$__structs__silt__plain_path__answer" = false ]; then
      __structs__silt__plain_paths__answer=false
      return 0
    fi
  done
}

: <<'FUN'
Fails, saying that <path> is not a path. A path is the root, ".", or a run
of keys and list indexes.

  __structs__silt__not_a_path '.a | length'
    ->  structs: '.a | length' is not a path ...
FUN
__structs__silt__not_a_path() {
  fatal "structs: '$1' is not a path. A path is the root, \".\", or keys and list indexes, such as .name.\"a key\"[0]."
  return 1
}

: <<'FUN'
The value at path $2 of the struct $1 as text: a string without its
quotes, any other scalar as it is written, a map or a list as a struct,
and null when the path holds nothing. Refuses a path that is not one.
FUN
__structs__silt__query_raw() {
  __structs__silt__plain_path "$2"
  if [ "$__structs__silt__plain_path__answer" = false ]; then
    __structs__silt__not_a_path "$2"
    return 1
  fi
  __structs__silt__at "$1" "$2"
  if [ -z "$__structs__silt__at__doc" ]; then
    __structs__RESULT=null
    return 0
  fi
  __structs__silt__raw "$__structs__silt__at__doc"
  __structs__RESULT="$__structs__silt__raw__text"
}

: <<'FUN'
The name of the type of the value at path $2 of the struct $1: object,
array, string, number, boolean or null, and null when the path holds
nothing. Refuses a path that is not one.
FUN
__structs__silt__query_type() {
  __structs__silt__plain_path "$2"
  if [ "$__structs__silt__plain_path__answer" = false ]; then
    __structs__silt__not_a_path "$2"
    return 1
  fi
  __structs__silt__at "$1" "$2"
  __structs__silt__kind "$__structs__silt__at__doc"
  __structs__RESULT="$__structs__silt__kind__name"
}

: <<'FUN'
The SILT half of __structs__query_first: the value, as text, at the first
of the paths $3... at which the struct $1 holds a value that is not a
null, and the default $2 when no path does, in one read of the document.
Refuses a path that is not one.
FUN
__structs__silt__query_first() {
  __structs__silt__query_first__json="$1"
  __structs__silt__query_first__default="$2"
  shift 2

  __structs__silt__plain_paths "$@"
  if [ "$__structs__silt__plain_paths__answer" = false ]; then
    __structs__silt__not_a_path "$*"
    return 1
  fi

  __structs__silt__first_defined "$__structs__silt__query_first__json" "$@"
  if [ -z "$__structs__silt__first_defined__doc" ]; then
    __structs__RESULT="$__structs__silt__query_first__default"
    return 0
  fi
  __structs__silt__raw "$__structs__silt__first_defined__doc"
  __structs__RESULT="$__structs__silt__raw__text"
}

: <<'FUN'
Sets __structs__silt__first_defined__doc to the value at the first of
the paths <path>... at which the struct <value> holds a defined value,
and to the empty string when no path does or <value> is no struct.
Defined is what @defined answers: not a null, not the empty string and
not the text null.

Usage: __structs__silt__first_defined <value> <path>...
FUN
__structs__silt__first_defined() {
  __structs__silt__first_defined__doc=''
  silt__read __structs__silt__first_defined__value "$1" || return 0
  shift
  for __structs__silt__first_defined__path in "$@"; do
    __structs__silt__first_defined__at "$__structs__silt__first_defined__value" "$__structs__silt__first_defined__path"
    if [ -n "$__structs__silt__first_defined__at__doc" ]; then
      __structs__silt__first_defined__doc="$__structs__silt__first_defined__at__doc"
      return 0
    fi
  done
}

: <<'FUN'
Sets __structs__silt__first_defined__at__doc to the value at <path> of
the document <doc>, and to the empty string when the path holds nothing
or a value that is not defined.

Usage: __structs__silt__first_defined__at <doc> <path>
FUN
__structs__silt__first_defined__at() {
  silt__get __structs__silt__first_defined__at__doc "$1" "$2" 2>/dev/null \
    || __structs__silt__first_defined__at__doc=''
  if [ "$(__structs__silt__is_defined "$__structs__silt__first_defined__at__doc")" = false ]; then
    __structs__silt__first_defined__at__doc=''
  fi
}

: <<'FUN'
Prints true when the document <doc> is a value @get's fallthrough keeps,
and false for nothing, a null, the empty string and the text null.

  __structs__silt__is_defined '0.:str=""'  ->  false
FUN
__structs__silt__is_defined() {
  case "$1" in
    '' | 0.:null | '0.:str=""' | '0.:str="null"') println false ;;
    *) println true ;;
  esac
}

: <<'FUN'
Sets __structs__silt__root__doc to the document @set starts from: the
struct <value>, or the empty map when <value> is empty or null. Fails,
naming the verb <who>, when
<value> is no struct.

Usage: __structs__silt__root <value> <who>
FUN
__structs__silt__root() {
  case "$1" in
    '' | null)
      silt__obj __structs__silt__root__doc
      return 0
      ;;
  esac
  __structs__silt__read "$2" "$1" || return 1
  __structs__silt__root__doc="$__structs__silt__read__doc"
}

: <<'FUN'
The SILT half of @set: places each value at its path in the struct $1,
one pair after the other, and prints the document. A later pair sees what
an earlier pair placed. Refuses, naming the path, a path that runs
through a scalar and a list index the list does not have.
FUN
__structs__silt__set() {
  __structs__silt__root "$1" put || return 1
  __structs__silt__set__doc="$__structs__silt__root__doc"
  shift

  while [ $# -ge 2 ]; do
    __structs__silt__place "$1" "$2" || return 1
    shift 2
  done
  __structs__RESULT="$__structs__silt__set__doc"
}

: <<'FUN'
Places the value <text> at <path> in __structs__silt__set__doc, reading
both as @set takes them. A null on the way to the path becomes a map
first. Fails, naming the path, when SILT refuses the
place.

Usage: __structs__silt__place <path> <text>
FUN
__structs__silt__place() {
  __structs__normalized_path "$1"
  __structs__silt__place__path="$__structs__normalized_path__value"
  __structs__silt__value "$2"
  __structs__silt__place__null_parent "$__structs__silt__place__path"
  if ! silt__set __structs__silt__set__doc "$__structs__silt__set__doc" "$__structs__silt__place__path" "$__structs__silt__value__doc" 2>/dev/null; then
    # A place SILT refuses can leave the spill file a value too large for
    # an argument went through; SILT removes it only on its own way out.
    __silt__unspill
    fatal "put: cannot set field at '$__structs__silt__place__path'"
    return 1
  fi
}

: <<'FUN'
Makes the nearest ancestor of <path> that __structs__silt__set__doc holds
a map when it is a null, so that silt__set can create the members under
it. An ancestor the document does not hold is missing, not null, and
silt__set creates it itself.

Usage: __structs__silt__place__null_parent <path>
FUN
__structs__silt__place__null_parent() {
  __structs__silt__place__null_parent__path="$(__structs__parent_path "$1")"
  while [ "$__structs__silt__place__null_parent__path" != . ]; do
    silt__get __structs__silt__place__null_parent__doc "$__structs__silt__set__doc" "$__structs__silt__place__null_parent__path" 2>/dev/null \
      || __structs__silt__place__null_parent__doc=''
    if [ -n "$__structs__silt__place__null_parent__doc" ]; then
      __structs__silt__place__null_parent__map "$__structs__silt__place__null_parent__path" "$__structs__silt__place__null_parent__doc"
      return 0
    fi
    __structs__silt__place__null_parent__path="$(__structs__parent_path "$__structs__silt__place__null_parent__path")"
  done
}

: <<'FUN'
Replaces the value <doc> at <path> of __structs__silt__set__doc with the
empty map when it is a null, and leaves any other value alone.

Usage: __structs__silt__place__null_parent__map <path> <doc>
FUN
__structs__silt__place__null_parent__map() {
  if [ "$2" = 0.:null ]; then
    silt__set __structs__silt__set__doc "$__structs__silt__set__doc" "$1" 0.:map
  fi
}

: <<'FUN'
The SILT half of @push: appends the values to the list at the root of
the struct $1, or at the path $2 when more than one argument follows the
struct, and prints the document. Refuses a path that holds no list.
FUN
__structs__silt__push() {
  __structs__silt__push__json="$1"
  __structs__silt__push__path=.
  shift
  if [ $# -ge 2 ]; then
    __structs__normalized_path "$1"
    __structs__silt__push__path="$__structs__normalized_path__value"
    shift
  fi

  __structs__silt__require_list_at append "$__structs__silt__push__json" "$__structs__silt__push__path" || return 1
  __structs__silt__list_of "$@"
  silt__concat __structs__silt__push__doc "$__structs__silt__at__doc" "$__structs__silt__list_of__doc" || return 1
  if [ "$__structs__silt__push__path" != . ]; then
    silt__set __structs__silt__push__doc "$__structs__silt__at__value" "$__structs__silt__push__path" "$__structs__silt__push__doc" || return 1
  fi
  __structs__RESULT="$__structs__silt__push__doc"
}

: <<'FUN'
The SILT half of __structs__is_json: whether <value> is a struct, in any
form this backend reads.
FUN
__structs__silt__is_json() {
  silt__read __structs__silt__is_json__doc "$1"
}

: <<'FUN'
The SILT half of __structs__each: each member of the struct $1 on a line
of its own, a scalar in its JSON spelling and a collection as its
document on one line. A value with no members, a scalar or no struct
among them, yields no lines and succeeds.
FUN
__structs__silt__each() {
  __structs__RESULT=''
  __structs__silt__each__lines=''
  silt__read __structs__silt__each__doc "$1" || return 0
  case "$__structs__silt__each__doc" in
    0.:*) return 0 ;;
  esac
  silt__each "$__structs__silt__each__doc" __structs__silt__each__line || return 1
  __structs__RESULT="${__structs__silt__each__lines#"$__structs__NL"}"
}

: <<'FUN'
__structs__silt__each's callback: adds the member <value>, on one line, to
the lines __structs__silt__each gathers.

Usage: __structs__silt__each__line <key> <value>
FUN
__structs__silt__each__line() {
  __structs__silt__struct "$2"
  silt__to_line __structs__silt__each__line__text "$__structs__silt__struct__text"
  __structs__silt__each__lines="$__structs__silt__each__lines$__structs__NL$__structs__silt__each__line__text"
}


: <<'FUN'
The SILT half of __structs__collect: the list of the values in the run
$1, each preceded by the record separator, a value that is a struct
joining as that value and any other as a str.
FUN
__structs__silt__collect() {
  if [ -z "$1" ]; then
    __structs__silt__list_of
  else
    __structs__silt__collect__list "${1#"$__structs__RS"}"
  fi
  __structs__RESULT="$__structs__silt__list_of__doc"
}

: <<'FUN'
Sets __structs__silt__list_of__doc to the list of the values in <run>,
which the record separator divides; an empty value among them joins as
the empty string, where a split on the separator would drop it.

Usage: __structs__silt__collect__list <run>
FUN
__structs__silt__collect__list() {
  __structs__silt__collect__list__rest="$1"
  set --
  while [ "${__structs__silt__collect__list__rest#*"$__structs__RS"}" != "$__structs__silt__collect__list__rest" ]; do
    set -- "$@" "${__structs__silt__collect__list__rest%%"$__structs__RS"*}"
    __structs__silt__collect__list__rest="${__structs__silt__collect__list__rest#*"$__structs__RS"}"
  done
  set -- "$@" "$__structs__silt__collect__list__rest"
  __structs__silt__list_of "$@"
  __structs__RESULT="$__structs__silt__list_of__doc"
}

: <<'FUN'
The SILT half of @let: binds the keys in the caller's shell through
silt__bind, which binds a str as its text, a map or a list as its
document, another scalar as its spelling, and an absent or null field as
the empty string. A value that is no struct binds every key empty.
FUN
__structs__silt__let() {
  if ! silt__read __structs__silt__let__doc "$1"; then
    silt__null __structs__silt__let__doc
  fi
  __structs__silt__let__prefix="$2"
  shift 2
  silt__bind "$__structs__silt__let__prefix" "$__structs__silt__let__doc" "$@"
}

: <<'FUN'
The SILT half of @unwrap. The options object goes unread: a map or a
list prints as its document either way. An empty value prints nothing.
FUN
__structs__silt__unwrap() {
  if [ -z "$1" ]; then
    return 0
  fi
  __structs__silt__read "@unwrap" "$1" || return 1
  if [ "$(__structs__silt__unwrap__compact "${2:-}")" = true ]; then
    __structs__silt__unwrap__json "$__structs__silt__read__doc"
    __structs__RESULT="$__structs__silt__unwrap__json__text"
    return 0
  fi
  __structs__silt__raw "$__structs__silt__read__doc"
  __structs__RESULT="$__structs__silt__raw__text"
}

: <<'FUN'
Prints true when the @unwrap options <options> ask for the compact form,
false otherwise, an absent or unreadable options value included.
FUN
__structs__silt__unwrap__compact() {
  if silt__read __structs__silt__unwrap__compact__doc "$1" \
    && silt__get __structs__silt__unwrap__compact__value "$__structs__silt__unwrap__compact__doc" .compact 2>/dev/null \
    && [ "$__structs__silt__unwrap__compact__value" = '0.:bool=true' ]; then
    printf 'true\n'
  else
    printf 'false\n'
  fi
}

: <<'FUN'
Sets __structs__silt__unwrap__json__text to the document <doc> in @unwrap's
compact form: a str as its text, and any other value as one line of JSON.
FUN
__structs__silt__unwrap__json() {
  case "$1" in
    0.:str=*) silt__unwrap __structs__silt__unwrap__json__text "${1#0.:str=}" ;;
    *) silt__to_json __structs__silt__unwrap__json__text "$1" ;;
  esac
}

: <<'FUN'
The SILT half of @scalar: a list yields its first element, a str its
text, a null or a missing field nothing, and any other value its
spelling, a map as one line of JSON.
FUN
__structs__silt__scalar() {
  __structs__normalized_path "${2:-.}"
  __structs__silt__at "$1" "$__structs__normalized_path__value"
  __structs__silt__kind "$__structs__silt__at__doc"
  case "$__structs__silt__kind__name" in
    null) __structs__RESULT='' ;;  # private-name-check: allow -- the backend answers in the register
    array) __structs__silt__scalar__first "$__structs__silt__at__doc" ;;
    object) __structs__silt__scalar__json "$__structs__silt__at__doc" ;;
    *) __structs__silt__scalar__raw "$__structs__silt__at__doc" ;;
  esac
}

: <<'FUN'
Sets __structs__RESULT to the first element of the list <doc> as @scalar
answers it: the empty string for an empty list, and for a null or a false
first element.
FUN
__structs__silt__scalar__first() {
  silt__first __structs__silt__scalar__first__doc "$1" || return 1
  case "$__structs__silt__scalar__first__doc" in
    '' | 0.:null | 0.:bool=false) __structs__RESULT='' ;;  # private-name-check: allow -- the backend answers in the register
    *) __structs__silt__scalar__raw "$__structs__silt__scalar__first__doc" ;;
  esac
}

: <<'FUN'
Prints the map <doc> as one line of JSON, which is how @scalar
stringifies a map.
FUN
__structs__silt__scalar__json() {
  silt__to_json __structs__silt__scalar__json__text "$1" || return 1
  __structs__RESULT="$__structs__silt__scalar__json__text"
}

: <<'FUN'
Prints the scalar <doc> as text: a str without its quotes, and any other
scalar as it is written.
FUN
__structs__silt__scalar__raw() {
  __structs__silt__raw "$1"
  __structs__RESULT="$__structs__silt__raw__text"
}

: <<'FUN'
The SILT half of @first.
FUN
__structs__silt__first() {
  __structs__silt__read "@first" "$1" || return 1
  silt__first __structs__silt__first__doc "$__structs__silt__read__doc" || return 1
  __structs__silt__element "$__structs__silt__first__doc"
}

: <<'FUN'
The SILT half of @last.
FUN
__structs__silt__last() {
  __structs__silt__read "@last" "$1" || return 1
  silt__last __structs__silt__last__doc "$__structs__silt__read__doc" || return 1
  __structs__silt__element "$__structs__silt__last__doc"
}

: <<'FUN'
The SILT half of @pop: the last element, then the list without it.
FUN
__structs__silt__pop() {
  __structs__silt__read "@pop" "$1" || return 1
  silt__pop __structs__silt__pop__last __structs__silt__pop__rest "$__structs__silt__read__doc" || return 1
  __structs__silt__element "$__structs__silt__pop__last"
  __structs__RESULT="$__structs__silt__pop__rest"
}

: <<'FUN'
The SILT half of @shift: the first element, then the list without it.
FUN
__structs__silt__shift() {
  __structs__silt__read "@shift" "$1" || return 1
  silt__shift __structs__silt__shift__first __structs__silt__shift__rest "$__structs__silt__read__doc" || return 1
  __structs__silt__element "$__structs__silt__shift__first"
  __structs__RESULT="$__structs__silt__shift__rest"
}

: <<'FUN'
The SILT half of @take: the first $2 elements of the list $1, and the
whole list with a warning when it has fewer. Refuses a count that is not
a whole number of 0 or more and a value that is not a list.
FUN
__structs__silt__take() {
  case "$2" in
    '' | *[!0-9]*)
      fatal "@take: n must be a non-negative integer, got '$2'"
      return 1
      ;;
  esac
  __structs__silt__require_root "@take" "$1" array || return 1
  silt__len __structs__silt__take__len "$__structs__silt__at__value" || return 1
  __structs__warn_take_overrun "$2" "$__structs__silt__take__len"
  silt__take __structs__silt__take__doc "$__structs__silt__at__value" "$2" 2>/dev/null || return 1
  __structs__RESULT="$__structs__silt__take__doc"
}

: <<'FUN'
The SILT half of @compact: a document has one spelling, so the value
prints as it reads.
FUN
__structs__silt__compact() {
  __structs__silt__read "@compact" "$1" || return 1
  __structs__silt__struct "$__structs__silt__read__doc"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
The SILT half of @sum: the total of the numbers in the list, a null
among them counting for nothing, and a whole total printed without a
fraction.

  @sum "[1,null,3]"  ->  4
  @sum "[1.5,2.5]"   ->  4
FUN
__structs__silt__sum() {
  __structs__silt__require_root "@sum" "$1" array || return 1
  silt__filter __structs__silt__sum__numbers "$__structs__silt__at__value" __structs__silt__sum__is_number || return 1
  silt__sum __structs__silt__sum__doc "$__structs__silt__sum__numbers" || return 1
  __structs__silt__struct "$__structs__silt__sum__doc"
  __structs__silt__sum__integral "$__structs__silt__struct__text"
  __structs__RESULT="$__structs__silt__sum__integral__text"
}

: <<'FUN'
silt__filter's predicate for @sum: answers true in the variable <out> for
a member that is not a null, and false for a null.

Usage: __structs__silt__sum__is_number <out> <key> <value>
FUN
__structs__silt__sum__is_number() {
  case "$3" in
    0.:null) eval "$1=false" ;;
    *) eval "$1=true" ;;
  esac
}

: <<'FUN'
Sets __structs__silt__sum__integral__text to the number <text> without a
fraction of nothing but zeros, and any other number as it is.

  __structs__silt__sum__integral 4.0   ->  4
  __structs__silt__sum__integral 2.50  ->  2.5
FUN
__structs__silt__sum__integral() {
  __structs__silt__sum__integral__text="$1"
  case "$1" in
    *.*)
      __structs__silt__sum__integral__text="${1%"${1##*[!0]}"}"
      __structs__silt__sum__integral__text="${__structs__silt__sum__integral__text%.}"
      ;;
  esac
}

: <<'FUN'
Runs the SILT verb silt__<verb> over the two lists <list> and <other>,
and prints the list it answers.

Usage: __structs__silt__of_two concat "$list" "$other"
FUN
__structs__silt__of_two() {
  __structs__silt__read "@$1" "$2" || return 1
  __structs__silt__of_two__left="$__structs__silt__read__doc"
  __structs__silt__read "@$1" "$3" || return 1
  "silt__$1" __structs__silt__of_two__doc "$__structs__silt__of_two__left" "$__structs__silt__read__doc" || return 1
  __structs__RESULT="$__structs__silt__of_two__doc"
}

: <<'FUN'
The SILT half of @intersect.
FUN
__structs__silt__intersect() {
  __structs__silt__of_two intersect "$1" "$2"
}

: <<'FUN'
The SILT half of @difference.
FUN
__structs__silt__difference() {
  __structs__silt__of_two difference "$1" "$2"
}

: <<'FUN'
The SILT half of @concat.
FUN
__structs__silt__concat() {
  __structs__silt__of_two concat "$1" "$2"
}

: <<'FUN'
The SILT half of @unique: the distinct elements in the order of values
that sort.awk beside this file gives.
FUN
__structs__silt__unique() {
  __structs__silt__read "@unique" "$1" || return 1
  silt__unique __structs__silt__unique__doc "$__structs__silt__read__doc" || return 1
  __structs__silt__unique__sorted="$(__structs__silt__sorted "$__structs__silt__unique__doc")" || return 1
  __structs__RESULT="$__structs__silt__unique__sorted"
}

: <<'FUN'
Prints the SILT list $1 with its members in the order of values that
sort.awk beside this file gives: null, false, true, numbers, strings,
lists, then maps.
FUN
__structs__silt__sorted() {
  println "$1" | LC_ALL=C awk -f "$__structs__DIR/silt/sort.awk"
}

: <<'FUN'
The SILT half of @run_awk: runs the awk program $1 over the struct $2 with
silt__run, which starts one process. Every struct given with --with is
read into a document first, and every other option goes to silt__run as it
is. A map or a list the program prints is the result as it is, and a
scalar is the result in its JSON spelling.
FUN
__structs__silt__run_awk() {
  __structs__silt__run_awk__program="$1"
  __structs__silt__read "@run_awk" "$2" || return 1
  __structs__silt__run_awk__main="$__structs__silt__read__doc"
  shift 2

  __structs__silt__run_awk__left=$#
  while [ "$__structs__silt__run_awk__left" -gt 0 ]; do
    case "$1" in
      --with)
        __structs__silt__read "@run_awk" "${2-}" || return 1
        set -- "$@" --with "$__structs__silt__read__doc"
        __structs__silt__run_awk__left=$((__structs__silt__run_awk__left - 2))
        shift 2
        ;;
      *)
        set -- "$@" "$1"
        __structs__silt__run_awk__left=$((__structs__silt__run_awk__left - 1))
        shift
        ;;
    esac
  done

  silt__run __structs__silt__run_awk__printed \
    "$__structs__silt__run_awk__program" \
    "$__structs__silt__run_awk__main" \
    "$@" \
    || return $?
  __structs__silt__struct "$__structs__silt__run_awk__printed"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
The SILT half of @member: the value at the path $2 inside $1 as a struct,
and null when the path holds nothing.
FUN
__structs__silt__member() {
  __structs__normalized_path "$2"
  __structs__silt__at "$1" "$__structs__normalized_path__value"
  __structs__silt__element "$__structs__silt__at__doc"
}

: <<'FUN'
Sets __structs__silt__keyed__doc to what SILT's verb <verb> answers for
the list $2 and the paths after it. The verbs that order a list by the
values at paths inside its elements run through this: @sort_by,
@group_by, @min and @max.

Usage: __structs__silt__keyed sort_by "$list" .ready_at .iid
FUN
__structs__silt__keyed() {
  __structs__silt__keyed__verb="$1"
  __structs__silt__read "@$1" "$2" || return 1
  shift 2

  "silt__$__structs__silt__keyed__verb" __structs__silt__keyed__doc "$__structs__silt__read__doc" "$@"
}

: <<'FUN'
The SILT half of @sort_by.
FUN
__structs__silt__sort_by() {
  __structs__silt__keyed sort_by "$@" || return 1
  __structs__silt__struct "$__structs__silt__keyed__doc"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
The SILT half of @group_by.
FUN
__structs__silt__group_by() {
  __structs__silt__keyed group_by "$@" || return 1
  __structs__silt__struct "$__structs__silt__keyed__doc"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
The SILT half of @min: the element that orders first, and null for an
empty list.
FUN
__structs__silt__min() {
  __structs__silt__keyed min "$@" || return 1
  __structs__silt__element "$__structs__silt__keyed__doc"
}

: <<'FUN'
The SILT half of @max: the element that orders last, and null for an
empty list.
FUN
__structs__silt__max() {
  __structs__silt__keyed max "$@" || return 1
  __structs__silt__element "$__structs__silt__keyed__doc"
}

: <<'FUN'
The SILT half of @from_entries: a map from a list of its keys and
values.
FUN
__structs__silt__from_entries() {
  __structs__silt__read "@from_entries" "$1" || return 1
  silt__from_entries __structs__silt__from_entries__doc "$__structs__silt__read__doc" || return 1
  __structs__silt__struct "$__structs__silt__from_entries__doc"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
The SILT half of @to_json: the struct $1 as one line of JSON.
FUN
__structs__silt__to_json() {
  __structs__silt__read "@to_json" "$1" || return 1
  silt__to_json __structs__silt__to_json__text "$__structs__silt__read__doc" || return 1
  __structs__RESULT="$__structs__silt__to_json__text"
}

: <<'FUN'
The SILT half of @pick: the map $1 with only the members under the keys
$2... .
FUN
__structs__silt__pick() {
  __structs__silt__read "@pick" "$1" || return 1
  shift

  silt__pick __structs__silt__pick__doc "$__structs__silt__read__doc" "$@" || return 1
  __structs__silt__struct "$__structs__silt__pick__doc"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
The SILT half of @without: the map $1 without the members under the keys
$2... .
FUN
__structs__silt__without() {
  __structs__silt__read "@without" "$1" || return 1
  shift

  silt__without __structs__silt__without__doc "$__structs__silt__read__doc" "$@" || return 1
  __structs__silt__struct "$__structs__silt__without__doc"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
The SILT half of @filter with a predicate: the members of $1 that the
predicate $2 answers true for, called as SILT calls a predicate, with the
extra arguments after it.
FUN
__structs__silt__filter() {
  __structs__silt__read "@filter" "$1" || return 1
  shift

  silt__filter __structs__silt__filter__doc "$__structs__silt__read__doc" "$@" || return 1
  __structs__silt__struct "$__structs__silt__filter__doc"
  __structs__RESULT="$__structs__silt__struct__text"
}

: <<'FUN'
The SILT half of @entries: one {key, value} map per member, in the
map's order.
FUN
__structs__silt__entries() {
  __structs__silt__require_root "@entries" "$1" object || return 1
  silt__entries __structs__silt__entries__doc "$__structs__silt__at__value" || return 1
  __structs__RESULT="$__structs__silt__entries__doc"
}

: <<'FUN'
The SILT half of @keys: a map's keys in sorted order, and a list's
indices. The order is one awk.
FUN
__structs__silt__keys() {
  __structs__silt__read "@keys" "$1" || return 1
  silt__canon __structs__silt__keys__doc "$__structs__silt__read__doc" || return 1
  silt__keys __structs__silt__keys__doc "$__structs__silt__keys__doc" || return 1
  __structs__RESULT="$__structs__silt__keys__doc"
}

: <<'FUN'
The SILT half of @values: a map's values as a list, in the map's order.
FUN
__structs__silt__values() {
  __structs__silt__read "@values" "$1" || return 1
  silt__values __structs__silt__values__doc "$__structs__silt__read__doc" || return 1
  __structs__RESULT="$__structs__silt__values__doc"
}

: <<'FUN'
The SILT half of @join: the elements of the list $1 as text, with the
separator $2 between them. Refuses a third argument, since @join takes
none.
FUN
__structs__silt__join() {
  if [ "${3:-.}" != "." ]; then
    fatal "@join: takes a list and a separator, and no template. Change each element first, then join them."
    return 1
  fi
  __structs__silt__read "@join" "$1" || return 1
  silt__join __structs__silt__join__text "$__structs__silt__read__doc" "${2:-}" || return 1
  __structs__RESULT="$__structs__silt__join__text"
}

: <<'FUN'
The SILT half of @split. SILT cuts on newlines when the delimiter is
omitted or empty, as @split does.
FUN
__structs__silt__split() {
  silt__split __structs__silt__split__doc "$1" "${2-}" || return 1
  __structs__RESULT="$__structs__silt__split__doc"
}

: <<'FUN'
The SILT half of @is_valid.
FUN
__structs__silt__is_valid() {
  silt__read __structs__silt__is_valid__doc "$1"
}

: <<'FUN'
The SILT half of @encode_string.
FUN
__structs__silt__encode_string() {
  silt__wrap __structs__silt__encode_string__text "$1" || return 1
  __structs__RESULT="$__structs__silt__encode_string__text"
}

: <<'FUN'
The SILT half of @len.
FUN
__structs__silt__len() {
  __structs__silt__read "@len" "$1" || return 1
  silt__len __structs__silt__len__n "$__structs__silt__read__doc" || return 1
  __structs__RESULT="$__structs__silt__len__n"
}

: <<'FUN'
Sets __structs__silt__arrays__how to what the options <opts> of @merge
or @deepmerge say two lists under one key do: replace, concat or union.
Empty options, and options that say nothing, mean replace.
FUN
__structs__silt__arrays() {
  __structs__silt__arrays__how=replace
  silt__read __structs__silt__arrays__doc "$1" || return 0
  silt__option __structs__silt__arrays__how "$__structs__silt__arrays__doc" arrays replace
}

: <<'FUN'
The SILT face of @merge: the map $1 with the map $2 laid over it, one
level deep, two lists under one key combined as the options $3 say.
FUN
__structs__silt__merge() {
  __structs__silt__read "@merge" "$1" || return 1
  __structs__silt__MERGED="$__structs__silt__read__doc"
  __structs__silt__read "@merge" "$2" || return 1
  __structs__silt__arrays "${3:-}"
  silt__each "$__structs__silt__read__doc" __structs__silt__merge__lay "$__structs__silt__arrays__how" || return 1
  __structs__RESULT="$__structs__silt__MERGED"
}

: <<'FUN'
__structs__silt__merge's callback: lays the member <key> <value> of the
second map on __structs__silt__MERGED, two lists under the key combined
as <how> says.

Usage: __structs__silt__merge__lay <key> <value> <how>
FUN
__structs__silt__merge__lay() {
  silt__wrap __structs__silt__merge__lay__key "$1"
  __structs__silt__merge__lay__path=".$__structs__silt__merge__lay__key"
  __structs__silt__merge__combined "$__structs__silt__merge__lay__path" "$2" "$3"
  silt__set __structs__silt__MERGED "$__structs__silt__MERGED" "$__structs__silt__merge__lay__path" "$__structs__silt__merge__combined__doc"
}

: <<'FUN'
Sets __structs__silt__merge__combined__doc to the value to place at
<path> of __structs__silt__MERGED: the list already there with the list
<value> after it when both are lists and <how> is concat, the distinct
values of both in the order @unique gives when <how> is union, and
<value> otherwise.

Usage: __structs__silt__merge__combined <path> <value> <how>
FUN
__structs__silt__merge__combined() {
  __structs__silt__merge__combined__doc="$2"
  if [ "$3" = replace ]; then
    return 0
  fi
  silt__get __structs__silt__merge__combined__had "$__structs__silt__MERGED" "$1" 2>/dev/null || return 0
  case "$__structs__silt__merge__combined__had" in
    0.0* | 0.:list) ;;
    *) return 0 ;;
  esac
  case "$2" in
    0.0* | 0.:list) ;;
    *) return 0 ;;
  esac

  silt__concat __structs__silt__merge__combined__doc "$__structs__silt__merge__combined__had" "$2"
  if [ "$3" = union ]; then
    silt__unique __structs__silt__merge__combined__doc "$__structs__silt__merge__combined__doc"
    __structs__silt__merge__combined__doc="$(__structs__silt__sorted "$__structs__silt__merge__combined__doc")"
  fi
}

: <<'FUN'
The SILT face of @deepmerge: the map $1 with the map $2 laid over it at
every depth, two lists under one key combined as the options $3 say.
FUN
__structs__silt__deepmerge() {
  __structs__silt__read "@deepmerge" "$1" || return 1
  __structs__silt__deepmerge__under="$__structs__silt__read__doc"
  __structs__silt__read "@deepmerge" "$2" || return 1
  __structs__silt__arrays "${3:-}"
  silt__deepmerge __structs__silt__deepmerge__doc "$__structs__silt__deepmerge__under" "$__structs__silt__read__doc" --lists "$__structs__silt__arrays__how" || return 1
  __structs__RESULT="$__structs__silt__deepmerge__doc"
}

: <<'FUN'
The SILT face of @pluck: the value at the path $2 inside each element of
$1, as a list, null where an element holds nothing there. Refuses a path
that is not one.
FUN
__structs__silt__pluck() {
  __structs__silt__plain_path "$2"
  if [ "$__structs__silt__plain_path__answer" = false ]; then
    __structs__silt__not_a_path "$2"
    return 1
  fi
  __structs__silt__read "@pluck" "$1" || return 1
  __structs__normalized_path "$2"
  silt__pluck __structs__silt__pluck__doc "$__structs__silt__read__doc" "$__structs__normalized_path__value" || return 1
  __structs__RESULT="$__structs__silt__pluck__doc"
}

: <<'FUN'
The SILT face of @project: each element of the list $1 as a map of the
keys the constructor $2 names, "{name, color}". Refuses a constructor
that computes a member, such as "{label: .name}".
FUN
__structs__silt__project() {
  __structs__silt__project__keys="$2"
  case "$__structs__silt__project__keys" in
    '{'?*'}') ;;
    *)
      fatal "@project: expected object constructor (e.g. {name, color}), got '$2'"
      return 1
      ;;
  esac
  __structs__silt__project__keys="${__structs__silt__project__keys#\{}"
  __structs__silt__project__keys="${__structs__silt__project__keys%\}}"
  case "$__structs__silt__project__keys" in
    *[!A-Za-z0-9_,\ ]*)
      fatal "@project: expected the names of members (e.g. {name, color}), got '$2'"
      return 1
      ;;
  esac
  __structs__silt__require_root "@project" "$1" array || return 1

  __structs__silt__keep_ifs
  IFS=', '
  set -f
  # shellcheck disable=SC2086  # the split on the commas is the point
  set -- $__structs__silt__project__keys
  set +f
  __structs__silt__give_back_ifs

  silt__project __structs__silt__project__doc "$__structs__silt__at__value" "$@" || return 1
  __structs__RESULT="$__structs__silt__project__doc"
}

: <<'FUN'
The SILT face of @flatten.
FUN
__structs__silt__flatten() {
  __structs__silt__read "@flatten" "$1" || return 1
  silt__flatten __structs__silt__flatten__doc "$__structs__silt__read__doc" "$2" "${3:-.}" || return 1
  __structs__RESULT="$__structs__silt__flatten__doc"
}

: <<'FUN'
The SILT face of @dump: the struct $1 as JSON over several lines, with two
spaces for each level. Refuses a second argument, since @dump takes none.
FUN
__structs__silt__dump() {
  if [ "${2:-.}" != "." ]; then
    fatal "@dump: takes a struct and no filter. Use @pick or @without for the members to print."
    return 1
  fi
  __structs__silt__read "@dump" "$1" || return 1
  SILT_DUMP=json silt__dump __structs__silt__dump__text "$__structs__silt__read__doc" || return 1
  __structs__RESULT="$__structs__silt__dump__text"
}

: <<'FUN'
The SILT face of @validate: checks the struct $1 against the JSON Schema
in the file $2 through strata's validator, with every schema document the
schema refers to read from the file its reference names, relative to the
schema file's directory. Returns 0 when the struct meets the schema, and
1 with every error on stderr, one per line, when it does not.
FUN
__structs__silt__validate() {
  __structs__silt__read "@validate" "$1" || return 1
  __structs__silt__validate__doc="$__structs__silt__read__doc"
  if [ ! -f "$2" ]; then
    error "@validate: schema file not found: $2"
    return 1
  fi
  silt__from_json __structs__silt__validate__schema < "$2" || return 1
  __structs__silt__validate__dir="${2%/*}"
  if [ "$__structs__silt__validate__dir" = "$2" ]; then
    __structs__silt__validate__dir=.
  fi

  __structs__silt__check "$__structs__silt__validate__doc" "$__structs__silt__validate__schema" "$__structs__silt__validate__dir"
}

: <<'FUN'
Validates the document <doc> against the schema document <schema> and
the closure of the schema documents it refers to, each read from
<dir>/<key> as the closure grows, and reports the errors as @validate
does. A referenced file that is missing or holds no JSON is left out, so
the validator reports the reference that names it.

Usage: __structs__silt__check <doc> <schema> <dir>
FUN
__structs__silt__check() {
  __structs__silt__check__dir="$3"
  __structs__silt__KEYS_SEEN="$__structs__NL"
  silt__references __structs__silt__check__pending "$2"
  set -- "$1" "$2"

  while [ "$__structs__silt__check__pending" != 0.:list ]; do
    silt__shift __structs__silt__check__key __structs__silt__check__pending "$__structs__silt__check__pending"
    silt__unwrap __structs__silt__check__key "${__structs__silt__check__key#0.:str=}"
    __structs__silt__first_sight "$__structs__silt__check__key" || continue
    __structs__silt__referenced "$__structs__silt__check__dir" "$__structs__silt__check__key" || continue
    set -- "$@" "$__structs__silt__check__key" "$__structs__silt__referenced__doc"
    silt__references __structs__silt__check__more "$__structs__silt__referenced__doc" "$__structs__silt__check__key"
    silt__concat __structs__silt__check__pending "$__structs__silt__check__pending" "$__structs__silt__check__more"
  done

  silt__validate __structs__silt__check__errors "$@" || return 1
  __structs__silt__report "$__structs__silt__check__errors"
}

: <<'FUN'
Succeeds the first time it sees <key>, noting it in
__structs__silt__KEYS_SEEN, and fails every time after, so a closure that
refers to a document twice reads it once and one that refers back to a
document it came from ends.
FUN
__structs__silt__first_sight() {
  case "$__structs__silt__KEYS_SEEN" in
    *"$__structs__NL$1$__structs__NL"*) return 1 ;;
  esac
  __structs__silt__KEYS_SEEN="$__structs__silt__KEYS_SEEN$1$__structs__NL"
}

: <<'FUN'
Sets __structs__silt__referenced__doc to the schema document in the JSON
file <dir>/<key>. Fails, quietly, when the file is missing or holds no
JSON.

Usage: __structs__silt__referenced <dir> <key>
FUN
__structs__silt__referenced() {
  if [ ! -f "$1/$2" ]; then
    return 1
  fi
  silt__from_json __structs__silt__referenced__doc < "$1/$2" 2>/dev/null
}

: <<'FUN'
Prints every error in the list <errors> on stderr, one per line, and
fails when there is one. Succeeds, printing nothing, for the empty list.
FUN
__structs__silt__report() {
  case "$1" in
    0.:list) return 0 ;;
  esac
  silt__each "$1" __structs__silt__report__line
  return 1
}

: <<'FUN'
__structs__silt__report's callback: prints the error <value> on stderr.

Usage: __structs__silt__report__line <key> <value>
FUN
__structs__silt__report__line() {
  silt__unwrap __structs__silt__report__line__text "${2#0.:str=}"
  println "$__structs__silt__report__line__text" >&2
}
