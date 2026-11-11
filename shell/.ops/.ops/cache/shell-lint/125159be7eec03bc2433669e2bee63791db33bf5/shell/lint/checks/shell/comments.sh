#!/bin/sh

: <<'MODULE'
What the comment checks share: the audit that runs one detector over the
files, the doc-block model the detectors load, and the two prose caps. The
ten checks under shell/lint/checks read the same thing -- the prose a shell
source carries about itself -- and differ only in what they object to, so
each is a detector awk over shell-scan's scanner and lib/doc_block.awk,
driven through lint__checks__shell__comments__audit.

The two prose-line caps below were measured over the 588 doc blocks in this
repository. Of 522 function docs, 516 sit at ten prose lines or fewer, four
reach eleven, and the remaining two jump straight to fourteen. Of 66 module
headers, 55 sit at ten or fewer, a handful run to sixteen, one reaches
twenty-four, and two run past it. Each cap is set in the gap the distribution
leaves, so it admits every block written the way the rest of them are and
catches only the ones that broke away. A header gets twice the allowance
because it introduces a whole file rather than one function.
MODULE

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/api.sh"

# CONST: The scanner runtime every program is loaded with; it tracks the heredocs.
__lint__checks__shell__comments__RUNTIME="$SHELL_SCAN_DIR/shell/scan/scan.awk"

# CONST: The most prose lines a function's doc block may run to.
__lint__checks__shell__comments__FUNC_DOC_CAP=12

# CONST: The most prose lines a module's doc block may run to.
__lint__checks__shell__comments__MODULE_DOC_CAP=24

: <<'FUN'
Prints every finding the detector lint__checks__shell__comments__audit named reports in
<files...>, as "<file>:<lineno>: <why>", every file in one awk.

Both caps and the repository root are passed to every detector rather than
only to the ones that read them, so the invocation is the same shape whichever
check is running.
FUN
__lint__checks__shell__comments__scan_files() {
  awk \
    -v func_cap="$__lint__checks__shell__comments__FUNC_DOC_CAP" \
    -v header_cap="$__lint__checks__shell__comments__MODULE_DOC_CAP" \
    -v root="$PROJ" \
    -v library_roots="$__lint__checks__shell__comments__audit__roots" \
    -f "$__lint__checks__shell__comments__RUNTIME" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/library_root.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/doc_block.awk" \
    -f "$__lint__checks__shell__comments__audit__detector" \
    "$@"
}

: <<'PUB_FUN'
  Runs the detector at the path <detector> over <files...>, printing every
  offender it finds rather than stopping at the first. A check's run role
  calls this with its own detector.

  Usage: lint__checks__shell__comments__audit <detector> <opts> <files...>

  The library roots a detector keys a file by come from the options' config,
  or the defaults.

  Returns 0 when every file is clean, 1 otherwise.
PUB_FUN
lint__checks__shell__comments__audit() {
  __lint__checks__shell__comments__audit__detector="$1"
  @obj __lint__checks__shell__comments__audit__obj_1
  @get __lint__checks__shell__comments__audit__get_2 "$2" '.config' "$__lint__checks__shell__comments__audit__obj_1"
  @join __lint__checks__shell__comments__audit__roots "$(lint__config__library_roots "$__lint__checks__shell__comments__audit__get_2")" ' '
  shift 2

  __lint__checks__shell__comments__audit__hits="$(lint__call_with_existing __lint__checks__shell__comments__scan_files "$@")"
  @defined "$__lint__checks__shell__comments__audit__hits" || return 0

  log "$__lint__checks__shell__comments__audit__hits"
  return 1
}
