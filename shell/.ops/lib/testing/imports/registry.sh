#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
The import providers, one per language, and how a provider gets in.

A provider knows how the files of one language load one another. It is a
plugin: a file named <id>.imports.op.sh that defines one function,
@imports.<id>(), with these inner functions (roles) inside it:

  @language   The language whose files it reads, as language__of_path names
              it (shell, cargo). A plugin that names none is a vocabulary:
              its roles exist for another provider to compose over, and it
              reads no files itself.
  @edges      The loads among the files it is handed (one per line,
              $PROJ-relative), as a struct array of {from, to} edges,
              project-relative. Required of a provider that names a language.
  @loaders    The shell family's command words that load another file, as a
  @roots      struct array, and the variables a path may be written under,
              as a struct object of name -> directory. The shell scanner
              (shell/scan.sh) reads both when a shell-family provider answers
              @edges through it; a provider for another language needs
              neither.

Loading a provider (testing__imports__load_provider) turns the roles into plain
functions named <id>_<role> (shellops_edges) and registers the provider
under its language when it names one. A language has one provider: a second
one for the same language fails loudly, and so does a provider that names a
language without answering @edges. A dialect composes over a vocabulary by
calling its roles -- shellops's @loaders adds import to shell's -- so the
dialect is the one provider for their language and the vocabulary claims
nothing.
FRAGMENT

@obj __at1
__testing__imports__registry__BY_LANGUAGE="${__testing__imports__registry__BY_LANGUAGE:-$__at1}"

: <<'PUB_FUN'
Prints the name of the plain function that is <role> for the provider <id>.

    testing__imports__provider_fn shell loaders  ->  shell_loaders

Usage: testing__imports__provider_fn <id> <role>
PUB_FUN
testing__imports__provider_fn() {
  printf '%s_%s\n' "$1" "$2"
}

: <<'PUB_FUN'
Loads the provider <id>, whose plugin file has been imported, and registers
it under its language when it names one. Does nothing when the provider is
already registered, so importing a plugin twice is harmless. Fails, saying
what is wrong, when the required role is missing or the language already has
another provider.

Usage: testing__imports__load_provider <id>
PUB_FUN
testing__imports__load_provider() {
  if @is_true "$(testing__imports__provider_registered "$1")"; then
    return 0
  fi

  command -v interpreter__load_imports >/dev/null 2>&1 \
    || import "$SHELLOPS_DIR/interpreter/api.sh"
  @is_true "$(__testing__imports__registry__loaded "$1")" \
    || interpreter__load_imports "$1" "@imports.$1" \
    || return 1

  testing__imports__register_provider "$1"
}

: <<'FUN'
Prints true when the provider <id>'s roles are already plain functions, so a
second load does not desugar its plugin again.
FUN
__testing__imports__registry__loaded() {
  if command -v "$(testing__imports__provider_fn "$1" edges)" >/dev/null 2>&1 \
    || command -v "$(testing__imports__provider_fn "$1" loaders)" >/dev/null 2>&1; then
    @true __testing__imports__registry__loaded__out
    println "$__testing__imports__registry__loaded__out"
  else
    @false __testing__imports__registry__loaded__out
    println "$__testing__imports__registry__loaded__out"
  fi
}

: <<'PUB_FUN'
Registers the provider <id> under the language it names. A provider that
names none is left as the vocabulary it is; one that names a language without
answering @edges fails, and so does one naming a language another provider
already has, naming both.

Usage: testing__imports__register_provider <id>
PUB_FUN
testing__imports__register_provider() {
  __testing__imports__register_provider__language="$(testing__imports__provider_language "$1")" || return 1
  @defined "$__testing__imports__register_provider__language" || return 0

  if ! command -v "$(testing__imports__provider_fn "$1" edges)" >/dev/null 2>&1; then
    error "testing__imports__register_provider: provider '$1' names $__testing__imports__register_provider__language files but answers no @edges"
    return 1
  fi

  __testing__imports__register_provider__holder="$(testing__imports__provider_for "$__testing__imports__register_provider__language")"
  if @defined "$__testing__imports__register_provider__holder" \
    && [ "$__testing__imports__register_provider__holder" != "$1" ]; then
    __testing__imports__registry__clash \
      "$__testing__imports__register_provider__language" \
      "$__testing__imports__register_provider__holder" \
      "$1"
    return 1
  fi

  @set __testing__imports__registry__BY_LANGUAGE \
    "$__testing__imports__registry__BY_LANGUAGE" \
    "$__testing__imports__register_provider__language" \
    "$1"
}

: <<'FUN'
Fails, naming the two providers that both claim <language>.

args:
  $1  The language
  $2  The provider registered for it
  $3  The provider being registered
FUN
__testing__imports__registry__clash() {
  error "testing__imports__register_provider: providers '$2' and '$3' both read $1 files"
  return 1
}

: <<'PUB_FUN'
Prints true when the provider <id> is the one registered for its language,
false otherwise -- including for a vocabulary, which names no language, and
for an id whose plugin was never loaded.
PUB_FUN
testing__imports__provider_registered() {
  __testing__imports__provider_registered__language="$(testing__imports__provider_language "$1")"
  if ! @defined "$__testing__imports__provider_registered__language"; then
    @false __testing__imports__provider_registered__out
    println "$__testing__imports__provider_registered__out"
    return 0
  fi

  if [ "$(testing__imports__provider_for "$__testing__imports__provider_registered__language")" = "$1" ]; then
    @true __testing__imports__provider_registered__out
    println "$__testing__imports__provider_registered__out"
  else
    @false __testing__imports__provider_registered__out
    println "$__testing__imports__provider_registered__out"
  fi
}

: <<'PUB_FUN'
Prints the id of the provider registered for <language>, or nothing.
PUB_FUN
testing__imports__provider_for() {
  @get __testing__imports__provider_for__out "$__testing__imports__registry__BY_LANGUAGE" "$1" ''
  println "$__testing__imports__provider_for__out"
}

: <<'PUB_FUN'
Prints the languages that have a provider, as a struct array.
PUB_FUN
testing__imports__provider_languages() {
  @keys __testing__imports__provider_languages__out "$__testing__imports__registry__BY_LANGUAGE"
  println "$__testing__imports__provider_languages__out"
}

: <<'PUB_FUN'
Prints the loads among <files> (one per line, $PROJ-relative) as the provider
<id> reads them: a struct array of {from, to} edges, project-relative.

Usage: testing__imports__provider_edges <id> <files>
PUB_FUN
testing__imports__provider_edges() {
  "$(testing__imports__provider_fn "$1" edges)" "$2"
}

: <<'PUB_FUN'
Prints the language the provider <id> reads, or nothing for a vocabulary and
for an id whose plugin was never loaded.
PUB_FUN
testing__imports__provider_language() {
  __testing__imports__provider_language__fn="$(testing__imports__provider_fn "$1" language)"
  if command -v "$__testing__imports__provider_language__fn" >/dev/null 2>&1; then
    "$__testing__imports__provider_language__fn"
  fi
}
