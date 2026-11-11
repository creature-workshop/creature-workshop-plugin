#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'MODULE'
Regular expressions as values: the regex type, a struct string holding a
POSIX extended regular expression, the dialect grep -E, sed -E and awk
share, and the verbs that compose one from named parts, so a pattern is
built from pieces a reader can name rather than written out by hand.

A regex is made from an expression written as such, checked to compile, or
composed: a literal matches a text exactly, its metacharacters escaped; any
matches one of several parts; seq matches each part in turn; optional, many
and some repeat one part; anchored holds one part to the whole text. A
compound part is grouped, so a composition means what it says whatever its
parts are. regex__ere prints the expression for a consumer, and
regex__matches asks whether a text matches.

awk reads the same dialect with one gap: it has no \b, the word boundary
GNU grep -E and sed -E accept. A composition never emits one; an expression
written as such carries its own, and its author knows where it goes.

  @regex '[0-9]+'                                   ->  "[0-9]+"
  @regex '('                                        ->  fails
  regex__literal 'a.b'                              ->  "a\\.b"
  regex__any "$(@arr "$(regex__literal OPS)" "$(regex__literal BIZ)")"  ->  "(OPS|BIZ)"
  regex__matches "$(@regex '^OPS-[0-9]+$')" OPS-12  ->  true
MODULE

@load_types "$SHELLOPS_DIR/lib/regex"

:<<'PUB_FUN'
Prints true when the expression compiles as a POSIX extended regular
expression under grep -E, false when it does not, such as an unclosed group
or a repetition with nothing before it.

Usage: regex__is_valid "$expression"
PUB_FUN
regex__is_valid() {
  __regex__is_valid__status=0
  grep -E -e "$1" </dev/null >/dev/null 2>&1 || __regex__is_valid__status=$?

  @succeeds __regex__is_valid__out [ "$__regex__is_valid__status" -ne 2 ]
  println "$__regex__is_valid__out"
}

:<<'PUB_FUN'
Prints the expression a regex holds, as grep -E, sed -E and awk read it.

  regex__ere "$(regex__literal 'a.b')"  ->  a\.b

Usage: regex__ere "$regex"
PUB_FUN
regex__ere() {
  @unwrap __regex__ere__out "$1"
  println "$__regex__ere__out"
}

:<<'PUB_FUN'
Prints the regex matching the text exactly: every character that means
something in an expression is escaped, so a dot is a dot and a bracket a
bracket.

  regex__literal 'a.b'  ->  "a\\.b"

Usage: regex__literal "$text"
PUB_FUN
regex__literal() {
  __regex__literal__escaped="$(printf '%s' "$1" | sed -f "$SHELLOPS_DIR/lib/regex/escape_literal.sed")"

  @wrap __regex__literal__out "$__regex__literal__escaped"
  println "$__regex__literal__out"
}

:<<'PUB_FUN'
Prints the regex matching any one of the parts, a struct array of at least
one regex, as a grouped alternation. Fails with no part, since an empty
alternation matches nothing a reader would expect.

  regex__any "$(@arr "$(regex__literal OPS)" "$(regex__literal BIZ)")"  ->  "(OPS|BIZ)"

Usage: regex__any "$parts"
PUB_FUN
regex__any() {
  if @len __regex__any__len_1 "$1"; [ "$__regex__any__len_1" -eq 0 ]; then
    error "regex__any: at least one part is required"
    return 1
  fi
  @join __regex__any__joined "$1" "|"

  @wrap __regex__any__out "($__regex__any__joined)"
  println "$__regex__any__out"
}

:<<'PUB_FUN'
Prints the regex matching each of the parts in turn, a struct array of
regexes, one after the other with nothing between them.

  regex__seq "$(@arr "$(regex__literal OPS-)" "$(@regex '[0-9]+')")"  ->  "OPS-[0-9]+"

Usage: regex__seq "$parts"
PUB_FUN
regex__seq() {
  @join __regex__seq__joined "$1" ""

  @wrap __regex__seq__out "$__regex__seq__joined"
  println "$__regex__seq__out"
}

:<<'PUB_FUN'
Prints the regex matching the part once or not at all, grouped.

  regex__optional "$(regex__literal ab)"  ->  "(ab)?"

Usage: regex__optional "$regex"
PUB_FUN
regex__optional() {
  __regex__repeat "$1" "?"
}

:<<'PUB_FUN'
Prints the regex matching the part any number of times, none included,
grouped.

  regex__many "$(regex__literal ab)"  ->  "(ab)*"

Usage: regex__many "$regex"
PUB_FUN
regex__many() {
  __regex__repeat "$1" "*"
}

:<<'PUB_FUN'
Prints the regex matching the part one or more times, grouped.

  regex__some "$(regex__literal ab)"  ->  "(ab)+"

Usage: regex__some "$regex"
PUB_FUN
regex__some() {
  __regex__repeat "$1" "+"
}

:<<'FUN'
Prints the part grouped and followed by the repetition operator, so the
operator applies to the whole part and never to its last character alone.

Usage: __regex__repeat "$regex" "?"
FUN
__regex__repeat() {
  @unwrap __regex__repeat__expression "$1"

  @wrap __regex__repeat__out "($__regex__repeat__expression)$2"
  println "$__regex__repeat__out"
}

:<<'PUB_FUN'
Prints the regex matching the whole text and nothing less: the part grouped
between the start and end anchors, so an alternation is held as one.

  regex__anchored "$(@regex 'a|b')"  ->  "^(a|b)$"

Usage: regex__anchored "$regex"
PUB_FUN
regex__anchored() {
  @unwrap __regex__anchored__expression "$1"

  @wrap __regex__anchored__out "^($__regex__anchored__expression)$"
  println "$__regex__anchored__out"
}

:<<'PUB_FUN'
Prints true when the text matches the regex anywhere, false when it does
not. Fails when the expression does not compile.

  regex__matches "$(@regex '^OPS-[0-9]+$')" OPS-12  ->  true

Usage: regex__matches "$regex" "$text"
PUB_FUN
regex__matches() {
  @unwrap __regex__matches__expression "$1"
  __regex__matches__status=0
  println "$2" | grep -E -e "$__regex__matches__expression" >/dev/null 2>&1 || __regex__matches__status=$?
  if [ "$__regex__matches__status" -eq 2 ]; then
    error "regex__matches: the expression does not compile: $__regex__matches__expression"
    return 1
  fi

  @succeeds __regex__matches__out [ "$__regex__matches__status" -eq 0 ]
  println "$__regex__matches__out"
}
