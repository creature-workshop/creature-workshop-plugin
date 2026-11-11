#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/api.sh"

: <<'MODULE'
The banner-comment check, enforcement for the banners-mean-split rule: a banner comment marks a section
boundary the language cannot enforce, and the rule wants that boundary made
real -- its own file -- instead of drawn or labelled. Two detectors scan
shell, awk, jq, and bats sources: one rejects comment lines drawn as
dividers, the other rejects free-floating comment runs -- whole-line
comments followed by a blank line or EOF instead of the code they document,
which makes them section labels whatever they are drawn with.

The detectors are awks over the shell-scan scanner runtime, so heredoc
bodies (usage text, embedded fixtures) are never policed. The file preamble
-- the comment runs above the first code line -- is exempt from the floating
check, and directive comments (shellcheck, bats tags, waivers) never flag.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__banner_comment__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/banner-comment"

# CONST: The scanner runtime every program is loaded with; it tracks the heredocs.
__lint__checks__shell__banner_comment__RUNTIME="$SHELL_SCAN_DIR/shell/scan/scan.awk"

: <<'FUN'
Prints every finding the divider and floating detectors report in <files...>,
as "<file>:<lineno>: <why>". Each detector is its own awk program (awk rules
cannot be namespaced), so the files are scanned once per detector, every
file in one run.
FUN
__lint__checks__shell__banner_comment__scan_files() {
  awk \
    -f "$__lint__checks__shell__banner_comment__RUNTIME" \
    -f "$__lint__checks__shell__banner_comment__DIR/divider_banner.awk" \
    "$@"

  awk \
    -f "$__lint__checks__shell__banner_comment__RUNTIME" \
    -f "$__lint__checks__shell__banner_comment__DIR/floating_comment.awk" \
    "$@"
}

: <<'FUN'
  Runs both banner detectors over <files...>, printing every offender it
  finds rather than stopping at the first.

  Usage: __lint__checks__shell__banner_comment__audit <files...>

  Returns 0 when every file is clean, 1 otherwise.
FUN
__lint__checks__shell__banner_comment__audit() {
  __lint__checks__shell__banner_comment__audit__hits="$(lint__call_with_existing __lint__checks__shell__banner_comment__scan_files "$@")"
  @defined "$__lint__checks__shell__banner_comment__audit__hits" || return 0

  log "$__lint__checks__shell__banner_comment__audit__hits"
  return 1
}

: <<'PUB_FUN'
  Rejects banner comments of either kind. A divider banner is a run of five
  or more identical divider characters after the character that opens the
  comment. A floating banner is a run of whole-line comments followed by a
  blank line or EOF instead of code -- a section label rather than a doc
  attached to the thing below. Either way a banner names a concern the file
  wants to shed; split that concern into its own file.

  Exempt from the floating check: the file preamble (the comment runs above
  the first code line), directive comments, and inline trailing comments.

  Usage: lint__checks__shell__banner_comment__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Waiver: a banner that is load-bearing data is kept with a
    `# banner-lint: allow` comment on, or within three lines above, the
    offending line (explaining why, per house style).

  Returns 0 if no file carries one, 1 otherwise (offenders printed to
  stderr).
PUB_FUN
lint__checks__shell__banner_comment__run() {
  shift
  __lint__checks__shell__banner_comment__audit "$@"
}
