# Prints one finding per citation of a decision record that is not written
# ADR.<n>@<repository> as the text of a markdown link. Fenced examples are
# passed over. Reads every record named on the command line, one awk for the
# whole list. Exits 1 when there is a finding in any of them. Loaded after
# lib/markdown/lines.awk, which reads the fences.
#
#     See [ADR.34@tool](https://...).   ->  nothing
#     See ADR.34@tool.                   ->  "<file>:7: link the citation: ADR.34@tool"
#     See tool ADR 34.                   ->  "<file>:7: cite as ADR.<n>@<repository>: tool ADR 34"

function main(line) {
  if (FNR == 1) {
    in_fence = 0
  }
  if (is_code_fence(line) || in_fence) {
    return
  }
  report_unlinked(line)
  report_loose(line)
}

function report(why) {
  printf "%s:%s: %s\n", FILENAME, FNR, why
  found = 1
}

# True when TEXT holds a citation, ADR.<n>@<repository>; RSTART and RLENGTH
# then say where.
function has_citation(text) {
  return match(text, /ADR\.[0-9]+@[a-z0-9-]+/)
}

function report_unlinked(line, __rest, __before, __after) {
  __rest = line
  while (has_citation(__rest)) {
    __before = substr(__rest, RSTART - 1, 1)
    __after = substr(__rest, RSTART + RLENGTH, 2)
    if (__before != "[" || __after != "](") {
      report("link the citation: " substr(__rest, RSTART, RLENGTH))
    }
    __rest = substr(__rest, RSTART + RLENGTH)
  }
}

function report_loose(line) {
  if (match(line, /(G-ADR [0-9]+|ADR-[0-9]+|[a-z0-9-]+ ADR [0-9]+)/)) {
    report("cite as ADR.<n>@<repository>: " substr(line, RSTART, RLENGTH))
  }
}

    { main($0) }
END { exit found }
