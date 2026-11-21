#!/bin/sh

: <<'FRAGMENT'
Fixtures for the pandoc domain: a markdown document with front matter, and a
pandoc LaTeX template carrying the definitions a rendered body relies on, each
a real file under fixtures/.
FRAGMENT

: <<'PUB_FUN'
Copies the fixture markdown document into directory $1, creating it, and
prints the document's path.
PUB_FUN
pandoc__fixture_markdown() {
  mkdir -p "$1"
  cp "$SHELLOPS_DIR/lib/pandoc/fixtures/one-pager.md" "$1/one-pager.md"
  echo "$1/one-pager.md"
}

: <<'PUB_FUN'
Copies the fixture pandoc template into directory $1, creating it, and prints
the template's path.
PUB_FUN
pandoc__fixture_template() {
  mkdir -p "$1"
  cp "$SHELLOPS_DIR/lib/pandoc/fixtures/house.tex" "$1/house.tex"
  echo "$1/house.tex"
}
