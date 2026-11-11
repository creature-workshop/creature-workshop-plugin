#!/bin/sh
# shellcheck disable=SC2119  # bare @arr/@obj are the structs empty constructors

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
Reading one variable as it stands: whether it is set, its value, and what
a line may carry of it -- the digest, the shown prefix, and the scheme.
FRAGMENT

: <<'CONST'
How much of a value may be read for its scheme. A value carrying no scheme at
all gives away no more than this.
CONST
__fingerprint__SCHEME_WINDOW=12

: <<'CONST'
How much of a non-secret value a line carries. Long enough for the settings
this reports, short enough to leave the line readable.
CONST
__fingerprint__VALUE_WINDOW=32

:<<'PUB_FUN'
Prints whether <name> is set, an empty value included.
PUB_FUN
fingerprint__var_is_set() {
  @succeeds __fingerprint__var_is_set__out __fingerprint__var_is_exported "$1"
  println "$__fingerprint__var_is_set__out"
}

__fingerprint__var_is_exported() {
  printenv "$1" > /dev/null 2>&1
}

:<<'PUB_FUN'
Prints the value of <name>, or nothing when it is unset.
PUB_FUN
fingerprint__var_value() {
  printenv "$1" || true
}

:<<'PUB_FUN'
Prints the first twelve hex digits of the sha256 of <value> -- enough to match
one copy of a secret against another, far too little to walk back.
PUB_FUN
fingerprint__digest() {
  printf '%s' "$1" | sha256sum | cut -c1-12
}

:<<'PUB_FUN'
Prints as much of the non-secret <value> as a line carries: its leading
characters, with each run of whitespace standing as one _ so that one input
stays one line and one field. The line's length field is what says whether
anything was left off.
PUB_FUN
fingerprint__value_shown() {
  printf '%s' "$1" \
    | tr -s '[:space:]' '_' \
    | cut -c"1-$__fingerprint__VALUE_WINDOW"
}

:<<'PUB_FUN'
Prints the scheme prefix of <value>: its leading run up to and including the
first delimiter, or "none" when its opening characters hold no delimiter.

A token scheme is conventionally an unsecret prefix ending in a delimiter, so
reading the delimiter off the value keeps this ignorant of which schemes exist
and how each one is spelled.
PUB_FUN
fingerprint__scheme() {
  __fingerprint__scheme__head="$(printf '%s' "$1" | cut -c"1-$__fingerprint__SCHEME_WINDOW")"
  __fingerprint__scheme__prefix="$(__fingerprint__delimited_prefix "$__fingerprint__scheme__head")"

  if ! @defined "$__fingerprint__scheme__prefix"; then
    printf 'none\n'
    return 0
  fi

  println "$__fingerprint__scheme__prefix"
}

:<<'FUN'
Prints <text> up to and including its first _ or -, or nothing when it holds
neither. The two delimiters fold to one so the shell's own prefix removal finds
whichever comes first, and the character it landed on is read back from <text>
at that offset.
FUN
__fingerprint__delimited_prefix() {
  __fingerprint__delimited_prefix__folded="$(printf '%s' "$1" | tr '-' '_')"
  __fingerprint__delimited_prefix__head="${__fingerprint__delimited_prefix__folded%%_*}"

  if [ "$__fingerprint__delimited_prefix__head" = "$__fingerprint__delimited_prefix__folded" ]; then
    return 0
  fi

  __fingerprint__delimited_prefix__at=$(( ${#__fingerprint__delimited_prefix__head} + 1 ))
  __fingerprint__delimited_prefix__delimiter="$(printf '%s' "$1" \
    | cut -c"$__fingerprint__delimited_prefix__at"
  )"

  printf '%s%s\n' \
    "$__fingerprint__delimited_prefix__head" \
    "$__fingerprint__delimited_prefix__delimiter"
}

:<<'FUN'
Prints the name in <chain> holding the value its reader resolves to -- the first
one that is set and not empty -- or nothing when none of them is.
FUN
__fingerprint__winner() {
  @find __fingerprint__winner__match __fingerprint__name_has_value "$1"

  if ! @defined "$__fingerprint__winner__match"; then
    return 0
  fi

  @unwrap __fingerprint__winner__out "$__fingerprint__winner__match"
  println "$__fingerprint__winner__out"
}

:<<'FUN'
@find predicate: succeeds when <name> (wrapped) holds a non-empty value.
FUN
__fingerprint__name_has_value() {
  @unwrap __fingerprint__name_has_value__name "$1"

  @defined "$(fingerprint__var_value "$__fingerprint__name_has_value__name")"
}
