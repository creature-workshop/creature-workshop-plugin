# Reports each call of @jq in a shell source. Loaded with the scanner
# runtime:
#
#   awk -f scan.awk -f jq_call.awk <files...>
#
# A call is the word @jq where the shell reads a word of its own: at the
# start of the line or after a blank or one of ; & | (, and followed by a
# blank, one of ; & | ) or the end of the line. So `@jq out "$file" "$doc"`
# and `run printing @jq "$file" "$doc"` are calls, and "@jq: no result" in
# a message is not.
#
# A heredoc body and a comment are not read. A line that has
# `# jq-program-check: allow`, and the three lines below it, are left alone.
#
# Output: "<file>:<lineno>: <message>".

function main(line) {
  if (FNR == 1) {
    start_file()
  }
  if (in_heredoc) {
    if (closes_heredoc(line)) {
      in_heredoc = 0
    }
    return
  }
  if (has_allow_marker(line)) {
    allow_until = FNR + 3
  }
  if (opens_heredoc(line)) {
    in_heredoc = 1
  }
  if (FNR > allow_until && calls_jq(without_comment(line))) {
    note(FNR, "@jq runs a jq program; use the structs verbs")
  }
}

function start_file() {
  in_heredoc = 0
  allow_until = 0
}

function has_allow_marker(line) {
  return line ~ /jq-program-check:[ \t]*allow/
}

# LINE up to the # that opens its comment. A # opens a comment only at the
# start of a word, so the # in ${name#prefix} and in $# stays.
function without_comment(line) {
  sub(/(^|[ \t])#.*/, "", line)
  return line
}

function calls_jq(code) {
  return code ~ /(^|[ \t;&|(])@jq([ \t;&|)]|$)/
}

{ main($0) }
