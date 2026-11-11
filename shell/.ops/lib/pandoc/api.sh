#!/bin/sh

: <<'MODULE'
Document conversion with pandoc.

pandoc converts between markup formats: markdown, LaTeX, HTML, DOCX and
dozens more, with front matter carried as metadata and a template shaping
the output. This library wraps the conversions shellops runs; today that is
markdown to a standalone LaTeX document, which Tectonic (lib/tectonic) then
compiles, the two chained by the render action. pandoc is a system tool
declared in ops.lock.
MODULE

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'PUB_FUN'
Turns the markdown source $1 into a standalone LaTeX document under directory
$3 and prints the path of the .tex it wrote, named after the source. The
template $2, when given, shapes the document and the front matter fills its
variables; empty uses pandoc's own template. Only the path goes to stdout:
pandoc's own output is sent to stderr so a caller capturing the path never
picks it up.

    pandoc__markdown_to_tex src/one-pager.md templates/house.tex dist/.tex
      ->  dist/.tex/one-pager.tex
PUB_FUN
pandoc__markdown_to_tex() {
  __pandoc__markdown_to_tex__target="$3/$(basename "$1" .md).tex"
  mkdir -p "$3"
  if @defined "$2"; then
    pandoc "$1" --from markdown --to latex --standalone --template "$2" --output "$__pandoc__markdown_to_tex__target" >&2 || return 1
  else
    pandoc "$1" --from markdown --to latex --standalone --output "$__pandoc__markdown_to_tex__target" >&2 || return 1
  fi
  echo "$__pandoc__markdown_to_tex__target"
}
