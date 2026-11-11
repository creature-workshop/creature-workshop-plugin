#!/bin/sh

:<<'MODULE'
The structs API: structured-object helpers for POSIX shell.

Provides a backend-opaque, @-sigil surface (@get, @set, @map, ...) for
reading, building, and transforming structured values. The verbs run on
SILT, the document format and library that strata provides, in the calling
shell. A caller treats a value as an opaque struct and passes it only
through this API, so the format can change without callers changing.

A verb reads a path that is keys and list indexes, such as .name."a key"[0].
A transformation that loops over the members of a struct is an awk program
that @run_awk runs in one process. Nothing here starts jq, and lint rejects
a jq program or a call of jq anywhere in the repository.
MODULE

:<<'DOC'
The type kind (type.sh, sourced below) imports lib/kinds, which imports this
file back. That second arrival is the load already under way, and returns to
it, so the two modules can each import the other. The loader, the
reporting verbs and println are sourced here for a caller that reaches this
file without .envrc: the verbs below print with println, which lib/stdout
defines, and fail with fatal, which shell-logs defines.
DOC
if [ "${__structs__SOURCING:-0}" = 1 ]; then
  return 0
fi
__structs__SOURCING=1

if [ "${import__DEFINED:-0}" != 1 ]; then
  . "$SHELLOPS_DIR/lib/import.api.sh"
fi

if ! command -v fatal >/dev/null 2>&1; then
  . "$SHELLOPS_DIR/shell/.logs/shell/log/api.sh"
fi

if ! command -v println >/dev/null 2>&1; then
  . "$SHELLOPS_DIR/lib/stdout/api.sh"
fi

:<<'CONST'
Absolute path to this module's directory. POSIX sh has no $BASH_SOURCE, so we
derive it from SHELLOPS_DIR, which .envrc exports (from its own location) just
before sourcing this file -- it always tracks the real install location, even
when callers relocate the tree (e.g. install tests).
CONST
__structs__DIR="$SHELLOPS_DIR/lib/structs"

:<<'DOC'
The type kind and the enum family, each its own file for its own machinery
and part of this API. They come first, the way a module's imports do: what
they define is called later, and nothing they run at import needs a verb.
The enum family declares into the type kind, so it loads second.
DOC
. "$__structs__DIR/type.sh"
. "$__structs__DIR/enum.sh"
__structs__SOURCING=0

# CONST: A newline, the separator @println joins elements with.
__structs__NL="
"

:<<'CONST'
Every verb the backend implements, one name per word: @<verb> is defined
below as a call to __structs__dispatch, which runs the backend's
__structs__<backend>__<verb>. Adding a verb is exactly: write its
implementation in the backend and add its name here.
CONST
__structs__PORTED_VERBS='unwrap scalar set push last first pop shift take compact sum intersect difference concat unique entries keys values join split is_valid encode_string len'

:<<'CONST'
The backend the verbs run on: silt, the SILT library from strata, which
the boot fetches and sources before this file loads (lib/self/structs.sh).
The verbs run in the calling shell and write their result into the
register below.
CONST
__structs__BACKEND=silt

:<<'DOC'
The backend's fragment, lib/structs/silt/backend.sh: its implementations
of the verbs. The verbs run on SILT's, which the
boot makes present (lib/self/structs.sh); a shell that sources this file
without the boot gets them from the library SILT_DIR names, and fails,
saying so, when it names none.
DOC
if ! command -v silt__read >/dev/null 2>&1; then
  if [ -n "${SILT_DIR:-}" ] && [ -f "$SILT_DIR/api.sh" ]; then
    . "$SILT_DIR/api.sh"
  else
    fatal "structs: SILT is not loaded and SILT_DIR names no library; source .envrc first (ADR 000048)"
  fi
fi
. "$__structs__DIR/$__structs__BACKEND/backend.sh"

# VAR: The register: what the backend's last verb computed. A public verb reads it and answers.
__structs__RESULT=''

:<<'FUN'
Assigns <value> to the variable <name> in the calling shell, the way every
value verb answers: the caller names the variable first, and the verb
prints nothing. A verb clears the variable this way before it runs, so a
verb that fails leaves it empty, never a stale value. Fails, naming it,
when <name> is not a variable name, which is what a call with a document
where the name goes looks like.

  __structs__answer_to x '{"a":1}'
FUN
__structs__answer_to() {
  case "$1" in
    # structs-lint: allow -- a variable name's spelling, checked before an eval
    '' | [0-9]* | *[!A-Za-z0-9_]*)
      fatal "structs: a verb writes its result into the variable named first, and '$1' is not a variable name"
      return 1
      ;;
  esac
  eval "$1=\$2"
}

:<<'FUN'
The value at path $2 of document $1 as text: a string without its quotes,
and any other value as it is written.
FUN
__structs__query_raw() {
  "__structs__${__structs__BACKEND}__query_raw" "$@"
}

:<<'FUN'
The name of the type of the value at path $2 of document $1: object,
array, string, number, boolean or null ("null" when absent).
FUN
__structs__query_type() {
  "__structs__${__structs__BACKEND}__query_type" "$@"
}

:<<'FUN'
The value, as text, at the first of the paths $3... at which document $1
holds a defined value, or the default $2 when none does. Defined is what
@defined answers: not null, not empty, not the text
null. A path that does not apply to the document counts as holding nothing,
and a document that is not itself defined holds nothing at any path, so the
default answers without a backend call.

  __structs__query_first '{"b":2}' d .a .b .c  ->  2
  __structs__query_first '' d .a               ->  d
FUN
__structs__query_first() {
  if ! @defined "$1"; then
    __structs__RESULT="$2"
    return 0
  fi

  "__structs__${__structs__BACKEND}__query_first" "$@"
}

:<<'FUN'
Sets __structs__normalized_path__value to <path> with a bare key wrapped
in quoted-index form (foo -> ."foo"), so keys with hyphens or dots work;
a path already starting with . or [ passes through untouched. A setter,
so a verb that forks nothing reads its path without a subshell.
FUN
__structs__normalized_path() {
  case "$1" in
    .* | '['*) __structs__normalized_path__value="$1" ;;
    *) __structs__normalized_path__value=".\"$1\"" ;;
  esac
}

:<<'FUN'
Prints <path> as __structs__normalized_path spells it.
FUN
__structs__normalize_path() {
  __structs__normalized_path "$1"
  println "$__structs__normalized_path__value"
}

: <<'FUN'
Drops the last path segment, yielding the parent path (root "." when none).
FUN
__structs__parent_path() {
  __structs__parent_path__parent="${1%.*}"
  println "${__structs__parent_path__parent:-.}"
}

:<<'FUN'
Echoes the type at <path> in <json> and returns non-zero unless it matches
<type_rgx>; used to guard mutations against the wrong container type.
FUN
__structs__validate_path_type() {
  __structs__normalized_path "$2"
  __structs__query_type "$1" "$__structs__normalized_path__value" 2>/dev/null
  __structs__validate_path_type__type="$__structs__RESULT"
  __structs__RESULT="$__structs__validate_path_type__type"
  printf '%s' "$__structs__validate_path_type__type" | grep -Eq "$3"
}

:<<'FUN'
Returns 0 when <value> is non-empty and parses as a single JSON value; the
typing predicate behind @set/@push (typed values via --argjson, plain strings
via --arg) and __structs__arg_flag.
FUN
__structs__is_json() {
  "__structs__${__structs__BACKEND}__is_json" "$@"
}

:<<'FUN'
Streams each element of <array>, compact, one JSON value per line.

The iteration verbs capture this once and feed their `while read` loop from a
heredoc rather than a pipe, so the loop body runs in the caller's shell --
callbacks can mutate caller-scope state and `return` from the verb.

A value there is nothing to iterate -- null, a scalar, malformed JSON -- yields
no elements and succeeds, so an absent field is an empty loop rather than an
`errexit` abort in the caller.

Usage: __structs__each "$array"
FUN
__structs__each() {
  "__structs__${__structs__BACKEND}__each" "$@"
}

:<<'DOC'
The byte that precedes every value handed to __structs__collect: RS, the
separator RFC 7464 puts between JSON texts. No callback prints one, so a
value with newlines inside it stays one value. Set once per process: this
file is sourced more than once, and the printf behind it is a fork.
DOC
: "${__structs__RS:=$(printf '\036')}"

:<<'FUN'
Builds a struct array from a run of values, each preceded by __structs__RS,
on whichever backend is live. A value that is one whole JSON text joins the
array as that value and any other joins as a string -- the reading @push
gives its arguments -- so an iteration verb gathers every callback result
first and pays for one backend call instead of one per element. An empty
run is the empty array.

  __structs__collect "$(printf '\036x\036{"a":1}')"  ->  ["x",{"a":1}]

Usage: __structs__collect "$run"
FUN
__structs__collect() {
  "__structs__${__structs__BACKEND}__collect" "$@"
}

:<<'FUN'
Invokes an iteration callback on one element.

Verbs whose callbacks run in the caller's shell route every invocation through
these helpers and hold their own loop state in positional parameters, because a
callback is free to call the same verb again and the nested call overwrites
every global the outer loop owns -- down to the name of the callback itself.
The helpers' own variables survive that, since they are expanded into the
invocation and never read once it returns.

Usage:
  __structs__call "$element" "$callback" [extra_args...]
  __structs__call_indexed "$element" "$index" "$callback" [extra_args...]
FUN
__structs__call() {
  __structs__call__element="$1"
  __structs__call__func="$2"
  shift 2

  "$__structs__call__func" "$__structs__call__element" "$@"
}

__structs__call_indexed() {
  __structs__call_indexed__element="$1"
  __structs__call_indexed__index="$2"
  __structs__call_indexed__func="$3"
  shift 3

  "$__structs__call_indexed__func" "$__structs__call_indexed__element" "$__structs__call_indexed__index" "$@"
}

:<<'PUB_FUN'
Extracts a value from a struct by path, with optional fallback paths.

Usage:
  @get "$struct" '.name'
  @get "$struct" '.name' 'unnamed'
  @get "$struct" '.nodes' '.edges' '[]'

With two args, returns the value at the path (null if missing).
With three or more args, tries each path in order and returns the first
defined result, in one backend call however many paths there are. The last
argument is the fallback default.
PUB_FUN
@get() {
  __structs__get__out="$1"
  __structs__answer_to "$__structs__get__out" '' || return 1
  __structs__get__json="$2"
  shift 2

  if [ $# -eq 1 ]; then
    __structs__normalized_path "$1"
    __structs__query_raw "$__structs__get__json" "$__structs__normalized_path__value" || return $?
    __structs__answer_to "$__structs__get__out" "$__structs__RESULT"
    return
  fi

  # Rotate every path, normalized, behind the default, so "$@" reads as
  # __structs__query_first takes it: the default first, then the paths.
  __structs__get__count=$(($# - 1))
  __structs__get__i=0
  while [ "$__structs__get__i" -lt "$__structs__get__count" ]; do
    __structs__normalized_path "$1"
    set -- "$@" "$__structs__normalized_path__value"
    shift
    __structs__get__i=$((__structs__get__i + 1))
  done

  __structs__query_first "$__structs__get__json" "$@" || return $?
  __structs__answer_to "$__structs__get__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns the value at a path as a struct, with its type: a string keeps its
quotes, an object or an array is returned whole, and a path that holds
nothing gives null. @get answers the text of a value, which loses its type:
the string "12" and the number 12 have the same text. Use @member to carry
a value into @obj, @set or @push as it is.

Usage: @member <result> "$struct" '.name'

  @member x '{"n":"12"}' .n  ->  x="12"
  @get x '{"n":"12"}' .n     ->  x=12
PUB_FUN
@member() {
  __structs__member__out="$1"
  __structs__answer_to "$__structs__member__out" '' || return 1
  shift
  __structs__dispatch member "$@" || return $?
  __structs__answer_to "$__structs__member__out" "$__structs__RESULT"
}

:<<'FUN'
Fails, naming the caller and the offender, when <word> is not a key: one
shell name, or several joined by dots to name a path into the struct. A
key that is not one has no variable to bind; read it with @get.

Usage: __structs__require_key "@let" "$key" || return 1
FUN
__structs__require_key() {
  case "$2" in
    '' | .* | *. | *..* | *[!A-Za-z0-9_.]*)
      fatal "$1: '$2' is not a key: a shell name, or names joined by dots; read it with @get"
      return 1
      ;;
  esac
}

:<<'FUN'
Sets __structs__key_name__value to the variable name <key> binds: its
dot-separated segments joined by underscores.

A setter rather than a printer because @let and @unlet call it once per
key, and a command substitution would fork where neither verb forks at
all.

    __structs__key_name state.type  ->  __structs__key_name__value=state_type
FUN
__structs__key_name() {
  __structs__key_name__rest="$1"
  __structs__key_name__value=""
  while [ "$__structs__key_name__rest" != "${__structs__key_name__rest#*.}" ]; do
    __structs__key_name__value="$__structs__key_name__value${__structs__key_name__rest%%.*}_"
    __structs__key_name__rest="${__structs__key_name__rest#*.}"
  done

  __structs__key_name__value="$__structs__key_name__value$__structs__key_name__rest"
}

:<<'FUN'
Fails, naming the caller and the offender, unless every key of <keys...>
is one __structs__require_key accepts and no two of them name the same
variable, as `a.b` and `a_b` would.

Usage: __structs__require_keys "@let" "$@" || return 1
FUN
__structs__require_keys() {
  __structs__require_keys__who="$1"
  shift

  __structs__require_keys__taken=" "
  for __structs__require_keys__key in "$@"; do
    __structs__require_key "$__structs__require_keys__who" "$__structs__require_keys__key" || return 1
    __structs__key_name "$__structs__require_keys__key"
    __structs__require_keys__unclaimed "$__structs__require_keys__who" || return 1
    __structs__require_keys__taken="$__structs__require_keys__taken$__structs__key_name__value "
  done
}

:<<'FUN'
Fails, naming <who> and the key, when the variable __structs__key_name
last named is one an earlier key of the same call already binds.
FUN
__structs__require_keys__unclaimed() {
  case "$__structs__require_keys__taken" in
    *" $__structs__key_name__value "*)
      fatal "$1: '$__structs__require_keys__key' binds $__structs__key_name__value, which another key of this call already binds"
      return 1
      ;;
  esac
}

:<<'FUN'
Fails, naming the caller and the offender, when <word> cannot begin a shell
variable name: a letter or underscore, then letters, digits and underscores.

Usage: __structs__require_prefix "@let" "$prefix" || return 1
FUN
__structs__require_prefix() {
  case "$2" in
    '' | [0-9]* | *[!A-Za-z0-9_]*)
      fatal "$1: '$2' cannot begin a variable name"
      return 1
      ;;
  esac
}

:<<'PUB_FUN'
Binds fields of a struct to shell variables in one backend call, in the
caller's shell: after it, <prefix><key> holds each key's value. A string
binds as its text, an object or array as compact JSON ready for another
verb, a number or boolean as its text, and an absent or null field as the
empty string. A quote, a newline or a dollar sign in a value binds as
written.

The prefix is the caller's __fn__ so the bindings are namespaced like
every other local, and @unlet releases them for the caller's last line.
Call it as a statement, never inside $(...), or the bindings die with the
subshell.

Keys:
  One shell name, or several joined by dots to reach a path into the
  struct, binding the segments joined by underscores: state.type binds
  <prefix>state_type. A segment missing along the way binds the empty
  string, and however deep the keys go the bind is still one call. The
  prefix must be able to begin a variable name and no two keys may bind
  one variable; anything else is refused by name, and a field so keyed
  is read with @get.

Usage:
  @let "$struct" <prefix> <key>...

  @let "$mr" __hygiene__ title state
  # __hygiene__title and __hygiene__state are set

  @let "$issue" __close__ id state.type
  # __close__id and __close__state_type are set
PUB_FUN
@let() {
  __structs__let__json="$1"
  __structs__let__prefix="$2"
  shift 2

  __structs__require_prefix "@let" "$__structs__let__prefix" || return 1
  __structs__require_keys "@let" "$@" || return 1

  "__structs__${__structs__BACKEND}__let" "$__structs__let__json" "$__structs__let__prefix" "$@"
}

:<<'PUB_FUN'
Releases what @let bound: unsets the variable each key names, in the
caller's shell, as the pair to its @let. The keys are spelled as they were
bound, dotted paths included.

Usage:
  @unlet <prefix> <key>...

  @unlet __hygiene__ title state
  @unlet __close__ id state.type
PUB_FUN
@unlet() {
  __structs__unlet__prefix="$1"
  shift

  __structs__require_prefix "@unlet" "$__structs__unlet__prefix" || return 1
  __structs__require_keys "@unlet" "$@" || return 1

  __structs__unlet__names=""
  for __structs__unlet__key in "$@"; do
    __structs__key_name "$__structs__unlet__key"
    __structs__unlet__names="$__structs__unlet__names $__structs__unlet__prefix$__structs__key_name__value"
  done

  # shellcheck disable=SC2086  # the names are one word each; splitting is the list
  unset $__structs__unlet__names
}

:<<'PUB_FUN'
Decodes a single struct value to raw shell text. Strings are emitted verbatim
(unquoted); by default a structured value prints as @dump prints it.

Typical use: lines from @foreach / @reduce over array elements, where each
string element is still JSON-quoted (e.g. "repo-name" -> repo-name).

An optional options object tunes the output via its "compact" setting (default
false): when true, structured values (objects, arrays) render as compact
single-line JSON while strings still pass through verbatim -- a value's natural
one-line text form, e.g. for dropping into a template.

Usage:
  @unwrap "$fragment"
  @unwrap "$struct" "$(@obj '.compact' true)"
PUB_FUN
@unwrap() {
  __structs__unwrap__out="$1"
  __structs__answer_to "$__structs__unwrap__out" '' || return 1
  shift
  __structs__dispatch unwrap "$@" || return $?
  __structs__answer_to "$__structs__unwrap__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Reads a field coerced to a single scalar string: arrays yield their first
element, strings pass through, null/missing yield "", and anything else is
stringified. Path defaults to the root.

Usage:
  @scalar "$struct"
  @scalar "$struct" '.field'
PUB_FUN
@scalar() {
  __structs__scalar__out="$1"
  __structs__answer_to "$__structs__scalar__out" '' || return 1
  shift
  __structs__dispatch scalar "$@" || return $?
  __structs__answer_to "$__structs__scalar__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Encodes a bash string as a struct string value. Same as @encode_string;
pairs with @unwrap for string round-trips.

Usage: @wrap <result> "$bash_string"
PUB_FUN
@wrap() {
  @encode_string "$1" "$2"
}

:<<'PUB_FUN'
Construct the struct booleans.

Structs owns this representation: @typeof answers "boolean" for them and options
objects already carry them (@obj '.compact' true), so a hand-written
printf 'true' is a struct scalar spelled by hand -- the same leak as the bare []
that @arr replaced.

Usage: @true <result>
       @false
PUB_FUN
@true() {
  __structs__answer_to "$1" true
}

@false() {
  __structs__answer_to "$1" false
}

:<<'PUB_FUN'
Construct the struct null -- the "no value" a record carries on purpose, as
distinct from a field left out. Owned here for the same reason @true/@false
are: a hand-written printf 'null' is a struct scalar spelled by hand.

Usage: @null <result>
PUB_FUN
@null() {
  __structs__answer_to "$1" null
}

:<<'PUB_FUN'
Succeeds when a count is zero. One argument is the value itself; two or more
are a command and its arguments, whose answer is tested, so a test over a
command reads as the verb applied to its answer, the way @succeeds runs one.

Only the struct integer 0 is zero. The empty string, null, and a number
spelled any other way (00, 0.0) fail, as does anything a command prints that
is not exactly 0 -- a nothing is not a zero, and the caller finds that out.

Usage:
  if @is_zero "$status"; then ...
  if @is_zero @len "$packages"; then ...
PUB_FUN
@is_zero() {
  if [ "$#" -gt 1 ]; then
    __structs__is_zero__value="$("$@")"
  else
    __structs__is_zero__value="$1"
  fi

  [ "$__structs__is_zero__value" = 0 ]
}

:<<'PUB_FUN'
Succeeds when <value> is the struct boolean true.

Only that spelling matches. Shell-truthy stand-ins (1, yes, TRUE) fail, as do
false, empty, and null.

Usage: if @is_true "$flag"; then ...
PUB_FUN
@is_true() {
  [ "$1" = true ]
}

:<<'PUB_FUN'
Succeeds when <value> is the struct boolean false.

Only that spelling matches. Shell-falsey stand-ins (0, empty, null) fail, as
does true.

Usage: if @is_false "$flag"; then ...
PUB_FUN
@is_false() {
  [ "$1" = false ]
}

:<<'PUB_FUN'
Prints the struct boolean opposite to <value>.

Strict in the same way @is_true and @is_false are: only those two spellings have
an opposite, and anything else fails rather than being resolved to one of them.
A lax reading would answer true for the empty string, which is the shape an
unset variable arrives in -- the one answer no caller wants to be given
confidently.

Usage: @not <result> "$flag"
PUB_FUN
@not() {
  if @is_true "$2"; then
    __structs__answer_to "$1" false
  elif @is_false "$2"; then
    __structs__answer_to "$1" true
  else
    error "@not: not a struct boolean: $2"
    return 1
  fi
}

:<<'PUB_FUN'
Prints true when the two strings are the same, false otherwise: the shell's
`[ = ]` as a struct boolean, so an equality is a value to store and pass
rather than a status to test and forget.

Usage: @equals <result> "$mode" --json
PUB_FUN
@equals() {
  if [ "$2" = "$3" ]; then
    __structs__answer_to "$1" true
  else
    __structs__answer_to "$1" false
  fi
}

:<<'PUB_FUN'
Prints the struct boolean for whether <command> succeeded.

The bridge for predicates whose answer arrives as an exit status, which per
shell/return-values has to be republished as a value. Without it every such
predicate carries the same five-line if/else.

The command is taken as arguments rather than converted from $? afterwards:
under set -e a failing command aborts before the next line runs, so there is no
status left to read. `[` is an ordinary command, so a test goes straight in.
Stdin passes through, which is what a wrapped filter needs.

Usage:
  @succeeds [ "$(@get "$1" '.type' '')" = DiscussionNote ]
  printf '%s\n' "$text" | @succeeds awk -f is_quoted.awk
PUB_FUN
@succeeds() {
  __structs__succeeds__out="$1"
  __structs__answer_to "$__structs__succeeds__out" '' || return 1
  shift
  if "$@"; then
    __structs__answer_to "$__structs__succeeds__out" true
  else
    __structs__answer_to "$__structs__succeeds__out" false
  fi
}

:<<'PUB_FUN'
Prints the struct boolean for whether <command> failed.

The counterpart of @succeeds for a predicate whose "yes" is the command not
succeeding -- an install check that exits non-zero on drift, a grep -q that
finds nothing. Spelling that with @succeeds leaves the reader negating the
answer at every call site, or the predicate carrying the swapped if/else.
Takes the command as arguments, and passes stdin through, for the same reasons
@succeeds does.

Usage:
  @fails "$repo/agents/install.sh" --check
  printf '%s\n' "$text" | @fails grep -q '^#'
PUB_FUN
@fails() {
  __structs__fails__out="$1"
  __structs__answer_to "$__structs__fails__out" '' || return 1
  shift
  if "$@"; then
    __structs__answer_to "$__structs__fails__out" false
  else
    __structs__answer_to "$__structs__fails__out" true
  fi
}

:<<'PUB_FUN'
Variadic setter.

Usage: @set <result> "$struct" '.<path1>' "val1" '.<path2>' "val2" ...
PUB_FUN
@set() {
  __structs__set__out="$1"
  __structs__answer_to "$__structs__set__out" '' || return 1
  shift
  __structs__dispatch set "$@" || return $?
  __structs__answer_to "$__structs__set__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Variadic setter with PATCH semantics: a supplied value is written, an omitted
one leaves the target's field as it was.

Shell has no way to pass "absent" apart from empty, since an unset variable
expands to "", so an empty value is read as omitted rather than written. Values
are independent, so a pair cannot read one an earlier pair set.

Usage: @patch <result> "$struct" '.<path1>' "val1" '.<path2>' "val2" ...
PUB_FUN
@patch() {
  __structs__patch__out="$1"
  __structs__answer_to "$__structs__patch__out" '' || return 1
  __structs__patch__json="$2"
  shift 2

  while [ "$#" -ge 2 ]; do
    if [ -n "$2" ]; then
      @set __structs__patch__json "$__structs__patch__json" "$1" "$2" || return 1
    fi
    shift 2
  done

  __structs__answer_to "$__structs__patch__out" "$__structs__patch__json"
}

:<<'PUB_FUN'
Construct a struct object from variadic key/value pairs.

Usage: @obj <result> '.<path1>' "val1" '.<path2>' "val2" ...
PUB_FUN
@obj() {
  __structs__obj__out="$1"
  __structs__answer_to "$__structs__obj__out" '' || return 1
  shift
  if [ $# -eq 0 ]; then
    __structs__answer_to "$__structs__obj__out" '{}'
    return
  fi
  @set "$__structs__obj__out" '{}' "$@"
}

:<<'PUB_FUN'
Reads an option from an options object by bare key, falling back to <default>
when the key is absent or null.

This is the reader half of the options-object pattern: callers build an options
object with @obj (e.g. @obj '.arrays' union) and read individual toggles here,
so a verb's switches stay in one named, defaulted place as they grow.

Usage: @option <result> "$opts" "<key>" "<default>"
PUB_FUN
@option() {
  @get "$1" "$2" "$3" "${4:-}"
}

:<<'PUB_FUN'
Predicate for the options-object pattern: succeeds when the option at <key>
equals <value>. An absent or null option never matches.

Usage:
  if @option_is "$opts" arrays union; then ...
PUB_FUN
@option_is() {
  @get __structs__option_is__value "$1" "$2" ""
  [ "$__structs__option_is__value" = "${3:-}" ]
}

:<<'PUB_FUN'
Construct a struct array from variadic elements.

A bare `@arr` is the empty-array constructor, so the zero-argument call is
intended rather than a forgotten "$@" -- hence the SC2120 waiver, which also
silences SC2119 at those call sites.

Usage: @arr <result> "val1" "val2" ...
PUB_FUN
# shellcheck disable=SC2120
@arr() {
  __structs__arr__out="$1"
  __structs__answer_to "$__structs__arr__out" '' || return 1
  shift
  if [ $# -eq 0 ]; then
    __structs__answer_to "$__structs__arr__out" '[]'
    return
  fi
  @push "$__structs__arr__out" '[]' '.' "$@"
}

:<<'PUB_FUN'
Variadic append for struct arrays.

Usage: @push <result> "$struct" '{"a":1}' '{"b":2}' ...
       @push "$struct" '.<path>' '{"a":1}' '{"b":2}' ...

When called with 2 args, appends to the root array.
When called with 3+ args, the second arg is the path.
PUB_FUN
@push() {
  __structs__push__out="$1"
  __structs__answer_to "$__structs__push__out" '' || return 1
  shift
  __structs__dispatch push "$@" || return $?
  __structs__answer_to "$__structs__push__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns the last element of a struct array.

Usage: @last <result> "$array"
PUB_FUN
@last() {
  __structs__last__out="$1"
  __structs__answer_to "$__structs__last__out" '' || return 1
  shift
  __structs__dispatch last "$@" || return $?
  __structs__answer_to "$__structs__last__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns the first element of a struct array.

Usage: @first <result> "$array"
PUB_FUN
@first() {
  __structs__first__out="$1"
  __structs__answer_to "$__structs__first__out" '' || return 1
  shift
  __structs__dispatch first "$@" || return $?
  __structs__answer_to "$__structs__first__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Removes and returns the last element of a struct array.

Outputs two lines: the removed element, then the remaining array.
Capture with: read -r element && read -r rest

Usage:
  { read -r elem; read -r rest; } < <(@pop "$array")
PUB_FUN
@pop() {
  __structs__pop__out="$1"
  __structs__answer_to "$__structs__pop__out" '' || return 1
  shift
  __structs__dispatch pop "$@" || return $?
  __structs__answer_to "$__structs__pop__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Removes and returns the first element of a struct array.

Outputs two lines: the removed element, then the remaining array.

Usage:
  { read -r elem; read -r rest; } < <(@shift "$array")
PUB_FUN
@shift() {
  __structs__shift__out="$1"
  __structs__answer_to "$__structs__shift__out" '' || return 1
  shift
  __structs__dispatch shift "$@" || return $?
  __structs__answer_to "$__structs__shift__out" "$__structs__RESULT"
}

:<<'FUN'
Fatals (returning 1) unless the value's root is of the required type. The
guard a typed verb's backend implementations each run before doing any work,
so both backends refuse the same inputs with the same message.

args:
  $1  The verb name the message speaks as (e.g. @sum)
  $2  The value
  $3  The required root type (array | object)
FUN
__structs__require_root_type() {
  if ! __structs__validate_path_type "$2" "." "^$3\$"; then
    __structs__require_root_type__unexpected="$__structs__RESULT"
    fatal "$1: expected $3, got '$__structs__require_root_type__unexpected'"
    return 1
  fi
}

:<<'FUN'
Fatals (returning 1) unless the value parses as a single struct value. The
validity half of __structs__require_root_type, for verbs that accept any
type but refuse text that is no struct at all.

args:
  $1  The verb name the message speaks as (e.g. @compact)
  $2  The value
FUN
__structs__require_valid() {
  if ! @is_valid "$2"; then
    fatal "$1: invalid struct"
    return 1
  fi
}

:<<'FUN'
Warns when @take asks for more elements than the array holds; the whole
array still comes back.

args:
  $1  The requested element count
  $2  The array's length
FUN
__structs__warn_take_overrun() {
  if [ "$1" -gt "$2" ]; then
    warn "@take: requested $1 elements but array only has $2"
  fi
}

:<<'FUN'
@take's argument checks, shared by both backend implementations: n must be a
non-negative integer and the value an array. Asking past the end only warns
-- the whole array still comes back.

args:
  $1  The array
  $2  The requested element count
FUN
__structs__take_guard() {
  case "$2" in
    '' | *[!0-9]*)
      fatal "@take: n must be a non-negative integer, got '$2'"
      return 1
      ;;
  esac

  __structs__require_root_type "@take" "$1" array || return 1
  @len __structs__take__len "$1"
  __structs__warn_take_overrun "$2" "$__structs__take__len"
}

:<<'PUB_FUN'
Returns the first N elements of a struct array.

If N exceeds the array length, returns the whole array. If N is 0, returns [].

Usage: @take <result> "$array" "$n"
PUB_FUN
@take() {
  __structs__take__out="$1"
  __structs__answer_to "$__structs__take__out" '' || return 1
  shift
  __structs__dispatch take "$@" || return $?
  __structs__answer_to "$__structs__take__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns a struct as JSON over several lines, with two spaces for each
level, for a person to read. @to_json returns the same JSON on one line.

Usage: @dump <result> "$struct"
PUB_FUN
@dump() {
  __structs__dump__out="$1"
  __structs__answer_to "$__structs__dump__out" '' || return 1
  shift
  __structs__dispatch dump "$@" || return $?
  __structs__answer_to "$__structs__dump__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns a struct as one line of JSON, for a value that leaves the process:
the body of a request, a file another program reads, or a line of a log.
@dump returns the same JSON over several lines, for a person to read.

Usage: @to_json <result> "$struct"

  @to_json text "$(@obj '.name' lib '.paths' "$(@arr lib)")"  ->  text={"name":"lib","paths":["lib"]}
PUB_FUN
@to_json() {
  __structs__to_json__out="$1"
  __structs__answer_to "$__structs__to_json__out" '' || return 1
  shift
  __structs__dispatch to_json "$@" || return $?
  __structs__answer_to "$__structs__to_json__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns compact single-line form. Fails if the input is not a valid struct.

Usage: @compact <result> "$struct"
PUB_FUN
@compact() {
  __structs__compact__out="$1"
  __structs__answer_to "$__structs__compact__out" '' || return 1
  shift
  __structs__dispatch compact "$@" || return $?
  __structs__answer_to "$__structs__compact__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Maps a bash function over each element of a struct array, returning a new array.

Usage: @map <result> callback_func "$array" [extra_args...]

  Callback signature:
    callback "$element" [extra_args...] -> transformed element
PUB_FUN
@map() {
  __structs__map__out="$1"
  __structs__answer_to "$__structs__map__out" '' || return 1
  shift
  __structs__map__func="$1"
  __structs__each "$2" || return $?
  __structs__map__each="$__structs__RESULT"
  shift 2

  __structs__map__run=""
  while IFS= read -r __structs__map__element; do
    [ -n "$__structs__map__element" ] || continue
    __structs__map__transformed="$("$__structs__map__func" "$__structs__map__element" "$@")"
    __structs__map__run="${__structs__map__run}${__structs__RS}${__structs__map__transformed}"
  done <<EOF
$__structs__map__each
EOF

  __structs__collect "$__structs__map__run" || return $?
  __structs__answer_to "$__structs__map__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Like @map, but passes the element index to the callback.

Usage: @mapi <result> callback_func "$array" [extra_args...]

  Callback signature:
    callback "$element" "$index" [extra_args...] -> transformed element
PUB_FUN
@mapi() {
  __structs__mapi__out="$1"
  __structs__answer_to "$__structs__mapi__out" '' || return 1
  shift
  __structs__mapi__func="$1"
  __structs__each "$2" || return $?
  __structs__mapi__each="$__structs__RESULT"
  shift 2

  __structs__mapi__run=""
  __structs__mapi__index=0
  while IFS= read -r __structs__mapi__element; do
    [ -n "$__structs__mapi__element" ] || continue
    __structs__mapi__transformed="$("$__structs__mapi__func" "$__structs__mapi__element" "$__structs__mapi__index" "$@")"
    __structs__mapi__run="${__structs__mapi__run}${__structs__RS}${__structs__mapi__transformed}"
    __structs__mapi__index=$((__structs__mapi__index + 1))
  done <<EOF
$__structs__mapi__each
EOF

  __structs__collect "$__structs__mapi__run" || return $?
  __structs__answer_to "$__structs__mapi__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Reduces a struct array through a bash function, threading an accumulator.

Usage: @reduce <result> callback_func "$array" [initial_accumulator] [extra_args...]

  Callback signature:
    callback "$accumulator" "$element" [extra_args...] -> new accumulator

  Omitting the accumulator seeds it with an empty array. A reduce that folds
  into an object passes "$(@obj)" instead.
PUB_FUN
@reduce() {
  __structs__reduce__out="$1"
  __structs__answer_to "$__structs__reduce__out" '' || return 1
  shift
  __structs__reduce__func="$1"
  __structs__each "$2" || return $?
  __structs__reduce__each="$__structs__RESULT"
  __structs__reduce__accumulator="${3:-[]}"
  shift 3 2>/dev/null || shift $#

  while IFS= read -r __structs__reduce__element; do
    [ -n "$__structs__reduce__element" ] || continue
    __structs__reduce__accumulator="$("$__structs__reduce__func" "$__structs__reduce__accumulator" "$__structs__reduce__element" "$@")"
  done <<EOF
$__structs__reduce__each
EOF

  __structs__answer_to "$__structs__reduce__out" "$__structs__reduce__accumulator"
}

:<<'PUB_FUN'
Like @reduce, but passes the element index to the callback.

Usage: @reducei <result> callback_func "$array" [initial_accumulator] [extra_args...]

  Callback signature:
    callback "$accumulator" "$element" "$index" [extra_args...] -> new accumulator

  Omitting the accumulator seeds it with an empty array. A reduce that folds
  into an object passes "$(@obj)" instead.
PUB_FUN
@reducei() {
  __structs__reducei__out="$1"
  __structs__answer_to "$__structs__reducei__out" '' || return 1
  shift
  __structs__reducei__func="$1"
  __structs__each "$2" || return $?
  __structs__reducei__each="$__structs__RESULT"
  __structs__reducei__accumulator="${3:-[]}"
  shift 3 2>/dev/null || shift $#

  __structs__reducei__index=0
  while IFS= read -r __structs__reducei__element; do
    [ -n "$__structs__reducei__element" ] || continue
    __structs__reducei__accumulator="$("$__structs__reducei__func" "$__structs__reducei__accumulator" "$__structs__reducei__element" "$__structs__reducei__index" "$@")"
    __structs__reducei__index=$((__structs__reducei__index + 1))
  done <<EOF
$__structs__reducei__each
EOF

  __structs__answer_to "$__structs__reducei__out" "$__structs__reducei__accumulator"
}

:<<'PUB_FUN'
Runs a command with the elements of a struct string array appended to its
arguments, and returns the command's own status.

Unlike @foreach, the command runs once, seeing the whole array as argv --
what a command that takes a variable file list wants.

Usage: @apply command [fixed_args...] "$array"

  @apply git add -- "$files"
runs: git add -- <element>...
PUB_FUN
@apply() {
  for __structs__apply__array in "$@"; do :; done

  # Rotate argv so the array (its last argument) drops off the front,
  # leaving the command and its fixed arguments in order.
  __structs__apply__fixed=$(($# - 1))
  __structs__apply__i=0
  while [ "$__structs__apply__i" -lt "$__structs__apply__fixed" ]; do
    set -- "$@" "$1"
    shift
    __structs__apply__i=$((__structs__apply__i + 1))
  done
  shift

  @len __structs__apply__length "$__structs__apply__array"
  __structs__apply__i=0
  while [ "$__structs__apply__i" -lt "$__structs__apply__length" ]; do
    @get __structs__apply__element "$__structs__apply__array" ".[$__structs__apply__i]"
    set -- "$@" "$__structs__apply__element"
    __structs__apply__i=$((__structs__apply__i + 1))
  done

  "$@"
}

:<<'PUB_FUN'
Prints each element of the struct array <array> as its own line, as println
prints each argument. A string prints as its text, a number or boolean as
its literal; an empty array prints nothing.

  @arr x ready set; @println "$x"  ->  ready
                                    set

Usage: @println "$array"
PUB_FUN
@println() {
  if @empty "$1"; then
    return 0
  fi
  @join __structs__println__text "$1" "$__structs__NL"
  println "$__structs__println__text"
}

:<<'PUB_FUN'
Iterates a struct array, calling a bash function for each element.

Unlike @map, this does not collect results -- use for side-effectful operations.

Usage: @foreach callback_func "$array" [extra_args...]

  Callback signature:
    callback "$element" [extra_args...]
PUB_FUN
@foreach() {
  __structs__foreach__func="$1"
  __structs__each "$2" || return $?
  __structs__foreach__each="$__structs__RESULT"
  shift 2
  # $1 is the callback, $2... the extra args, held here so a nested @foreach
  # cannot take them out from under the loop.
  set -- "$__structs__foreach__func" "$@"

  # A failing callback stops iteration and propagates its status.
  __structs__foreach__rc=0
  while IFS= read -r __structs__foreach__element; do
    [ -n "$__structs__foreach__element" ] || continue
    __structs__call "$__structs__foreach__element" "$@"
    __structs__foreach__rc=$?
    [ "$__structs__foreach__rc" -eq 0 ] || break
  done <<EOF
$__structs__foreach__each
EOF

  return "$__structs__foreach__rc"
}

:<<'PUB_FUN'
Like @foreach, but passes the element index to the callback.

Usage: @foreachi callback_func "$array" [extra_args...]

  Callback signature:
    callback "$element" "$index" [extra_args...]
PUB_FUN
@foreachi() {
  __structs__foreachi__func="$1"
  __structs__each "$2" || return $?
  __structs__foreachi__each="$__structs__RESULT"
  shift 2
  # $1 is the current element and $2 its index, rotated once per iteration
  # because the count has to outlive a callback that iterates in turn. $3 is
  # the callback, $4... the extra args.
  set -- "" -1 "$__structs__foreachi__func" "$@"

  while IFS= read -r __structs__foreachi__element; do
    [ -n "$__structs__foreachi__element" ] || continue
    __structs__foreachi__index=$(($2 + 1))
    shift 2
    set -- "$__structs__foreachi__element" "$__structs__foreachi__index" "$@"
    __structs__call_indexed "$@"
  done <<EOF
$__structs__foreachi__each
EOF
}

:<<'FUN'
Keeps the name of the variable a searching verb <verb> answers into, for
the call now running, apart from the names of the calls above it: a
callback that runs the same verb again must not take the outer call's name
with it. Paired with __structs__release_out.

  __structs__hold_out find x
FUN
__structs__hold_out() {
  eval "__structs__hold_out__depth=\$((\${__structs__${1}__DEPTH:-0} + 1))"
  eval "__structs__${1}__DEPTH=$__structs__hold_out__depth"
  eval "__structs__${1}__out_$__structs__hold_out__depth=\$2"
}

:<<'FUN'
Answers <value> into the variable __structs__hold_out kept for the call of
<verb> now ending, and forgets the name.

  __structs__release_out find 4
FUN
__structs__release_out() {
  eval "__structs__release_out__depth=\$__structs__${1}__DEPTH"
  eval "__structs__release_out__name=\$__structs__${1}__out_$__structs__release_out__depth"
  eval "__structs__${1}__DEPTH=\$((__structs__release_out__depth - 1))"
  __structs__answer_to "$__structs__release_out__name" "$2"
}

:<<'PUB_FUN'
Returns the first element of a struct array where the callback returns 0 (true).

Usage: @find <result> callback_func "$array" [extra_args...]

  Callback signature:
    callback "$element" [extra_args...] -> return 0 for match, non-zero to skip

  Returns the matching element, or "null" if none matched.
PUB_FUN
@find() {
  __structs__find__out="$1"
  __structs__answer_to "$__structs__find__out" '' || return 1
  shift
  __structs__find__func="$1"
  __structs__each "$2" || return $?
  __structs__find__each="$__structs__RESULT"
  shift 2
  # $1 holds the current element, and so the match once the loop breaks on one;
  # it has to outlive a callback that searches in turn. $2 is the callback,
  # $3... the extra args.
  __structs__hold_out find "$__structs__find__out"
  set -- "null" "$__structs__find__func" "$@"

  while IFS= read -r __structs__find__element; do
    [ -n "$__structs__find__element" ] || continue
    shift
    set -- "$__structs__find__element" "$@"
    __structs__call "$@" && break
    shift
    set -- "null" "$@"
  done <<EOF
$__structs__find__each
EOF

  __structs__release_out find "$1"
}

:<<'PUB_FUN'
Like @find, but passes the element index to the callback.

Usage: @findi <result> callback_func "$array" [extra_args...]

  Callback signature:
    callback "$element" "$index" [extra_args...] -> return 0 for match, non-zero to skip

  Returns the matching element, or "null" if none matched.
PUB_FUN
@findi() {
  __structs__findi__out="$1"
  __structs__answer_to "$__structs__findi__out" '' || return 1
  shift
  __structs__findi__func="$1"
  __structs__each "$2" || return $?
  __structs__findi__each="$__structs__RESULT"
  shift 2
  # $1 holds the current element, and so the match once the loop breaks on one,
  # with its index in $2; both have to outlive a callback that searches in
  # turn. $3 is the callback, $4... the extra args.
  __structs__hold_out findi "$__structs__findi__out"
  set -- "null" -1 "$__structs__findi__func" "$@"

  while IFS= read -r __structs__findi__element; do
    [ -n "$__structs__findi__element" ] || continue
    __structs__findi__index=$(($2 + 1))
    shift 2
    set -- "$__structs__findi__element" "$__structs__findi__index" "$@"
    __structs__call_indexed "$@" && break
    shift
    set -- "null" "$@"
  done <<EOF
$__structs__findi__each
EOF

  __structs__release_out findi "$1"
}

:<<'PUB_FUN'
Prints the struct boolean for whether the callback returns 0 (true) for at
least one element of a struct array. An empty array answers false.

Usage: @any <result> callback_func "$array" [extra_args...]

  Callback signature:
    callback "$element" [extra_args...] -> return 0 for match, non-zero to skip
PUB_FUN
@any() {
  __structs__any__out="$1"
  __structs__answer_to "$__structs__any__out" '' || return 1
  shift
  __structs__any__func="$1"
  __structs__each "$2" || return $?
  __structs__any__each="$__structs__RESULT"
  shift 2
  __structs__hold_out any "$__structs__any__out"
  set -- "$__structs__any__func" "$@"

  while IFS= read -r __structs__any__element; do
    [ -n "$__structs__any__element" ] || continue
    if __structs__call "$__structs__any__element" "$@"; then
      __structs__release_out any true
      return
    fi
  done <<EOF
$__structs__any__each
EOF

  __structs__release_out any false
}

:<<'PUB_FUN'
Prints the struct boolean for whether the callback returns 0 (true) for every
element of a struct array. An empty array answers true.

Usage: @all <result> callback_func "$array" [extra_args...]

  Callback signature:
    callback "$element" [extra_args...] -> return 0 for match, non-zero to skip
PUB_FUN
@all() {
  __structs__all__out="$1"
  __structs__answer_to "$__structs__all__out" '' || return 1
  shift
  __structs__all__func="$1"
  __structs__each "$2" || return $?
  __structs__all__each="$__structs__RESULT"
  shift 2
  __structs__hold_out all "$__structs__all__out"
  set -- "$__structs__all__func" "$@"

  while IFS= read -r __structs__all__element; do
    [ -n "$__structs__all__element" ] || continue
    if ! __structs__call "$__structs__all__element" "$@"; then
      __structs__release_out all false
      return
    fi
  done <<EOF
$__structs__all__each
EOF

  __structs__release_out all true
}

:<<'PUB_FUN'
Extracts a single field from each element of a struct array.

Usage: @pluck <result> "$array" '.name'
       @pluck "$array" '.user.id'
PUB_FUN
@pluck() {
  __structs__pluck__out="$1"
  __structs__answer_to "$__structs__pluck__out" '' || return 1
  shift
  __structs__dispatch pluck "$@" || return $?
  __structs__answer_to "$__structs__pluck__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns each element of a struct array as an object of the members that
the constructor names.

Usage: @project <result> "$array" "{name, color, description}"
PUB_FUN
@project() {
  __structs__project__out="$1"
  __structs__answer_to "$__structs__project__out" '' || return 1
  shift
  __structs__dispatch project "$@" || return $?
  __structs__answer_to "$__structs__project__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Sums numeric values in a struct array. Returns 0 for empty arrays.

Usage: @sum <result> "$array"
       @sum "$(@pluck "$objects" '.score')"
PUB_FUN
@sum() {
  __structs__sum__out="$1"
  __structs__answer_to "$__structs__sum__out" '' || return 1
  shift
  __structs__dispatch sum "$@" || return $?
  __structs__answer_to "$__structs__sum__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Filters a struct array or object, keeping the members a predicate answers
true for (ADR.35@strata). The predicate is a function. @filter calls it with
the name of the variable to answer in, the member's key, the member's value
and the extra arguments, and it assigns true or false to that variable.
SILT provides the common predicates:

  silt__text_is <path> <text>              the text at the path is the text
  silt__text_is_not <path> <text>          the text at the path differs
  silt__text_starts_with <path> <prefix>   the text at the path starts so

Usage: @filter <result> "$reviews" silt__text_is .state merged
       @filter <result> "$names" silt__text_is_not . ''
       @filter <result> "$rows" my_module__is_stale "$cutoff"
PUB_FUN
@filter() {
  __structs__answer_to "$1" '' || return 1

  if ! command -v "${3:-}" >/dev/null 2>&1; then
    fatal "@filter: '${3:-}' is not a function. The third argument is a predicate, such as silt__text_is."
    return 1
  fi
  __structs__filter__by_predicate "$@"
}

:<<'FUN'
The half of @filter that takes a predicate function: runs the backend's
filter and answers its result into <result>. A predicate may call @filter
itself.

Usage: __structs__filter__by_predicate <result> "$array" <predicate> [extras...]
FUN
__structs__filter__by_predicate() {
  __structs__hold_out filter "$1"
  shift

  __structs__RESULT=''
  __structs__filter__by_predicate__status=0
  __structs__dispatch filter "$@" || __structs__filter__by_predicate__status=$?
  __structs__release_out filter "$__structs__RESULT"

  return "$__structs__filter__by_predicate__status"
}

:<<'PUB_FUN'
Returns elements present in both struct arrays.

Usage: @intersect <result> "$array_a" "$array_b"
PUB_FUN
@intersect() {
  __structs__intersect__out="$1"
  __structs__answer_to "$__structs__intersect__out" '' || return 1
  shift
  __structs__dispatch intersect "$@" || return $?
  __structs__answer_to "$__structs__intersect__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns elements in the first struct array that are not in the second.

Usage: @difference <result> "$array_a" "$array_b"
PUB_FUN
@difference() {
  __structs__difference__out="$1"
  __structs__answer_to "$__structs__difference__out" '' || return 1
  shift
  __structs__dispatch difference "$@" || return $?
  __structs__answer_to "$__structs__difference__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Concatenates two struct arrays.

Usage: @concat <result> "$array_a" "$array_b"
PUB_FUN
@concat() {
  __structs__concat__out="$1"
  __structs__answer_to "$__structs__concat__out" '' || return 1
  shift
  __structs__dispatch concat "$@" || return $?
  __structs__answer_to "$__structs__concat__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns a struct array with each element once, in the order @sort_by gives
them.

Usage: @unique <result> "$array"
PUB_FUN
@unique() {
  __structs__unique__out="$1"
  __structs__answer_to "$__structs__unique__out" '' || return 1
  shift
  __structs__dispatch unique "$@" || return $?
  __structs__answer_to "$__structs__unique__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Orders a struct array by the value at a path inside each element. Given
several paths, orders by the value at the first path, and orders the
elements that tie there by the value at the next. Given no path, orders by
the elements themselves. Elements that tie at every path keep their order.

Values are ordered by kind first: a null or a path that holds nothing, then
false, then true, then a number, then a string. Fails when the value at a
path is an object or an array.

Usage: @sort_by <result> "$array" '.created_at'
       @sort_by <result> "$queue" '.ready_at' '.iid'
       @sort_by <result> "$names"
PUB_FUN
@sort_by() {
  __structs__sort_by__out="$1"
  __structs__answer_to "$__structs__sort_by__out" '' || return 1
  shift
  __structs__dispatch sort_by "$@" || return $?
  __structs__answer_to "$__structs__sort_by__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Groups the elements of a struct array: returns an array of arrays, one for
each distinct value at the path, holding the elements that have that value
in their order. The groups are in the order @sort_by gives those values.
Given several paths, two elements are in the same group when their values
are the same at every path. Given no path, the elements themselves are
compared.

Usage: @group_by <result> "$rows" '.suite'

  @group_by x '["b","a","b"]'  ->  x=[["a"],["b","b"]]
PUB_FUN
@group_by() {
  __structs__group_by__out="$1"
  __structs__answer_to "$__structs__group_by__out" '' || return 1
  shift
  __structs__dispatch group_by "$@" || return $?
  __structs__answer_to "$__structs__group_by__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns the element of a struct array that @sort_by orders first, or null
for an empty array. Of several elements that tie, returns the first.

Usage: @min <result> "$numbers"
       @min <result> "$shards" '.run.started_at'
PUB_FUN
@min() {
  __structs__min__out="$1"
  __structs__answer_to "$__structs__min__out" '' || return 1
  shift
  __structs__dispatch min "$@" || return $?
  __structs__answer_to "$__structs__min__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns the element of a struct array that @sort_by orders last, or null
for an empty array. Of several elements that tie, returns the last.

Usage: @max <result> "$numbers"
       @max <result> "$areas" '.length'
PUB_FUN
@max() {
  __structs__max__out="$1"
  __structs__answer_to "$__structs__max__out" '' || return 1
  shift
  __structs__dispatch max "$@" || return $?
  __structs__answer_to "$__structs__max__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Builds a struct object from an array of its keys and values, the reverse of
@entries. Each element is an object with the member's key under "key" and
its value under "value". When two elements have the same key, the member
has the value of the last.

Usage: @from_entries <result> "$entries"

  @from_entries x '[{"key":"a","value":1}]'  ->  x={"a":1}
PUB_FUN
@from_entries() {
  __structs__from_entries__out="$1"
  __structs__answer_to "$__structs__from_entries__out" '' || return 1
  shift
  __structs__dispatch from_entries "$@" || return $?
  __structs__answer_to "$__structs__from_entries__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns a struct object with only the members under the keys given, in the
object's own order. A key that the object does not have is left out.

Usage: @pick <result> "$object" <key>...

  @pick x '{"title":"t","token":"s","body":"b"}' title body  ->  x={"title":"t","body":"b"}
PUB_FUN
@pick() {
  __structs__pick__out="$1"
  __structs__answer_to "$__structs__pick__out" '' || return 1
  shift
  __structs__dispatch pick "$@" || return $?
  __structs__answer_to "$__structs__pick__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns a struct object without the members under the keys given. Use it to
take a secret out of an object before the object is logged.

Usage: @without <result> "$object" <key>...

  @without x '{"title":"t","token":"s"}' token  ->  x={"title":"t"}
PUB_FUN
@without() {
  __structs__without__out="$1"
  __structs__answer_to "$__structs__without__out" '' || return 1
  shift
  __structs__dispatch without "$@" || return $?
  __structs__answer_to "$__structs__without__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Shallow-merges two struct objects. Right-side wins on key conflicts.

An optional options object tunes how same-key arrays combine via its "arrays"
setting ("replace" (default) | "concat" | "union"); omit it for right-wins.

Usage:
  @merge "$object_a" "$object_b"
  @merge "$object_a" "$object_b" "$(@obj '.arrays' union)"
PUB_FUN
@merge() {
  __structs__merge__out="$1"
  __structs__answer_to "$__structs__merge__out" '' || return 1
  shift
  __structs__dispatch merge "$@" || return $?
  __structs__answer_to "$__structs__merge__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Recursively merges two struct objects: nested objects are merged, while
right-side scalars win.

An optional options object tunes how same-key arrays combine via its "arrays"
setting ("replace" (default) | "concat" | "union"), at any nesting depth.

Usage:
  @deepmerge "$object_a" "$object_b"
  @deepmerge "$object_a" "$object_b" "$(@obj '.arrays' union)"
PUB_FUN
@deepmerge() {
  __structs__deepmerge__out="$1"
  __structs__answer_to "$__structs__deepmerge__out" '' || return 1
  shift
  __structs__dispatch deepmerge "$@" || return $?
  __structs__answer_to "$__structs__deepmerge__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Converts a struct object into an array of {key, value} entries.

Usage: @entries <result> "$object"

Returns: [{"key":"k1","value":"v1"}, ...]
PUB_FUN
@entries() {
  __structs__entries__out="$1"
  __structs__answer_to "$__structs__entries__out" '' || return 1
  shift
  __structs__dispatch entries "$@" || return $?
  __structs__answer_to "$__structs__entries__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns a struct array of an object's keys (sorted), or an array's indices.

Usage: @keys <result> "$object"
PUB_FUN
@keys() {
  __structs__keys__out="$1"
  __structs__answer_to "$__structs__keys__out" '' || return 1
  shift
  __structs__dispatch keys "$@" || return $?
  __structs__answer_to "$__structs__keys__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Flattens a nested tree object -- name -> node where a node may nest a child tree
under <child-key> -- into a flat map keyed by the dot-joined path from the root
("lib", "lib.areas", "engine.ast"). Each value is its node with the child key
removed; parents precede their descendants. The dotted keys carry the ancestry,
so a caller resolves any inheritance from them. The separator defaults to ".".

Usage:
  @flatten "$tree" "areas"
  @flatten "$tree" "children" "/"
PUB_FUN
@flatten() {
  __structs__flatten__out="$1"
  __structs__answer_to "$__structs__flatten__out" '' || return 1
  shift
  __structs__dispatch flatten "$@" || return $?
  __structs__answer_to "$__structs__flatten__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns a struct array of an object's values (or an array's elements).

Usage: @values <result> "$object"
PUB_FUN
@values() {
  __structs__values__out="$1"
  __structs__answer_to "$__structs__values__out" '' || return 1
  shift
  __structs__dispatch values "$@" || return $?
  __structs__answer_to "$__structs__values__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Joins the elements of a struct array into one string, with a separator
between them.

Usage: @join <result> "$array" ", "
PUB_FUN
@join() {
  __structs__join__out="$1"
  __structs__answer_to "$__structs__join__out" '' || return 1
  shift
  __structs__dispatch join "$@" || return $?
  __structs__answer_to "$__structs__join__out" "$__structs__RESULT"
}

:<<'FUN'
Resolves @split's optional delimiter argument into
__structs__split_delimiter__result: the argument itself, or a lone newline
when omitted or empty. The answer travels by variable because command
substitution would eat the very newline being handed back.
FUN
__structs__split_delimiter() {
  __structs__split_delimiter__result="${1-}"

  if [ -z "$__structs__split_delimiter__result" ]; then
    # POSIX sh has no $'\n'; synthesize a lone newline without embedding one in
    # source: printf a newline plus a sentinel, then strip the sentinel (command
    # substitution would otherwise eat the trailing newline).
    __structs__split_delimiter__result="$(printf '\n_')"
    __structs__split_delimiter__result="${__structs__split_delimiter__result%_}"
  fi
}

:<<'PUB_FUN'
Splits a string on a delimiter and returns a struct string array.
Defaults to newline if no delimiter is given.

Usage: @split <result> "$lines"
       @split "a,b,c" ","
PUB_FUN
@split() {
  __structs__split__out="$1"
  __structs__answer_to "$__structs__split__out" '' || return 1
  shift
  __structs__dispatch split "$@" || return $?
  __structs__answer_to "$__structs__split__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns the type of a value at the given path.

Usage: @typeof <result> "$struct"
       @typeof "$struct" '.field'

Returns one of: object, array, string, number, boolean, null
PUB_FUN
@typeof() {
  __structs__typeof__out="$1"
  __structs__answer_to "$__structs__typeof__out" '' || return 1
  shift
  __structs__normalized_path "${2:-.}"
  __structs__query_type "$1" "$__structs__normalized_path__value" || return $?
  __structs__answer_to "$__structs__typeof__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns 0 if the string parses as a single valid struct value (object, array,
string, number, boolean, or null). Returns 1 on parse failure.

A root `null` is a valid struct value.

Usage: @is_valid "$string"
PUB_FUN
@is_valid() {
  __structs__dispatch is_valid "$@"
}

:<<'PUB_FUN'
Parses a struct from text that may be wrapped in a markdown code fence: trims
whitespace, tries to parse directly, then strips one fence (``` or ```lang ...)
and parses the inner body. Prints compact output on success.

Inverse of @to_codeblock for well-formed inputs.

Fails if no valid struct value remains after normalization.

Usage: @from_codeblock <result> "$text"
PUB_FUN
@from_codeblock() {
  __structs__answer_to "$1" '' || return 1
  if @compact __structs__from_codeblock__struct "$2" 2>/dev/null; then
    __structs__answer_to "$1" "$__structs__from_codeblock__struct"
    return 0
  fi

  __structs__from_codeblock__body="$(println "$2" | awk -f "$__structs__DIR/code_block_body.awk")" || return $?
  @compact __structs__from_codeblock__struct "$__structs__from_codeblock__body" || return $?
  __structs__answer_to "$1" "$__structs__from_codeblock__struct"
}

:<<'PUB_FUN'
Parses a struct from yaml text, the compact struct every other verb takes.
The yaml is read through yq, which ops.lock provisions.

Fails when the text is not yaml.

Usage: @from_yaml <result> "$text"
PUB_FUN
@from_yaml() {
  __structs__answer_to "$1" '' || return 1
  __structs__from_yaml__json="$(println "$2" | yq -o=json -I0 '.')" || return $?
  __structs__answer_to "$1" "$__structs__from_yaml__json"
}

:<<'PUB_FUN'
Prints a struct as YAML, the inverse of @from_yaml, for a file a person
reads and edits. The YAML is written through yq, which ops.lock provisions,
the same program @from_yaml reads with.

Usage: @to_yaml <result> "$struct"
PUB_FUN
@to_yaml() {
  __structs__answer_to "$1" '' || return 1
  __structs__json_of "$2"
  __structs__to_yaml__text="$(println "$__structs__json_of__text" | yq -p=json -o=yaml '.')" || return $?
  __structs__answer_to "$1" "$__structs__to_yaml__text"
}

:<<'FUN'
Sets __structs__json_of__text to the struct <value> as JSON text, which is
what another tool, such as yq, reads: the backend translates its
own document form when its fragment defines __structs__<backend>__as_json,
and a value that is JSON already stays as it is.

  __structs__json_of '0."a":int=1'  ->  __structs__json_of__text={"a":1}
FUN
__structs__json_of() {
  if command -v "__structs__${__structs__BACKEND}__as_json" >/dev/null 2>&1; then
    "__structs__${__structs__BACKEND}__as_json" "$1"
    eval "__structs__json_of__text=\$__structs__${__structs__BACKEND}__as_json__text"
  else
    __structs__json_of__text="$1"
  fi
}

:<<'PUB_FUN'
Wraps a valid struct in a markdown fenced block. Pretty-prints before wrapping.
Fails if the input is not a valid struct.

Optional second argument is the fence language tag (default when omitted:
json). Pass "" as the second argument for an opening fence with no language.

Usage: @to_codeblock <result> "$struct"
       @to_codeblock "$struct" "yaml"
       @to_codeblock "$struct" ""
PUB_FUN
@to_codeblock() {
  __structs__to_codeblock__out="$1"
  __structs__answer_to "$__structs__to_codeblock__out" '' || return 1
  __structs__to_codeblock__lang="${3-json}"
  @dump __structs__to_codeblock__formatted "$2" || return 1
  if [ -n "$__structs__to_codeblock__lang" ]; then
    __structs__to_codeblock__text="\`\`\`$__structs__to_codeblock__lang$__structs__NL$__structs__to_codeblock__formatted$__structs__NL\`\`\`"
  else
    __structs__to_codeblock__text="\`\`\`$__structs__NL$__structs__to_codeblock__formatted$__structs__NL\`\`\`"
  fi
  __structs__answer_to "$__structs__to_codeblock__out" "$__structs__to_codeblock__text"
}

:<<'PUB_FUN'
Reads a JSON file from disk, validates it against a JSON Schema file, and echoes
the struct as compact JSON. Returns non-zero when the file is missing, the
content is not valid JSON, or schema validation fails.

Usage: @load <result> "$data_file" "$schema_file"
PUB_FUN
@load() {
  __structs__load__out="$1"
  __structs__answer_to "$__structs__load__out" '' || return 1
  __structs__load__data_file="$2"
  __structs__load__schema_file="$3"

  if [ ! -f "$__structs__load__data_file" ]; then
    error "@load: data file not found: $__structs__load__data_file"
    return 1
  fi

  __structs__load__json="$(cat "$__structs__load__data_file")" || return 1

  if ! @is_valid "$__structs__load__json"; then
    error "@load: invalid JSON in $__structs__load__data_file"
    return 1
  fi

  @validate "$__structs__load__json" "$__structs__load__schema_file" || return 1

  @compact "$__structs__load__out" "$__structs__load__json"
}

:<<'PUB_FUN'
Validates a struct value against a JSON Schema file. Cross-document $refs in
the schema resolve against files relative to the schema file's directory.
Returns 0 on success, 1 on failure with every validation error on stderr, one
per line, so a malformed value can be fixed in one pass rather than one
error at a time. A document of any size validates.

Usage: @validate "$struct" "$schema_file"
PUB_FUN
@validate() {
  __structs__dispatch validate "$@"
}

:<<'PUB_FUN'
Encodes a bash string as a struct string value (quoted, escaped). @wrap
delegates here.

Usage: @encode_string <result> "$bash_string"
PUB_FUN
@encode_string() {
  __structs__encode_string__out="$1"
  __structs__answer_to "$__structs__encode_string__out" '' || return 1
  shift
  __structs__dispatch encode_string "$@" || return $?
  __structs__answer_to "$__structs__encode_string__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Returns true (0) if the value is neither "null" nor empty.

Usage: @defined "$value"
PUB_FUN
@defined() {
  [ "$1" != "null" ] && [ -n "$1" ]
}

:<<'PUB_FUN'
Succeeds when a struct array or object has no elements. Reads as a sentence at
the call site, where the length compared with 0 does not:

  if @empty "$packages"; then

Only a collection can be empty: null, a scalar, or a bash string that is not a
struct is a type error, reported and returned as 2, so an absent value never
passes for an empty one.

Usage: @empty "$struct"
PUB_FUN
@empty() {
  @typeof __structs__empty__type "$1"
  case "$__structs__empty__type" in
    array|object)
      @len __structs__empty__len "$1"
      [ "$__structs__empty__len" -eq 0 ]
      ;;
    *)
      error "@empty: not a struct array or object: '$1'"
      return 2
      ;;
  esac
}

:<<'PUB_FUN'
Returns the length of a struct array, object (key count), or string.

Usage: @len <result> "$struct"
PUB_FUN
@len() {
  __structs__len__out="$1"
  __structs__answer_to "$__structs__len__out" '' || return 1
  shift
  __structs__dispatch len "$@" || return $?
  __structs__answer_to "$__structs__len__out" "$__structs__RESULT"
}

:<<'PUB_FUN'
Runs awk program $1 over stdin with the structs JSON runtime loaded ahead of
it, so a program that emits JSON spells a string with json_encode_string the
way structs does and the two never disagree on an escape. Extra arguments
reach awk as they are, so a -v assignment or an input file may follow.

Usage:
  @awk "$program_file" < input
  @awk "$program_file" -v name=value < input
PUB_FUN
@awk() {
  __structs__awk__out="$1"
  __structs__answer_to "$__structs__awk__out" '' || return 1
  __structs__AWK_RUN_PROGRAM="$2"
  shift 2
  __structs__awk__result="$(awk \
    -f "$__structs__DIR/awk/runtime.awk" \
    -f "$__structs__DIR/awk/nodes.awk" \
    -f "$__structs__DIR/awk/parse.awk" \
    -f "$__structs__DIR/awk/serialize.awk" \
    -f "$__structs__DIR/awk/paths.awk" \
    -f "$__structs__DIR/awk/ops.awk" \
    -f "$__structs__AWK_RUN_PROGRAM" \
    "$@")" || return $?
  __structs__answer_to "$__structs__awk__out" "$__structs__awk__result"
}

:<<'PUB_FUN'
Runs an awk program over a struct in one process, and returns what the
program prints: a struct, or plain text. Use it for a transformation that
loops over the members of a struct, where a callback for each member would
start a process for each.

The program reads the struct as a tree of nodes, through the functions of
SILT's tree.awk, which silt__run loads ahead of it with SILT's line library
(strata, shell/silt/awk). It prints its answer as SILT lines. A struct given
with --with is read ahead of the main one, with tree_ahead(). A value given
with --arg is read with arg("<name>").

Usage: @run_awk <result> "$program_file" "$struct"
       @run_awk <result> "$program_file" "$struct" --with "$other" --arg since "$since"
PUB_FUN
@run_awk() {
  __structs__run_awk__out="$1"
  __structs__answer_to "$__structs__run_awk__out" '' || return 1
  shift
  __structs__dispatch run_awk "$@" || return $?
  __structs__answer_to "$__structs__run_awk__out" "$__structs__RESULT"
}

:<<'FUN'
Runs the chosen backend's implementation of the verb <verb>,
__structs__<backend>__<verb>, with the arguments after it, and fails,
naming the verb, when the backend has none. Every verb with an
implementation in the backend is defined as a call to this.

  __structs__dispatch merge "$a" "$b"  ->  __structs__silt__merge "$a" "$b" under silt
FUN
__structs__dispatch() {
  __structs__dispatch__verb="$1"
  shift
  if command -v "__structs__${__structs__BACKEND}__${__structs__dispatch__verb}" >/dev/null 2>&1; then
    "__structs__${__structs__BACKEND}__${__structs__dispatch__verb}" "$@"
  else
    fatal "structs: the $__structs__BACKEND backend has no verb named $__structs__dispatch__verb"
    return 127
  fi
}

