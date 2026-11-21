# Prints one finding per part of a table file's shape that is missing: the H1
# on its first line, the table's title; a summary after it of a quarter to
# half of the page the variable `page_words` gives; a "## Glossary" section;
# and one table after the glossary. Fenced blocks in the summary are free.
# Reads every table file named on the command line, one awk for the whole
# list; a file is judged when the next one opens, and the last in END. Exits
# 1 when there is a finding in any of them. Loaded after
# lib/markdown/lines.awk, which says what a heading, a fence and a table row
# are.
#
#     a file opening on prose, 15 words of summary and no glossary, page_words=450
#       ->  <file>:1: the title is an H1: "# <the table's title>"
#           <file>:1: the summary is 15 words; a quarter to half of the page is 112 to 225
#           <file>:1: the summary is followed by a "## Glossary" section

function main(line) {
  if (FNR == 1) {
    judge()
    begin_file(FILENAME)
    report_title(line)
    return
  }
  if (part == "table" && !is_table_row(line)) {
    part = "after"
  }
  if (is_code_fence(line) || in_fence) {
    return
  }
  if (opens_glossary(line)) {
    part = "glossary"
    glossary_line = FNR
    return
  }
  if (is_table_row(line)) {
    note_table_row()
    return
  }
  if (part == "summary") {
    words += NF
  }
}

# Starts reading the table file at `path`: in its summary, nothing seen yet.
function begin_file(path) {
  table = path
  part = "summary"
  words = 0
  glossary_line = 0
  tables_after_glossary = 0
  extra_reported = 0
  in_fence = 0
}

# Reports what the table file read so far is missing, when there is one.
function judge() {
  if (table == "") {
    return
  }
  report_summary()
  report_glossary()
}

function quarter() {
  return int(page_words / 4)
}

function half() {
  return int(page_words / 2)
}

function is_title(line) {
  return heading_level(line) == 1 && heading_text(line) != ""
}

function opens_glossary(line) {
  return heading_level(line) == 2 && heading_text(line) == "Glossary"
}

function note_table_row() {
  if (part == "after") {
    report_extra_table()
    return
  }
  if (part == "glossary") {
    tables_after_glossary++
  }
  part = "table"
}

function report(line_number, why) {
  printf "%s:%s: %s\n", table, line_number, why
  found = 1
}

function report_title(line) {
  if (!is_title(line)) {
    report(1, "the title is an H1: \"# <the table's title>\"")
  }
}

function report_summary() {
  if (words < quarter() || words > half()) {
    report(1, "the summary is " words " words; a quarter to half of the page is " quarter() " to " half())
  }
}

function report_glossary() {
  if (!glossary_line) {
    report(1, "the summary is followed by a \"## Glossary\" section")
    return
  }
  if (!tables_after_glossary) {
    report(glossary_line, "the glossary is followed by one table")
  }
}

function report_extra_table() {
  if (extra_reported) {
    return
  }
  report(FNR, "the glossary is followed by one table")
  extra_reported = 1
}

    { main($0) }
END { judge(); exit found }
