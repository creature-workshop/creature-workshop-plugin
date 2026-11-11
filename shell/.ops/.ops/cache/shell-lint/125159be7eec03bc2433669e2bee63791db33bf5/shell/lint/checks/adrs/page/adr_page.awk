# Prints a finding for each decision record that spends more words of prose
# than the variable `page_words` allows, counted from its Context heading to
# its end. Fenced examples and figure lines are free, since neither is prose.
# Reads every record named on the command line, one awk for the whole list;
# a record is judged when the next one opens, and the last in END. Exits 1
# when there is a finding in any of them. Loaded after lib/markdown/lines.awk,
# which reads the fences.
#
#     a record of 512 words, page_words=450
#       ->  <file>:1: 512 words of prose; a page is 450

function main(line) {
  if (FNR == 1) {
    judge()
    begin_file(FILENAME)
  }
  if (is_code_fence(line) || in_fence) {
    return
  }
  if (line ~ /^## Context/) {
    counting = 1
    return
  }
  if (is_prose(line)) {
    words += NF
  }
}

# Starts reading the record at `path`: nothing counted yet, no fence open.
function begin_file(path) {
  record = path
  words = 0
  counting = 0
  in_fence = 0
}

# Reports the record read so far, when there is one, against the page.
function judge() {
  if (record == "") {
    return
  }
  if (words > page_words) {
    printf "%s:1: %s words of prose; a page is %s\n", record, words, page_words
    found = 1
  }
}

function is_prose(line) {
  return counting && line !~ /^!\[/
}

    { main($0) }
END { judge(); exit found }
