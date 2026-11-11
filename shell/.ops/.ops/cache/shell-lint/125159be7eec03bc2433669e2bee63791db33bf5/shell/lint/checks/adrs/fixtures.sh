#!/bin/sh

: <<'FRAGMENT'
The on-disk shapes a test of the decision-record checks needs: a repository
whose docs/decisions holds records, a default branch that has moved on with a
record of its own, and a one-page record in a directory of its own. Paths are
given, never read from a harness variable.

The one-page samples sit beside this file: one_page.fixture.md keeps the form,
misshapen.fixture.md breaks its shape, loose_citations.fixture.md cites
without linking, unapproved.fixture.md still says proposed, and
superseded.fixture.md names the record that superseded it. with_table.fixture.md
references the table beside it, fenced_table.fixture.md keeps a table in a
fence instead, and mistitled_table.fixture.md links a table by another title
and one that is not there.

The table samples: table.fixture.md keeps the table shape, bare_table.fixture.md
has no title, a short summary and no glossary, and two_tables.fixture.md has a
second table after the first.
FRAGMENT

__lint__checks__adrs__FIXTURES="$SHELL_LINT_DIR/shell/lint/checks/adrs"

: <<'PUB_FUN'
Builds a repository at <dir> whose one commit holds a decision record for each
name that follows, with origin's default branch at that commit. Prints <dir>.

Usage: lint__checks__adrs__fixture_repo "$BATS_TEST_TMPDIR/repo" 000001-a-first.md
PUB_FUN
lint__checks__adrs__fixture_repo() {
  __lint__checks__adrs__fixture_repo__dir="$1"
  shift

  git init -q -b main "$__lint__checks__adrs__fixture_repo__dir"
  git -C "$__lint__checks__adrs__fixture_repo__dir" config user.name test
  git -C "$__lint__checks__adrs__fixture_repo__dir" config user.email test@example.com
  git -C "$__lint__checks__adrs__fixture_repo__dir" config commit.gpgSign false
  mkdir -p "$__lint__checks__adrs__fixture_repo__dir/docs/decisions"

  for __lint__checks__adrs__fixture_repo__name in "$@"; do
    lint__checks__adrs__fixture_record \
      "$__lint__checks__adrs__fixture_repo__dir" \
      "$__lint__checks__adrs__fixture_repo__name" \
      >/dev/null
  done

  git -C "$__lint__checks__adrs__fixture_repo__dir" add docs
  git -C "$__lint__checks__adrs__fixture_repo__dir" commit -q --allow-empty -m records
  git -C "$__lint__checks__adrs__fixture_repo__dir" update-ref refs/remotes/origin/main HEAD

  println "$__lint__checks__adrs__fixture_repo__dir"
}

: <<'PUB_FUN'
Writes the decision record <name> into the working tree of the repository at
<dir>, uncommitted, the way a branch drafts one. Prints the record's path.

Usage: lint__checks__adrs__fixture_record <dir> <name>
PUB_FUN
lint__checks__adrs__fixture_record() {
  printf '# %s\n' "${2%.md}" > "$1/docs/decisions/$2"
  println "$1/docs/decisions/$2"
}

: <<'PUB_FUN'
Adds the decision record <name> to origin's default branch of the repository
at <dir> in a commit HEAD does not have, the way another merge lands while a
branch is open. The working tree is left as it was.

Usage: lint__checks__adrs__fixture_upstream_record <dir> <name>
PUB_FUN
lint__checks__adrs__fixture_upstream_record() {
  git -C "$1" checkout -q -b upstream refs/remotes/origin/main
  lint__checks__adrs__fixture_record "$1" "$2" >/dev/null
  git -C "$1" add "docs/decisions/$2"
  git -C "$1" commit -q -m "upstream: $2"
  git -C "$1" update-ref refs/remotes/origin/main HEAD
  git -C "$1" checkout -q main
  git -C "$1" branch -q -D upstream
}

: <<'PUB_FUN'
Writes the sample <sample> into the working tree of the repository at <dir> as
the one-page record <folder>/<name>/adr.md, uncommitted. Prints the record's
path.

  lint__checks__adrs__fixture_one_page "$repo" adrs 000007-fragments one_page
    ->  $repo/adrs/000007-fragments/adr.md

Usage: lint__checks__adrs__fixture_one_page <dir> <folder> <name> <sample>
PUB_FUN
lint__checks__adrs__fixture_one_page() {
  mkdir -p "$1/$2/$3"
  cp "$__lint__checks__adrs__FIXTURES/$4.fixture.md" "$1/$2/$3/adr.md"
  println "$1/$2/$3/adr.md"
}

: <<'PUB_FUN'
Writes the sample <sample> into the working tree of the repository at <dir>
as the table file <folder>/<name>/tables/<table>.md, uncommitted. Prints the
table file's path.

  lint__checks__adrs__fixture_table "$repo" adrs 000007-fragments kinds table
    ->  $repo/adrs/000007-fragments/tables/kinds.md

Usage: lint__checks__adrs__fixture_table <dir> <folder> <name> <table> <sample>
PUB_FUN
lint__checks__adrs__fixture_table() {
  mkdir -p "$1/$2/$3/tables"
  cp "$__lint__checks__adrs__FIXTURES/$5.fixture.md" "$1/$2/$3/tables/$4.md"
  println "$1/$2/$3/tables/$4.md"
}
