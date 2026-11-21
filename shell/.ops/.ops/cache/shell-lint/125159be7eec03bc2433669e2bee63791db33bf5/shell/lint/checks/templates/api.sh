#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
What the three checks on a catalog's CI component templates share, each a
module under shell/lint/checks:

  - template-declares-inputs: every template starts with a spec.inputs block.
  - template-inherits-bootstrap: only the base template defines
    before_script; every other job extends the base job.
  - job-lands-once: a job runs once per merge request, in the landing run,
    unless its template is listed as one that runs on every push.

Here are the facts they read from lint.json, the selection of the templates
among the files, and the runner of a detector with the yaml model loaded.
The checks read the catalog's facts from lint.json's `templates` block:
`glob` names the template files, `base` the base template, `mark` the
landing mark as the rules spell it, and `every_push` the templates that run
on every push. A yaml file `glob` does not match is not a template, and the
checks skip it.
MODULE

: <<'PUB_FUN'
Prints the template file pattern from <opts>.config, relative to the
repository root.

  lint__checks__templates__glob "$(@obj)"  ->  templates/*/template.yml
PUB_FUN
lint__checks__templates__glob() {
  lint__config__templates_glob "$(__lint__checks__templates__config "$1")"
}

: <<'PUB_FUN'
Prints the base template's path from <opts>.config, relative to the
repository root, or nothing when lint.json names none.
PUB_FUN
lint__checks__templates__base() {
  lint__config__templates_base "$(__lint__checks__templates__config "$1")"
}

: <<'PUB_FUN'
Prints the landing mark from <opts>.config, spelled as the templates' rules
spell it, or nothing when lint.json names none.
PUB_FUN
lint__checks__templates__mark() {
  lint__config__templates_mark "$(__lint__checks__templates__config "$1")"
}

: <<'PUB_FUN'
Prints the templates <opts>.config lists as running on every push, as a
struct array of paths relative to the repository root.
PUB_FUN
lint__checks__templates__every_push() {
  lint__config__templates_every_push "$(__lint__checks__templates__config "$1")"
}

: <<'FUN'
Prints the lint.json settings in <opts>, or an empty object when the run
has none.
FUN
__lint__checks__templates__config() {
  @obj __lint__checks__templates__config__none
  @get __lint__checks__templates__config__out "$1" '.config' "$__lint__checks__templates__config__none"
  println "$__lint__checks__templates__config__out"
}

: <<'FUN'
Prints <path> relative to PROJ, with any leading ./ removed. Every path is
compared in this form, so a caller may spell one absolutely or relatively.
FUN
__lint__checks__templates__key() {
  __lint__checks__templates__key__path="${1#"$PROJ"/}"
  println "${__lint__checks__templates__key__path#./}"
}

: <<'FUN'
Prints true when <path> exists and its relative form matches <glob>. The
pattern is a `case` pattern, so `*` also matches across directory
separators.
FUN
__lint__checks__templates__is_template() {
  # shellcheck disable=SC2254 # the pattern is the point: it must glob, unquoted.
  case "$(__lint__checks__templates__key "$1")" in
    $2)
      @succeeds __lint__checks__templates__is_template__out [ -f "$1" ]
      println "$__lint__checks__templates__is_template__out"
      ;;
    *)
      @false __lint__checks__templates__is_template__out
      println "$__lint__checks__templates__is_template__out"
      ;;
  esac
}

: <<'PUB_FUN'
Prints the templates among <files...>, one per line, in the order given:
the files that exist and match <opts>.config's pattern.

args:
  $1  The run's options
  $@  The files, after the options
PUB_FUN
lint__checks__templates__select() {
  lint__checks__templates__select__glob="$(lint__checks__templates__glob "$1")"
  shift

  for lint__checks__templates__select__file in "$@"; do
    if @is_true "$(__lint__checks__templates__is_template "$lint__checks__templates__select__file" "$lint__checks__templates__select__glob")"; then
      println "$lint__checks__templates__select__file"
    fi
  done
}

: <<'PUB_FUN'
Prints the lines of <files> whose relative form is not in the array
<exempt>, one per line.

args:
  $1  The files, one per line
  $2  The exempt paths (array)
PUB_FUN
lint__checks__templates__without() {
  args__call_with_lines __lint__checks__templates__keep_unless_exempt "$1" "$2"
}

: <<'FUN'
Prints each of <files...> that the array <exempt> does not name, one per
line.

args:
  $1  The exempt paths (array)
  $@  The files, after the array
FUN
__lint__checks__templates__keep_unless_exempt() {
  __lint__checks__templates__keep_unless_exempt__exempt="$1"
  shift

  for __lint__checks__templates__keep_unless_exempt__file in "$@"; do
    __lint__checks__templates__keep_unless_exempt__key="$(__lint__checks__templates__key "$__lint__checks__templates__keep_unless_exempt__file")"
    if @any __lint__checks__templates__keep_unless_exempt__any_1 __lint__checks__templates__key_eq "$__lint__checks__templates__keep_unless_exempt__exempt" "$__lint__checks__templates__keep_unless_exempt__key"; @is_false "$__lint__checks__templates__keep_unless_exempt__any_1"; then
      println "$__lint__checks__templates__keep_unless_exempt__file"
    fi
  done
}

: <<'FUN'
@any predicate: succeeds when the wrapped path $1 has the relative form $2.
FUN
__lint__checks__templates__key_eq() {
  @unwrap __lint__checks__templates__key_eq__unwrap_2 "$1"
  [ "$(__lint__checks__templates__key "$__lint__checks__templates__key_eq__unwrap_2")" = "$2" ]
}

: <<'PUB_FUN'
Runs the detector at the path <detector> over <files> in one awk and prints
its findings. Returns 0 when there are none, 1 otherwise. With no files the
detector is not run: an awk given no file reads stdin and waits.

args:
  $1  The detector's path
  $2  The files, one per line
PUB_FUN
lint__checks__templates__report() {
  @defined "$2" || return 0

  lint__checks__templates__report__hits="$(args__call_with_lines lint__checks__templates__awk "$2" "$1")"
  @defined "$lint__checks__templates__report__hits" || return 0

  println "$lint__checks__templates__report__hits"
  return 1
}

: <<'PUB_FUN'
Runs the detector at the path <detector> over <files...>, loading the shared
scanner, the yaml model and the document helpers before it.

args:
  $1  The detector's path
  $@  The files, after the path
PUB_FUN
lint__checks__templates__awk() {
  __lint__checks__templates__awk__program="$1"
  shift

  awk \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/yaml_scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/documents.awk" \
    -f "$__lint__checks__templates__awk__program" \
    "$@"
}
