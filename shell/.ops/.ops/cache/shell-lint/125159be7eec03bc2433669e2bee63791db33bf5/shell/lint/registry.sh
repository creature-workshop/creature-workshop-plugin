#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
The list of lint checks, and how a check gets onto it.

A check is a plugin: a file named <name>.check.op.sh that defines one function,
@check.<name>(), with five inner functions (roles) inside it:

  @run <opts> <files...>  Lints the files. Prints one line per finding, as
                          "<file>:<line>: <message>", and nothing else.
                          Returns 0 when every file is clean, 1 when not.
                          <opts> is a struct with .added_only (only new lines
                          count) and .config (the repository's lint.json).
  @languages              The file types the check reads: a struct array of
                          shell, awk, jq, markdown, yaml.
  @scopes                 Where the check reads them: a struct array of code,
                          tests. A file is tests when it sits under one of
                          lint.json's test trees.
  @summary                The rule, in one line. This is what --list prints
                          and the headline of a failing check's verdict.
  @hint                   How to satisfy the rule, one or more lines. The
                          engine prints it after a failing check's findings,
                          and --explain prints it with the summary.

Loading a check (lint__load_check) turns the inner roles into plain functions
named <prefix>_<role>, where <prefix> is the check name with dashes turned to
underscores (doc-comment -> doc_comment_run), checks that all five exist and
that @languages and @scopes only use the words above, and adds the name to the
list. The list is the order checks run in and the order --list prints.

The words of @languages and @scopes never change after load, so registration
reads each role once and keeps its words as a space-separated string beside
the name. The run (lint__files_for) and --list read the strings, through
lint__check_language_words and lint__check_scope_words, and start no process
for them. The roles themselves stay as they are, so a plugin does not change.
FRAGMENT

__lint__registry__CONTRACT="run languages scopes summary hint"
__lint__registry__LANGUAGES="shell awk jq markdown yaml"
__lint__registry__SCOPES="code tests"

@arr __at1
__lint__registry__NAMES="${__lint__registry__NAMES:-$__at1}"

# CONST: The same names as one space-separated string, so a membership test is a case statement and starts no process.
__lint__registry__WORDS="${__lint__registry__WORDS:-}"

: <<'PUB_FUN'
Prints true when <language> is one a check may read (shell, awk, jq or
markdown or yaml), false otherwise. The classifier names more languages than the
linter reads, so the listing asks here before it lists a file.
PUB_FUN
lint__registry__knows_language() {
  case " $__lint__registry__LANGUAGES " in
    *" $1 "*) @true __lint__registry__knows_language__out; println "$__lint__registry__knows_language__out" ;;
    *) @false __lint__registry__knows_language__out; println "$__lint__registry__knows_language__out" ;;
  esac
}

: <<'PUB_FUN'
Prints the function prefix a check's roles live under: its name with dashes
turned to underscores.

    lint__check_prefix doc-comment  ->  doc_comment
PUB_FUN
lint__check_prefix() {
  __lint__check_prefix__rest="$1"
  __lint__check_prefix__out=""
  while [ "$__lint__check_prefix__rest" != "${__lint__check_prefix__rest#*-}" ]; do
    __lint__check_prefix__out="$__lint__check_prefix__out${__lint__check_prefix__rest%%-*}_"
    __lint__check_prefix__rest="${__lint__check_prefix__rest#*-}"
  done

  printf '%s%s\n' "$__lint__check_prefix__out" "$__lint__check_prefix__rest"
}

: <<'PUB_FUN'
Prints the name of the plain function that is <role> for the check <name>.

    lint__check_fn doc-comment run  ->  doc_comment_run

Usage: lint__check_fn <name> <role>
PUB_FUN
lint__check_fn() {
  printf '%s_%s\n' "$(lint__check_prefix "$1")" "$2"
}

: <<'PUB_FUN'
Loads and registers the check <name>, whose plugin file has been imported.
Does nothing when the check is already registered, so importing a plugin
twice is harmless. Fails, saying what is wrong, when the plugin is missing a
role or uses a language or scope word the registry does not know.

Usage: lint__load_check <name>
PUB_FUN
lint__load_check() {
  if @is_true "$(lint__check_registered "$1")"; then
    return 0
  fi

  command -v interpreter__load_check >/dev/null 2>&1 \
    || import "$SHELLOPS_DIR/interpreter/api.sh"
  command -v "$(lint__check_fn "$1" run)" >/dev/null 2>&1 \
    || interpreter__load_check "$1" "@check.$1" \
    || return 1

  lint__register_check "$1"
}

: <<'PUB_FUN'
Adds the check <name> to the list, after checking its plain role functions
exist and its @languages and @scopes use only known words. Reads those two
roles once, here, and keeps their words beside the name for
lint__check_language_words and lint__check_scope_words. Fails, naming every
problem, when a role is missing or a word is unknown.

Usage: lint__register_check <name>
PUB_FUN
lint__register_check() {
  __lint__register_check__missing="$(__lint__registry__missing_roles "$1")"
  if @defined "$__lint__register_check__missing"; then
    error "lint__register_check: check '$1' missing contract function(s): $__lint__register_check__missing"
    return 1
  fi

  @join __lint__register_check__languages "$(lint__check_languages "$1")" ' '
  @join __lint__register_check__scopes "$(lint__check_scopes "$1")" ' '
  __lint__register_check__unknown="$(__lint__registry__unknown_words \
    "$__lint__register_check__languages" \
    "$__lint__register_check__scopes"
  )"
  if @defined "$__lint__register_check__unknown"; then
    error "lint__register_check: check '$1' uses unknown $__lint__register_check__unknown"
    return 1
  fi

  @push __lint__registry__NAMES "$__lint__registry__NAMES" "$1"
  __lint__registry__WORDS="${__lint__registry__WORDS:+$__lint__registry__WORDS }$1"
  __lint__registry__keep_words "$1" \
    "$__lint__register_check__languages" \
    "$__lint__register_check__scopes"
}

: <<'FUN'
Keeps the check <name>'s language and scope words, each a space-separated
string, in a variable named for the check's prefix:
__lint__registry__LANGUAGE_WORDS__<prefix> and
__lint__registry__SCOPE_WORDS__<prefix>. The readers below eval the same
names back.

Usage: __lint__registry__keep_words <name> <language words> <scope words>
FUN
__lint__registry__keep_words() {
  __lint__registry__keep_words__prefix="$(lint__check_prefix "$1")"
  eval "__lint__registry__LANGUAGE_WORDS__$__lint__registry__keep_words__prefix=\$2"
  eval "__lint__registry__SCOPE_WORDS__$__lint__registry__keep_words__prefix=\$3"
}

: <<'PUB_FUN'
Prints the check <name>'s languages as one space-separated string, as
registration read them from its @languages role. Starts no process. Prints
nothing for a check that is not registered.

    lint__check_language_words banner-comment  ->  shell awk jq

Usage: lint__check_language_words <name>
PUB_FUN
lint__check_language_words() {
  __lint__check_language_words__prefix="$(lint__check_prefix "$1")"
  eval "println \"\${__lint__registry__LANGUAGE_WORDS__$__lint__check_language_words__prefix:-}\""
}

: <<'PUB_FUN'
Prints the check <name>'s scopes as one space-separated string, as
registration read them from its @scopes role. Starts no process. Prints
nothing for a check that is not registered.

    lint__check_scope_words indent  ->  code tests

Usage: lint__check_scope_words <name>
PUB_FUN
lint__check_scope_words() {
  __lint__check_scope_words__prefix="$(lint__check_prefix "$1")"
  eval "println \"\${__lint__registry__SCOPE_WORDS__$__lint__check_scope_words__prefix:-}\""
}

: <<'FUN'
Prints the role functions the check <name> does not define, comma-separated.
Prints nothing when all are defined.
FUN
__lint__registry__missing_roles() {
  __lint__registry__missing_roles__missing=""
  for __lint__registry__missing_roles__role in $__lint__registry__CONTRACT; do
    __lint__registry__missing_roles__fn="$(lint__check_fn "$1" "$__lint__registry__missing_roles__role")"
    if ! command -v "$__lint__registry__missing_roles__fn" >/dev/null 2>&1; then
      __lint__registry__missing_roles__missing="$__lint__registry__missing_roles__missing, $__lint__registry__missing_roles__fn"
    fi
  done

  println "${__lint__registry__missing_roles__missing#, }"
}

: <<'FUN'
Prints the words among a check's space-separated <language words> and <scope
words> that the registry does not know, as "language(s): x, y; scope(s): z".
Prints nothing when every word is known.

Usage: __lint__registry__unknown_words <language words> <scope words>
FUN
__lint__registry__unknown_words() {
  __lint__registry__unknown_words__languages="$(__lint__registry__unknown_in \
    "$1" "$__lint__registry__LANGUAGES")"
  __lint__registry__unknown_words__scopes="$(__lint__registry__unknown_in \
    "$2" "$__lint__registry__SCOPES")"

  __lint__registry__unknown_words__out=""
  if @defined "$__lint__registry__unknown_words__languages"; then
    __lint__registry__unknown_words__out="language(s): $__lint__registry__unknown_words__languages"
  fi
  if @defined "$__lint__registry__unknown_words__scopes"; then
    __lint__registry__unknown_words__out="$__lint__registry__unknown_words__out; scope(s): $__lint__registry__unknown_words__scopes"
  fi

  println "${__lint__registry__unknown_words__out#; }"
}

: <<'FUN'
Prints the space-separated <words> that are not among the space-separated
<known>, comma-separated. Prints nothing when all are known.
FUN
__lint__registry__unknown_in() {
  __lint__registry__unknown_in__out=""
  for __lint__registry__unknown_in__word in $1; do
    case " $2 " in
      *" $__lint__registry__unknown_in__word "*) ;;
      *) __lint__registry__unknown_in__out="$__lint__registry__unknown_in__out, $__lint__registry__unknown_in__word" ;;
    esac
  done

  println "${__lint__registry__unknown_in__out#, }"
}

: <<'PUB_FUN'
Prints true when a check named <name> is on the list, false otherwise.
PUB_FUN
lint__check_registered() {
  case " $__lint__registry__WORDS " in
    *" $1 "*) @true __lint__check_registered__out; println "$__lint__check_registered__out" ;;
    *) @false __lint__check_registered__out; println "$__lint__check_registered__out" ;;
  esac
}

: <<'PUB_FUN'
Prints the names of every check on the list, as a struct array, in the order
they run.
PUB_FUN
lint__registry__names() {
  println "$__lint__registry__NAMES"
}

: <<'PUB_FUN'
Prints the <names> that are not on the list, as a struct array. Empty when
every name is a check.

    lint__unknown_checks '["indent","bogus"]'  ->  ["bogus"]
PUB_FUN
lint__unknown_checks() {
  @arr __lint__unknown_checks__arr_2
  @reduce __lint__unknown_checks__out __lint__registry__collect_unknown "$1" "$__lint__unknown_checks__arr_2"
  println "$__lint__unknown_checks__out"
}

: <<'FUN'
@reduce callback: adds the wrapped <name> to the accumulator unless a check by
that name is on the list.
FUN
__lint__registry__collect_unknown() {
  @unwrap __lint__registry__collect_unknown__name "$2"

  if @is_true "$(lint__check_registered "$__lint__registry__collect_unknown__name")"; then
    println "$1"
  else
    @push __lint__registry__collect_unknown__out "$1" "$__lint__registry__collect_unknown__name"
    println "$__lint__registry__collect_unknown__out"
  fi
}

: <<'PUB_FUN'
Prints the check <name>'s @languages: a struct array.
PUB_FUN
lint__check_languages() {
  "$(lint__check_fn "$1" languages)"
}

: <<'PUB_FUN'
Prints the check <name>'s @scopes: a struct array.
PUB_FUN
lint__check_scopes() {
  "$(lint__check_fn "$1" scopes)"
}

: <<'PUB_FUN'
Prints the check <name>'s @summary: its rule, in one line.
PUB_FUN
lint__check_summary() {
  "$(lint__check_fn "$1" summary)"
}

: <<'PUB_FUN'
Prints the check <name>'s @hint: how to satisfy its rule, one or more lines.
PUB_FUN
lint__check_hint() {
  "$(lint__check_fn "$1" hint)"
}

: <<'PUB_FUN'
Prints the check <name>'s verdict: its summary as the error headline, then
each line of its hint. This follows a failing check's findings.
PUB_FUN
lint__check_verdict() {
  error "$(lint__check_summary "$1")"
  lint__check_hint "$1" | __lint__registry__hint_lines
}

: <<'FUN'
Reads lines on stdin and prints each as a hint.
FUN
__lint__registry__hint_lines() {
  while IFS= read -r __lint__registry__hint_lines__line; do
    hint "$__lint__registry__hint_lines__line"
  done
}

: <<'PUB_FUN'
Prints what --explain <name> shows: the check's rule and how to satisfy it.
PUB_FUN
lint__explain_check() {
  printf '%s\n\n' "$(lint__check_summary "$1")"
  lint__check_hint "$1"
}

: <<'PUB_FUN'
Runs the check <name>'s @run over <files> with <opts>, returning what it
returns.

Usage: lint__check_run <name> <opts> <files...>
PUB_FUN
lint__check_run() {
  __lint__check_run__fn="$(lint__check_fn "$1" run)"
  shift
  "$__lint__check_run__fn" "$@"
}

: <<'PUB_FUN'
Prints one line per check on the list: its name, languages, scopes and rule.
This is what --list prints.
PUB_FUN
lint__describe_checks() {
  @foreach __lint__registry__describe "$__lint__registry__NAMES"
}

: <<'FUN'
@foreach callback: prints the --list line for the wrapped check <name>, its
languages and scopes read from the words registration kept.
FUN
__lint__registry__describe() {
  @unwrap __lint__registry__describe__name "$1"
  printf '%-20s %-16s %-12s %s\n' \
    "$__lint__registry__describe__name" \
    "$(__lint__registry__comma_list "$(lint__check_language_words "$__lint__registry__describe__name")")" \
    "$(__lint__registry__comma_list "$(lint__check_scope_words "$__lint__registry__describe__name")")" \
    "$(lint__check_summary "$__lint__registry__describe__name")"
}

: <<'FUN'
Prints the space-separated <words> joined with ", ", starting no process.

    __lint__registry__comma_list "shell awk jq"  ->  shell, awk, jq
FUN
__lint__registry__comma_list() {
  __lint__registry__comma_list__out=""
  for __lint__registry__comma_list__word in $1; do
    __lint__registry__comma_list__out="$__lint__registry__comma_list__out, $__lint__registry__comma_list__word"
  done

  println "${__lint__registry__comma_list__out#, }"
}
