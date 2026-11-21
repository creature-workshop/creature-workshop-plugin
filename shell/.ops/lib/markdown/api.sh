#!/bin/sh
# Markdown documents for shellops.
#
# A document is a struct string array of lines; the builder verbs append to it
# and markdown__render joins it into a single string. The reader verbs go the
# other direction over already-rendered markdown: dropping the parts that are
# someone else's words, measuring what is left, and saying what one line or
# one link is. The record verbs say which markdown documents under a folder
# are a repository's decision records and which are the table files beside
# them, from the path alone.

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'PUB_FUN'
Appends a level-1 heading to the document.

Usage: markdown__h1 "$doc" "$header"
PUB_FUN
markdown__h1() {
  __markdown__h1__doc="$1"
  __markdown__h1__header="$2"
  @push __markdown__h1__out "$__markdown__h1__doc" "# $__markdown__h1__header"
  println "$__markdown__h1__out"
}

:<<'PUB_FUN'
Appends a level-2 heading to the document.

Usage: markdown__h2 "$doc" "$header"
PUB_FUN
markdown__h2() {
  __markdown__h2__doc="$1"
  __markdown__h2__header="$2"
  @push __markdown__h2__out "$__markdown__h2__doc" "## $__markdown__h2__header"
  println "$__markdown__h2__out"
}

:<<'PUB_FUN'
Appends a level-3 heading to the document.

Usage: markdown__h3 "$doc" "$header"
PUB_FUN
markdown__h3() {
  __markdown__h3__doc="$1"
  __markdown__h3__header="$2"
  @push __markdown__h3__out "$__markdown__h3__doc" "### $__markdown__h3__header"
  println "$__markdown__h3__out"
}

:<<'PUB_FUN'
Appends a level-4 heading to the document.

Usage: markdown__h4 "$doc" "$header"
PUB_FUN
markdown__h4() {
  __markdown__h4__doc="$1"
  __markdown__h4__header="$2"
  @push __markdown__h4__out "$__markdown__h4__doc" "#### $__markdown__h4__header"
  println "$__markdown__h4__out"
}

:<<'PUB_FUN'
Indents the last line of the document by two spaces.

Usage: markdown__tab "$doc"
PUB_FUN
markdown__tab() {
  __markdown__tab__doc="$1"
  __markdown__tab__peek=".[length-1]"
  @get __markdown__tab__get_1 "$__markdown__tab__doc" "$__markdown__tab__peek"
  @set __markdown__tab__out "$__markdown__tab__doc" "$__markdown__tab__peek" "\"  $__markdown__tab__get_1\""
  println "$__markdown__tab__out"
}

:<<'PUB_FUN'
Appends a bullet-list item to the document.

Usage: markdown__bullet "$doc" "$point"
PUB_FUN
markdown__bullet() {
  __markdown__bullet__doc="$1"
  __markdown__bullet__point="$2"
  @push __markdown__bullet__out "$__markdown__bullet__doc" "- $__markdown__bullet__point"
  println "$__markdown__bullet__out"
}

:<<'PUB_FUN'
Appends a raw line to the document.

Usage: markdown__line "$doc" "$content"
PUB_FUN
markdown__line() {
  __markdown__line__doc="$1"
  __markdown__line__content="$2"
  @push __markdown__line__out "$__markdown__line__doc" "$__markdown__line__content"
  println "$__markdown__line__out"
}

:<<'PUB_FUN'
Appends a blank line to the document.

Usage: markdown__nl "$doc"
PUB_FUN
markdown__nl() {
  @push __markdown__nl__out "$1" ""
  println "$__markdown__nl__out"
}

:<<'PUB_FUN'
Opens a fenced code block, optionally tagged with a language.

Usage: markdown__code_start "$doc" "$lang"
PUB_FUN
markdown__code_start() {
  __markdown__code_start__doc="$1"
  __markdown__code_start__lang="$2"
  @push __markdown__code_start__out "$__markdown__code_start__doc" "\`\`\`$__markdown__code_start__lang"
  println "$__markdown__code_start__out"
}

:<<'PUB_FUN'
Closes a fenced code block.

Usage: markdown__code_end "$doc"
PUB_FUN
markdown__code_end() {
  @push __markdown__code_end__out "$1" "\`\`\`"
  println "$__markdown__code_end__out"
}

:<<'PUB_FUN'
Renders the document into a single newline-joined string.

Usage: markdown__render "$doc"
PUB_FUN
markdown__render() {
  # Command substitution strips trailing newlines, so capture a newline with a
  # sentinel and strip it back off to get a literal "\n" separator in POSIX sh.
  __markdown__render__nl="$(printf '\n_')"
  @join __markdown__render__out "$1" "${__markdown__render__nl%_}"
  println "$__markdown__render__out"
}

:<<'PUB_FUN'
Formats a markdown link. Text defaults to the link target.

Usage: markdown__link "$link" "$text"
PUB_FUN
markdown__link() {
  __markdown__link__link="$1"
  __markdown__link__text="${2:-$1}"
  echo "[$__markdown__link__text]($__markdown__link__link)"
}

:<<'FUN'
Runs the named lib/markdown awk program over stdin, with lib/path/paths.awk,
lines.awk and records.awk loaded ahead of it so the shared classifications of
a path, a line and a record are in scope. A program that reads no input, one
answering a question about a value passed with -v, runs the same way.

Repeating -f is how awk spells "load this library": there is no include in the
language, and the one gawk added is an extension mawk rejects. Naming the
program here keeps that spelling in one place instead of at every call site.

Arguments after the program name go to awk as they are, which is how a program
takes a parameter: __markdown__awk paragraph_under_heading -v heading=About.

Usage: ... | __markdown__awk strip_code
FUN
__markdown__awk() {
  __markdown__awk__program="$1"
  shift
  awk \
    -f "$SHELLOPS_DIR/lib/path/paths.awk" \
    -f "$SHELLOPS_DIR/lib/markdown/lines.awk" \
    -f "$SHELLOPS_DIR/lib/markdown/records.awk" \
    -f "$SHELLOPS_DIR/lib/markdown/$__markdown__awk__program.awk" \
    "$@"
}

:<<'PUB_FUN'
Prints true when <line> is an ATX heading, false otherwise.

  markdown__is_heading "## Glossary"  ->  true
  markdown__is_heading "Glossary"     ->  false

Usage: markdown__is_heading <line>
PUB_FUN
markdown__is_heading() {
  @succeeds __markdown__is_heading__out __markdown__awk is_heading -v line="$1"
  println "$__markdown__is_heading__out"
}

:<<'PUB_FUN'
Prints the level of the heading <line>, the count of its hashes; 0 for a
line that is no heading.

  markdown__heading_level "## Glossary"  ->  2

Usage: markdown__heading_level <line>
PUB_FUN
markdown__heading_level() {
  __markdown__awk heading_level -v line="$1"
}

:<<'PUB_FUN'
Prints the text of the heading <line>, without its hashes.

  markdown__heading_text "## Glossary ##"  ->  Glossary

Usage: markdown__heading_text <line>
PUB_FUN
markdown__heading_text() {
  __markdown__awk heading_text -v line="$1"
}

:<<'PUB_FUN'
Prints true when <line> is a row of a pipe table, false otherwise.

  markdown__is_table_row "| a | b |"  ->  true

Usage: markdown__is_table_row <line>
PUB_FUN
markdown__is_table_row() {
  @succeeds __markdown__is_table_row__out __markdown__awk is_table_row -v line="$1"
  println "$__markdown__is_table_row__out"
}

:<<'PUB_FUN'
Prints true when <line> is a pipe table's alignment row, the one under its
header, false otherwise.

  markdown__is_table_separator "|---|:--:|"  ->  true
  markdown__is_table_separator "| a | b |"   ->  false

Usage: markdown__is_table_separator <line>
PUB_FUN
markdown__is_table_separator() {
  @succeeds __markdown__is_table_separator__out __markdown__awk is_table_separator -v line="$1"
  println "$__markdown__is_table_separator__out"
}

:<<'PUB_FUN'
Prints true when <text> holds an inline link, [text](target), false
otherwise.

  markdown__has_link "see [the form](docs/form.md)"  ->  true

Usage: markdown__has_link <text>
PUB_FUN
markdown__has_link() {
  @succeeds __markdown__has_link__out __markdown__awk has_link -v text="$1"
  println "$__markdown__has_link__out"
}

:<<'PUB_FUN'
Prints the text of the inline link <link>.

  markdown__link_text "[Table 1: Kinds](tables/kinds.md)"  ->  Table 1: Kinds

Usage: markdown__link_text <link>
PUB_FUN
markdown__link_text() {
  __markdown__awk link_text -v link="$1"
}

:<<'PUB_FUN'
Prints the target of the inline link <link>.

  markdown__link_target "[Table 1: Kinds](tables/kinds.md)"  ->  tables/kinds.md

Usage: markdown__link_target <link>
PUB_FUN
markdown__link_target() {
  __markdown__awk link_target -v link="$1"
}

:<<'PUB_FUN'
Prints true when <path> names a decision record under <folder>, false
otherwise. A record is a file named <number>-<slug>.md in the folder, or the
file adr.md in a directory named <number>-<slug> there; a table file beside a
record is not one.

  markdown__is_record adrs/000007-fragments/adr.md adrs            ->  true
  markdown__is_record docs/decisions/000034-a-climb.md docs/decisions  ->  true
  markdown__is_record adrs/template/adr.md adrs                    ->  false
  markdown__is_record adrs/000007-fragments/tables/kinds.md adrs   ->  false

Usage: markdown__is_record <path> <folder>
PUB_FUN
markdown__is_record() {
  @succeeds __markdown__is_record__out __markdown__awk is_record -v path="$1" -v folder="$2"
  println "$__markdown__is_record__out"
}

:<<'PUB_FUN'
Prints true when <path> names a table file of a decision record under
<folder>, the file <name>.md in the directory tables beside the record's
adr.md, false otherwise.

  markdown__is_table adrs/000007-fragments/tables/kinds.md adrs  ->  true
  markdown__is_table adrs/000007-fragments/adr.md adrs           ->  false

Usage: markdown__is_table <path> <folder>
PUB_FUN
markdown__is_table() {
  @succeeds __markdown__is_table__out __markdown__awk is_table -v path="$1" -v folder="$2"
  println "$__markdown__is_table__out"
}

:<<'PUB_FUN'
Reads paths on stdin, one per line, and prints the ones that name a decision
record under <folder>, in the order read. One awk answers for the whole list,
so a caller with many paths asks once rather than once per path with
markdown__is_record.

  printf '%s\n' adrs/000007-fragments/adr.md adrs/template/adr.md \
    | markdown__records_among adrs
    ->  adrs/000007-fragments/adr.md

Usage: ... | markdown__records_among <folder>
PUB_FUN
markdown__records_among() {
  __markdown__awk records_among -v folder="$1"
}

:<<'PUB_FUN'
Reads paths on stdin, one per line, and prints the ones that name a table
file of a decision record under <folder>, in the order read. One awk answers
for the whole list, as markdown__records_among does for records.

  printf '%s\n' adrs/000007-fragments/tables/kinds.md adrs/000007-fragments/adr.md \
    | markdown__tables_among adrs
    ->  adrs/000007-fragments/tables/kinds.md

Usage: ... | markdown__tables_among <folder>
PUB_FUN
markdown__tables_among() {
  __markdown__awk tables_among -v folder="$1"
}

:<<'PUB_FUN'
Prints the record name <path> carries: the file's name, or the directory's
when the file is adr.md.

  markdown__record_name adrs/000007-fragments/adr.md         ->  000007-fragments
  markdown__record_name docs/decisions/000034-a-climb.md    ->  000034-a-climb.md

Usage: markdown__record_name <path>
PUB_FUN
markdown__record_name() {
  __markdown__awk record_name -v path="$1"
}

:<<'PUB_FUN'
Prints the number the record name <name> carries, as written, or nothing
when it carries none.

  markdown__record_number 000007-fragments  ->  000007
  markdown__record_number template          ->  (nothing)

Usage: markdown__record_number <name>
PUB_FUN
markdown__record_number() {
  __markdown__awk record_number -v name="$1"
}

:<<'PUB_FUN'
Prints the name of the record whose table file <path> is, or nothing when
<path> is no table file.

  markdown__table_record adrs/000007-fragments/tables/kinds.md  ->  000007-fragments

Usage: markdown__table_record <path>
PUB_FUN
markdown__table_record() {
  __markdown__awk table_record -v path="$1"
}

:<<'PUB_FUN'
Drops code from stdin -- fenced blocks and inline backtick spans alike --
printing the prose around it.

For readers of markdown the rest of this module builds: code is quoted material,
a pasted log or a sample of syntax, so anything scanning a document for
statements its author is making should not see inside it. An MR whose
description quotes a log line reading "Closed OPS-299" is otherwise
indistinguishable from one declaring that closure.

Spans count for the same reason, and learning that cost three issues: review
comments explaining this matcher wrote `Closes OPS-1` as an example, and the
merge closed OPS-1. A span is how anyone writes syntax they are talking about
rather than using.

Usage: ... | markdown__strip_code
PUB_FUN
markdown__strip_code() {
  __markdown__awk strip_code
}

:<<'PUB_FUN'
Prints true when stdin opens with a blockquote, false otherwise.

Leading blank lines are looked past, so the question is about the first line
with anything on it.

The awk program signals by exit status, as a command must; this is the boundary
where that becomes a value.

Usage: if [ "$(printf '%s\n' "$body" | markdown__has_leading_quote)" = true ]; then
PUB_FUN
markdown__has_leading_quote() {
  @succeeds __markdown__has_leading_quote__out __markdown__awk has_leading_quote
  println "$__markdown__has_leading_quote__out"
}

:<<'PUB_FUN'
Drops a leading blockquote from stdin, printing what follows it.

The reader half of the same idea as markdown__strip_code: quoted text is
someone else's words. Here it is specifically the quoted parent of a reply,
which is how a reply is spelled on a forge that has no real reply threads.

Only a leading run of quoted lines is dropped, so a quote the author uses
mid-thought survives. Blank lines above and below that run go with it, and
leading blank lines are dropped whether or not a quote follows them -- pair
this with markdown__has_leading_quote when the distinction matters.

Usage: ... | markdown__strip_leading_quote
PUB_FUN
markdown__strip_leading_quote() {
  __markdown__awk strip_leading_quote
}

:<<'PUB_FUN'
Reduces markdown to the prose a reader reads, as one whitespace-normalized line.
Quoted text, code, and the markup that carries structure rather than meaning are
dropped, so the result measures what was written rather than how it was
formatted.

Usage: markdown__prose_text "$markdown"
PUB_FUN
markdown__prose_text() {
  println "$1" | __markdown__awk strip_prose
}

:<<'PUB_FUN'
Counts the characters of prose in markdown -- the budget a length limit is
measured against.

Usage: markdown__prose_len "$markdown"
PUB_FUN
markdown__prose_len() {
  __markdown__prose_len__text="$(markdown__prose_text "$1")"
  printf '%s' "$__markdown__prose_len__text" | wc -m | tr -d ' '
}

:<<'PUB_FUN'
Prints the inline links in the markdown on stdin, one per line as written,
[text](target), in order; links inside fenced code are left out.

  printf '%s\n' 'See [the form](docs/form.md).' | markdown__links
    ->  [the form](docs/form.md)

Usage: ... | markdown__links
PUB_FUN
markdown__links() {
  __markdown__awk links
}

:<<'PUB_FUN'
Prints the first paragraph under the named heading, from the markdown on stdin,
as one line with its line breaks turned into single spaces. The heading matches
on its text at any level; the paragraph ends at a blank line, the next heading,
or a code fence. Prints an empty line when the heading is absent or nothing but
another heading follows it.

The reader for a document that keeps one paragraph in step with a source
elsewhere -- a profile's About beside a resume's summary -- so the two can be
compared as values.

Usage: markdown__paragraph_under_heading "About" < profile.md
PUB_FUN
markdown__paragraph_under_heading() {
  __markdown__awk paragraph_under_heading -v heading="$1"
}
