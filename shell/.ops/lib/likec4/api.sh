#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/self/assert.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Figures drawn as LikeC4 views, exported to images beside their sources.

A LikeC4 project is a directory of .c4 files. A view whose id opens with the
figure prefix, `f` by default, is a figure: view f1a becomes 1a.png in the
same directory, where it is committed and a document links it. Views without
the prefix are working views and are left alone. Dynamic views come out as
sequence diagrams.

The LikeC4 CLI is a tool the project locks. In ops.lock it is an npm tool, so
`ops install` brings node and puts likec4 on the PATH with no package.json:

  { "npm": { "likec4": { "version": "1.59.3", "bin": "bin/likec4.mjs" } } }

The PNG export drives a headless browser, and LikeC4 lays views out through
Graphviz's dot where that is installed.
MODULE

__likec4__VIEW_PREFIX="f"

: <<'PUB_FUN'
Exports every figure view of the LikeC4 project in <project-dir> to a PNG in
the same directory, named for the view without its prefix. A directory that
does not exist exports nothing, so a caller can pass every place a project
might be.

  likec4__export_figures adrs/0003-the-trunk-moves-once/figures
    ->  adrs/0003-the-trunk-moves-once/figures/1a.png

Fails when the sources do not parse, since an export draws whatever did parse
and exits clean, and when no figure came out, since LikeC4 reports a layout
that produced nothing as a warning and exits clean.

Usage: likec4__export_figures <project-dir> [view-prefix]
PUB_FUN
likec4__export_figures() {
  __likec4__export_figures__dir="$1"
  __likec4__export_figures__prefix="${2:-$__likec4__VIEW_PREFIX}"
  [ -d "$__likec4__export_figures__dir" ] || return 0

  likec4__assert_cli || return 1

  __likec4__validate "$__likec4__export_figures__dir" || return 1
  __likec4__export_png \
    "$__likec4__export_figures__dir" \
    "$__likec4__export_figures__prefix" \
    || return 1
  __likec4__require_figures \
    "$__likec4__export_figures__dir" \
    "$__likec4__export_figures__prefix" \
    || return 1
  __likec4__strip_view_prefix \
    "$__likec4__export_figures__dir" \
    "$__likec4__export_figures__prefix"
}

: <<'PUB_FUN'
Asserts that the LikeC4 CLI is on the PATH. On a miss it says so, how to
provision it, and the ops.lock entry that does, then returns 1.

  likec4__assert_cli
    ->  ERROR: likec4 is not installed
        HINT: Provision it with: shell/ops install likec4
PUB_FUN
likec4__assert_cli() {
  @obj __likec4__assert_cli__obj_1 \
    '.version' '<version>' \
    '.bin' 'bin/likec4.mjs'
  self__assert_tool likec4 npm "$__likec4__assert_cli__obj_1"
}

: <<'FUN'
Fails when the LikeC4 sources in <project-dir> do not parse.

Usage: __likec4__validate <project-dir>
FUN
__likec4__validate() {
  if ! likec4 validate "$1" >&2; then
    error "the LikeC4 sources in $1 are invalid"
    return 1
  fi
}

: <<'FUN'
Exports the views of <project-dir> whose id opens with <view-prefix> into the
same directory, one PNG per view, dynamic views as sequence diagrams.

LikeC4's preview server loads an AI assistant, and fetches its packages, when
it sees a provider key in the environment; an export needs neither, so the
keys are unset for the run.

Usage: __likec4__export_png <project-dir> <view-prefix>
FUN
__likec4__export_png() {
  CHOKIDAR_USEPOLLING=true env \
    -u ANTHROPIC_API_KEY \
    -u OPENAI_API_KEY \
    -u GOOGLE_GENERATIVE_AI_API_KEY \
    -u GEMINI_API_KEY \
    likec4 export png \
    --output "$1" \
    --flat \
    --seq \
    --filter "$2*" \
    "$1" \
    >&2
}

: <<'FUN'
Fails when <project-dir> holds no exported figure.

Usage: __likec4__require_figures <project-dir> <view-prefix>
FUN
__likec4__require_figures() {
  __likec4__require_figures__first="$(find "$1" -name "$2*.png" -print -quit)"
  if ! @defined "$__likec4__require_figures__first"; then
    error "LikeC4 exported no figure into $1; see its log above"
    return 1
  fi
}

: <<'FUN'
Renames every <view-prefix><id>.png in <project-dir> to <id>.png.

Usage: __likec4__strip_view_prefix <project-dir> <view-prefix>
FUN
__likec4__strip_view_prefix() {
  for __likec4__strip_view_prefix__png in "$1"/"$2"*.png; do
    [ -f "$__likec4__strip_view_prefix__png" ] || continue
    __likec4__strip_view_prefix__name="${__likec4__strip_view_prefix__png##*/}"
    mv \
      "$__likec4__strip_view_prefix__png" \
      "$1/${__likec4__strip_view_prefix__name#"$2"}"
  done
}
