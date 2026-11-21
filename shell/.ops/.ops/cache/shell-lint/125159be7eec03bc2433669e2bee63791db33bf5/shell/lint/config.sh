#!/bin/sh

: <<'FRAGMENT'
The repository's lint settings: the lint declaration, .ops/config/lint.yaml,
or $PROJ/lint.json while the repository has not converted.

The declaration is read once per run, checked against lint.schema.json, and
handed to every check inside its options as `.config`. It is optional, and
so is every key in it: each reader here has a default, so a repository with
no declaration gets the house settings. To add a setting, add it to the
schema and add a reader here; the schema is what tells a repository its
declaration is wrong.

The read goes through shellops' config module when the shellops the host
runs on has one, so the lint and the resolver agree on where a declaration
is and how it is read; otherwise the lint reads the YAML through SILT, in
the strata tree that SILT_DIR points to, and the JSON through the structs
API.
FRAGMENT

__lint__config__SCHEMA="$SHELL_LINT_DIR/shell/lint/lint.schema.json"

# CONST: The lint declaration's path under a repository.
__lint__config__DECLARATION='.ops/config/lint.yaml'

# CONST: The root file the declaration replaces, read while a repository has not converted.
__lint__config__LEGACY='lint.json'

: <<'PUB_FUN'
Prints the repository's lint settings as a struct, checked against
lint.schema.json: the declaration .ops/config/lint.yaml when the repository
has one, else $PROJ/lint.json, else an empty object. A declaration that
does not parse, or that breaks the schema, fails the call and says why. A
named file is read as JSON, for a test or a tool that keeps its settings
elsewhere.

Usage: lint__config__load            # the repository's lint declaration
       lint__config__load <path>     # a named JSON file
PUB_FUN
lint__config__load() {
  if [ -n "${1:-}" ]; then  # structs-lint: allow -- a positional path, not a printed answer
    __lint__config__load_json "$1"
    return
  fi

  __lint__config__load__config="$(__lint__config__load_declaration)" || return 1
  @defined "$__lint__config__load__config" || { @obj __lint__config__load__out; println "$__lint__config__load__out"; return 0; }
  @validate "$__lint__config__load__config" "$__lint__config__SCHEMA" || return 1
  println "$__lint__config__load__config"
}

: <<'FUN'
Prints the repository's lint declaration as a struct, unchecked, or nothing
when the repository has none: through shellops' config module when this
shell has one, else the YAML under .ops/config read through SILT, else
$PROJ/lint.json.
FUN
__lint__config__load_declaration() {
  __lint__config__import_shellops_module
  if @is_true "$(__lint__config__has_shellops_module)"; then
    __lint__config__load_through_shellops
  elif [ -f "$PROJ/$__lint__config__DECLARATION" ]; then
    __lint__config__read_yaml "$PROJ/$__lint__config__DECLARATION"
  elif [ -f "$PROJ/$__lint__config__LEGACY" ]; then
    __lint__config__read_json "$PROJ/$__lint__config__LEGACY"
  fi
}

: <<'FUN'
Imports shellops' config module when the shellops present has one and this
shell does not define its verbs yet. A shellops without the module leaves
the shell as it is.
FUN
__lint__config__import_shellops_module() {
  if @is_true "$(__lint__config__has_shellops_module)"; then
    return 0
  fi
  if [ -f "$SHELLOPS_DIR/lib/self/config.sh" ]; then
    import "$SHELLOPS_DIR/lib/self/config.sh"
  fi
}

: <<'FUN'
Prints true when this shell defines self__config__load, the verb of
shellops' config module, and false otherwise. A test that defines the verb
itself stands in for a shellops that has the module.
FUN
__lint__config__has_shellops_module() {
  __lint__config__has_shellops_module__verb="$(command -v self__config__load || true)"
  @succeeds __lint__config__has_shellops_module__out @defined "$__lint__config__has_shellops_module__verb"
  println "$__lint__config__has_shellops_module__out"
}

: <<'FUN'
Prints the lint declaration as shellops' config module reads it, or
nothing when that module finds none. The module hands a legacy lint.json
over as it is, so one that is not JSON is refused here, naming it.
FUN
__lint__config__load_through_shellops() {
  @is_true "$(self__config__present lint)" || return 0
  __lint__config__load_through_shellops__json="$(self__config__load lint)" || return 1
  __lint__config__parsed "$__lint__config__load_through_shellops__json" "$PROJ/$__lint__config__LEGACY"
}

: <<'FUN'
Prints the JSON file <file> as a struct. Fails, naming the file, when it
does not parse as JSON.
FUN
__lint__config__read_json() {
  __lint__config__read_json__json="$(cat "$1")" || return 1
  __lint__config__parsed "$__lint__config__read_json__json" "$1"
}

: <<'FUN'
Prints <json> when it parses as JSON. Fails, naming <file>, when it does
not.

args:
  $1  The text read from the file
  $2  The file it was read from
FUN
__lint__config__parsed() {
  if ! @is_valid "$1"; then
    error "$2 does not read as JSON"
    return 1
  fi
  println "$1"
}

: <<'FUN'
Prints the YAML file <file> as a struct, read through SILT's translator in
the strata tree that SILT_DIR points to. Fails, saying so, when SILT_DIR
does not point to the library or the file does not parse as YAML.
FUN
__lint__config__read_yaml() {
  __lint__config__silt || return 1
  if ! silt__from_yaml __lint__config__read_yaml__doc < "$1"; then
    error "$1 does not read as YAML"
    return 1
  fi
  silt__to_json __lint__config__read_yaml__json "$__lint__config__read_yaml__doc" || return 1
  println "$__lint__config__read_yaml__json"
}

: <<'FUN'
Makes SILT's verbs present in this shell, sourcing the library from the
strata tree that SILT_DIR points to when they are not yet. Fails, saying
so, when SILT_DIR is unset or does not point to the library.
FUN
__lint__config__silt() {
  if command -v silt__from_yaml >/dev/null 2>&1; then
    return 0
  fi
  if [ -z "${SILT_DIR:-}" ] || [ ! -f "$SILT_DIR/api.sh" ]; then
    error "SILT_DIR does not point to the SILT library, so $__lint__config__DECLARATION cannot be read"
    return 1
  fi
  . "$SILT_DIR/api.sh"
}

: <<'FUN'
Prints the lint settings in the JSON file <path> as a struct, checked
against lint.schema.json, or an empty object when the file does not exist.
Fails, saying why, when the file does not parse or breaks the schema.

Usage: __lint__config__load_json <path>
FUN
__lint__config__load_json() {
  if [ ! -f "$1" ]; then
    @obj __lint__config__load_json__out
    println "$__lint__config__load_json__out"
    return 0
  fi

  @load __lint__config__load_json__out "$1" "$__lint__config__SCHEMA" || return 1
  println "$__lint__config__load_json__out"
}

: <<'PUB_FUN'
Prints the directories a repository keeps its own lint checks under, as a
struct array of PROJ-relative paths; empty by default.
PUB_FUN
lint__config__check_roots() {
  @arr __lint__config__check_roots__arr_1
  @get __lint__config__check_roots__out "$1" '.checks' "$__lint__config__check_roots__arr_1"
  println "$__lint__config__check_roots__out"
}

: <<'PUB_FUN'
Prints the number of spaces one indent level is, 2 by default.
PUB_FUN
lint__config__indent_width() {
  @get __lint__config__indent_width__out "$1" '.indent.width' 2
  println "$__lint__config__indent_width__out"
}

: <<'PUB_FUN'
Prints true when leading tabs are allowed, false by default.
PUB_FUN
lint__config__allow_tabs() {
  @get __lint__config__allow_tabs__out "$1" '.indent.tabs' false
  println "$__lint__config__allow_tabs__out"
}

: <<'PUB_FUN'
Prints the directory names that mark a test tree, as a struct array; test and
tests by default. A file under a directory with one of these names, anywhere
in its path, is in the tests scope.
PUB_FUN
lint__config__test_trees() {
  @arr __lint__config__test_trees__arr_2 test tests
  @get __lint__config__test_trees__out "$1" '.tests' "$__lint__config__test_trees__arr_2"
  println "$__lint__config__test_trees__out"
}

: <<'PUB_FUN'
Prints the directories, relative to the repository root, that no check looks
in; a struct array, empty by default.
PUB_FUN
lint__config__excludes() {
  @arr __lint__config__excludes__arr_3
  @get __lint__config__excludes__out "$1" '.exclude' "$__lint__config__excludes__arr_3"
  println "$__lint__config__excludes__out"
}

: <<'PUB_FUN'
Prints the roots a library file sits under, relative to the repository root,
as a struct array: the list lint.json's library_roots names; otherwise
scripts, shell and src, the homes a consumer keeps its shell in, or lib and
interpreter when the repository is shellops itself, PROJ standing in
SHELLOPS_DIR (ADR 000045). A file under one is a module, its namespace the
path under the root; a consumer's root lib/ is its product's until named.
PUB_FUN
lint__config__library_roots() {
  @get __lint__config__library_roots__out "$1" '.library_roots' "$(__lint__config__default_library_roots)"
  println "$__lint__config__library_roots__out"
}

: <<'FUN'
Prints the library roots a repository has when lint.json names none, as a
struct array: shellops' own when PROJ stands in SHELLOPS_DIR, a consumer's
otherwise.
FUN
__lint__config__default_library_roots() {
  case "$PROJ/" in
    "$SHELLOPS_DIR"/*) __lint__config__shellops_library_roots ;;
    *) __lint__config__consumer_library_roots ;;
  esac
}

: <<'FUN'
Prints shellops' own library roots, lib and interpreter, as a struct array.
FUN
__lint__config__shellops_library_roots() {
  @arr __lint__config__shellops_library_roots__out lib interpreter
  println "$__lint__config__shellops_library_roots__out"
}

: <<'FUN'
Prints a consumer's library roots, the homes it keeps its shell in, as a
struct array: scripts, shell and src.
FUN
__lint__config__consumer_library_roots() {
  @arr __lint__config__consumer_library_roots__out scripts shell src
  println "$__lint__config__consumer_library_roots__out"
}

: <<'PUB_FUN'
Prints the names of the checks that run only under --added-only, as a struct
array; empty by default. A check goes here when the code already has findings
the team is working off: new lines still have to pass it, and a full sweep
leaves it out rather than failing on the old ones.
PUB_FUN
lint__config__added_only_checks() {
  @arr __lint__config__added_only_checks__arr_4
  @get __lint__config__added_only_checks__out "$1" '.added_only' "$__lint__config__added_only_checks__arr_4"
  println "$__lint__config__added_only_checks__out"
}

: <<'PUB_FUN'
Prints the names of the checks that never run in this repository, as a
struct array; empty by default. A check goes here when it polices an API
the repository does not use, so its findings are not a backlog that new
lines are held to: the check is left out of every run, and named.
PUB_FUN
lint__config__disabled_checks() {
  @arr __lint__config__disabled_checks__arr_5
  @get __lint__config__disabled_checks__out "$1" '.disabled' "$__lint__config__disabled_checks__arr_5"
  println "$__lint__config__disabled_checks__out"
}

: <<'PUB_FUN'
Prints the directory, relative to the repository root, that holds the
repository's decision records; docs/decisions by default.
PUB_FUN
lint__config__decisions_folder() {
  @get __lint__config__decisions_folder__out "$1" '.decisions.folder' docs/decisions
  println "$__lint__config__decisions_folder__out"
}

: <<'PUB_FUN'
Prints the form the repository holds its decision records to: one-page, or
nothing when the repository names no form.
PUB_FUN
lint__config__decisions_form() {
  @get __lint__config__decisions_form__out "$1" '.decisions.form' ''
  println "$__lint__config__decisions_form__out"
}

: <<'PUB_FUN'
Prints how many words of prose a one-page decision record may spend, 450 by
default.
PUB_FUN
lint__config__decisions_page_words() {
  @get __lint__config__decisions_page_words__out "$1" '.decisions.page_words' 450
  println "$__lint__config__decisions_page_words__out"
}

: <<'PUB_FUN'
Prints how many digits a one-page decision record's number is written with,
6 by default.
PUB_FUN
lint__config__decisions_number_digits() {
  @get __lint__config__decisions_number_digits__out "$1" '.decisions.number_digits' 6
  println "$__lint__config__decisions_number_digits__out"
}

: <<'PUB_FUN'
Prints the pattern that names the CI component templates, relative to the
repository root; templates/*/template.yml by default. A yaml file it does
not match is not a template, and the template checks skip it.
PUB_FUN
lint__config__templates_glob() {
  @get __lint__config__templates_glob__out "$1" '.templates.glob' 'templates/*/template.yml'
  println "$__lint__config__templates_glob__out"
}

: <<'PUB_FUN'
Prints the base template's path, relative to the repository root: the one
template allowed to define before_script. Nothing by default, which holds
every template to the rule.
PUB_FUN
lint__config__templates_base() {
  @get __lint__config__templates_base__out "$1" '.templates.base' ''
  println "$__lint__config__templates_base__out"
}

: <<'PUB_FUN'
Prints the landing mark as the templates' rules spell it: the text every
rule that matches a merge-request pipeline must contain. Nothing by default,
which turns the job-lands-once check off.
PUB_FUN
lint__config__templates_mark() {
  @get __lint__config__templates_mark__out "$1" '.templates.mark' ''
  println "$__lint__config__templates_mark__out"
}

: <<'PUB_FUN'
Prints the templates that run on every push to a merge request, marked or
not, as a struct array of paths relative to the repository root; empty by
default. Governance checks and previews go here.
PUB_FUN
lint__config__templates_every_push() {
  @arr __lint__config__templates_every_push__arr_6
  @get __lint__config__templates_every_push__out "$1" '.templates.every_push' "$__lint__config__templates_every_push__arr_6"
  println "$__lint__config__templates_every_push__out"
}
