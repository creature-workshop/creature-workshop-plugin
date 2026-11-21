#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/args/lines.sh"

: <<'MODULE'
The grammar of a command line: what shape a token in argv has, and whether a
flag that takes a value was given one.

Every question here is about one token, or about how many are left. Deciding
what a token means and consuming it are the parser's, since only the parser
knows what its own flags accept. Two things every parser says the same way
live here too: that a flag is missing its value, and that the options it
collected have problems -- every one of them named before it refuses.
MODULE

: <<'PUB_FUN'
Prints true when <token> is an option rather than a value.

Usage: args__is_flag "$1"
PUB_FUN
args__is_flag() {
  case "${1:-}" in
    -*) @true __args__is_flag__out; println "$__args__is_flag__out" ;;
    *) @false __args__is_flag__out; println "$__args__is_flag__out" ;;
  esac
}

: <<'PUB_FUN'
Prints true when <token> is a positional argument: present, and not an option.

The token after an optional-value flag is the case this answers. A flag there
belongs to the parser's next turn, and the end of argv is not a value either,
so both have to read as false before a parser can treat what is left as its own.

Usage: args__is_positional "${2:-}"
PUB_FUN
args__is_positional() {
  if @defined "${1:-}"; then
    @not __args__is_positional__out "$(args__is_flag "$1")"
    println "$__args__is_positional__out"
  else
    @false __args__is_positional__out
    println "$__args__is_positional__out"
  fi
}

: <<'PUB_FUN'
Prints true when the flag at the head of <argv> has a token after it to take as
its value.

Called with the parser's remaining argv, flag included, so a value-taking flag
can answer for itself before reading a positional that may not be there.

Usage: args__has_value "$@"
PUB_FUN
args__has_value() {
  @succeeds __args__has_value__out [ "$#" -ge 2 ]
  println "$__args__has_value__out"
}

: <<'PUB_FUN'
Prints true when <argv> carries no tokens at all.

A command that requires at least one argument asks this before reading any.
The question is arity, not content: an empty token is still a token, the same
way args__has_value counts one as given. Whether a token says anything is the
caller's question, asked of the token with @defined.

Usage: args__empty "$@"
PUB_FUN
args__empty() {
  @succeeds __args__empty__out [ "$#" -eq 0 ]
  println "$__args__empty__out"
}

: <<'PUB_FUN'
Succeeds quietly when the flag at the head of <argv> has a value after it;
otherwise names the flag that is missing one and returns 1.

  args__require_value --url http://localhost:3000   # returns 0
  args__require_value --url                         # Missing value for --url

Usage: args__require_value "$@" || <refuse>
PUB_FUN
args__require_value() {
  if @is_true "$(args__has_value "$@")"; then
    return 0
  fi

  error "Missing value for ${1:-}"
  return 1
}

: <<'PUB_FUN'
Prints the struct field a flag writes: the flag's name with its dashes turned
to underscores.

  args__field_of --ready-in  ->  .ready_in

Usage: args__field_of "$1"
PUB_FUN
args__field_of() {
  printf '.%s\n' "$(printf '%s' "${1#--}" | tr '-' '_')"
}

: <<'PUB_FUN'
Prints the <problems> array with <message> appended, unless <answer> is true,
in which case the array is printed as it came. A validator threads its
problems through one call per rule and hands the result to args__refuse.

  args__problem_unless "$problems" "$(is_url "$url")" "--url must be http(s)"

args:
  $1  The problems so far, a struct array of messages
  $2  A struct boolean: true when the rule holds
  $3  The message to note when it does not
PUB_FUN
args__problem_unless() {
  if @is_true "$2"; then
    println "$1"
  else
    @wrap __args__problem_unless__wrap_1 "$3"
    @push __args__problem_unless__out "$1" "$__args__problem_unless__wrap_1"
    println "$__args__problem_unless__out"
  fi
}

: <<'PUB_FUN'
Refuses a struct array of problems: names every one as an error and returns 1.
An empty array prints nothing and returns 0.

Usage: args__refuse "$problems" || exit 1
PUB_FUN
args__refuse() {
  if @len __args__refuse__len_2 "$1"; [ "$__args__refuse__len_2" -eq 0 ]; then
    return 0
  fi

  @foreach __args__report_problem "$1"
  return 1
}

__args__report_problem() {
  @unwrap __args__report_problem__unwrap_3 "$1"
  error "$__args__report_problem__unwrap_3"
}

: <<'PUB_FUN'
Prints <flags> with <flag> and <value> appended when <value> is set, and
<flags> unchanged when it is not: how a parser turns an option it collected
into the argument list of the command it calls through @apply. Both go in as
the strings they are, so a value spelled like a number or a boolean stays one.

  args__flag_with_value "$(@arr)" --registry crates-io  ->  ["--registry","crates-io"]
  args__flag_with_value "$(@arr)" --registry ''         ->  []

args:
  $1  The flags so far, a struct array
  $2  The flag
  $3  Its value, or empty
PUB_FUN
args__flag_with_value() {
  if ! @defined "$3"; then
    println "$1"
    return
  fi

  @wrap __args__flag_with_value__wrap_4 "$2"
  @push __args__flag_with_value__flags "$1" "$__args__flag_with_value__wrap_4"
  @wrap __args__flag_with_value__wrap_5 "$3"
  @push __args__flag_with_value__out "$__args__flag_with_value__flags" "$__args__flag_with_value__wrap_5"
  println "$__args__flag_with_value__out"
}

: <<'PUB_FUN'
Prints <flags> with <flag> appended when <setting> is set, and <flags>
unchanged when it is not: the boolean counterpart of args__flag_with_value.

  args__flag_when_set "$(@arr)" --dry-run true  ->  ["--dry-run"]
  args__flag_when_set "$(@arr)" --dry-run ''    ->  []

args:
  $1  The flags so far, a struct array
  $2  The flag
  $3  The setting that asks for it, or empty
PUB_FUN
args__flag_when_set() {
  if ! @defined "$3"; then
    println "$1"
    return
  fi

  @wrap __args__flag_when_set__wrap_6 "$2"
  @push __args__flag_when_set__out "$1" "$__args__flag_when_set__wrap_6"
  println "$__args__flag_when_set__out"
}
