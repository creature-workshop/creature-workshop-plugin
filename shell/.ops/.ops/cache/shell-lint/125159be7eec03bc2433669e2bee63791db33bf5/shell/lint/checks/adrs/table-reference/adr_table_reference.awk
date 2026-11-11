# Prints one finding per table file beside a decision record that the record
# does not reference, per link in the record to a table file that is not
# there or whose text is not "Table <k>: " and the table's title, and per
# Markdown table the record keeps in a fenced block. Reads the record's table
# files first and the record last, the record's path being in the variable
# `record` whether or not the file exists. Exits 1 when there is a finding.
# Loaded after lib/path/paths.awk and lib/markdown/lines.awk, which say what
# a path's last segment, a heading, a fence, a link and a table row are.
#
#     adrs/000007-fragments/tables/kinds.md, titled "The kinds of change", and
#     adrs/000007-fragments/adr.md, which never links it
#       ->  adrs/000007-fragments/adr.md:1: the record references its table: [Table <k>: The kinds of change](tables/kinds.md)

function main(line) {
  if (FILENAME != record) {
    note_table(line)
    return
  }
  if (is_code_fence(line)) {
    fence_reported = 0
    return
  }
  if (in_fence) {
    report_fenced_table(line)
    return
  }
  report_links(line)
}

function verdict(__i) {
  for (__i = 1; __i <= count; __i++) {
    report_unreferenced(keys[__i])
  }
  return found
}

function note_table(line, __key) {
  if (FNR != 1) {
    return
  }
  __key = "tables/" basename(FILENAME)
  keys[++count] = __key
  title[__key] = heading_text(line)
}

# True when LINK points into the record's tables directory.
function is_table_link(link) {
  return link_target(link) ~ /^tables\/[^\/]+\.md$/
}

# True when LINK's text has the form "Table <k>: <title>".
function has_table_text(link) {
  return link_text(link) ~ /^Table [0-9]+: ./
}

# The number a link's text carries after "Table", or <k> when it carries none.
function link_number(link) {
  if (!match(link_text(link), /[0-9]+/)) {
    return "<k>"
  }
  return substr(link_text(link), RSTART, RLENGTH)
}

# The title a link's text carries, after "Table <k>: ".
function link_title(link, __text) {
  __text = link_text(link)
  sub(/^Table [0-9]+: /, "", __text)
  return __text
}

function report(line_number, why) {
  printf "%s:%s: %s\n", record, line_number, why
  found = 1
}

# Every match() in the program sets RSTART and RLENGTH, so the end of the
# link is kept before report_link runs: a text with no number leaves match()
# with RSTART 0 and RLENGTH -1, and substr from there is the whole line again.
function report_links(line, __rest, __link, __end) {
  __rest = line
  while (has_link(__rest)) {
    __link = substr(__rest, RSTART, RLENGTH)
    __end = RSTART + RLENGTH
    if (is_table_link(__link)) {
      report_link(__link)
    }
    __rest = substr(__rest, __end)
  }
}

function report_link(link, __target) {
  __target = link_target(link)
  if (!(__target in title)) {
    report(FNR, "no table is at " __target)
    return
  }
  seen[__target] = 1
  if (!has_table_text(link) || link_title(link) != title[__target]) {
    report(FNR, "the link's text is \"Table <k>: \" and the table's title: [Table " link_number(link) ": " title[__target] "](" __target ")")
  }
}

function report_fenced_table(line) {
  if (fence_reported || !is_table_separator(line)) {
    return
  }
  report(FNR, "a table is a figure: move it to tables/<name>.md and reference it as [Table <k>: <title>](tables/<name>.md)")
  fence_reported = 1
}

function report_unreferenced(key) {
  if (key in seen) {
    return
  }
  report(1, "the record references its table: [Table <k>: " title[key] "](" key ")")
}

    { main($0) }
END { exit verdict() }
