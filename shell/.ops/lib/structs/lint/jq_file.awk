# Reports each jq program file among <files...> that has no allow marker:
#
#   awk -f jq_file.awk <files...>
#
# Every file given is taken to be a jq program; the caller chooses them by
# name. A file is reported at its first line, because the finding is the
# file itself. A file that has `# jq-program-check: allow` in a comment
# line of its own, anywhere in the file, is left alone.
#
# Output: "<file>:1: <message>".

function main(line) {
  if (FNR == 1) {
    report_unmarked()
    start_file()
  }
  if (is_allow_marker(line)) {
    marked = 1
  }
}

# Reports the file that has just been read, when it has no allow marker.
function report_unmarked() {
  if (reading && !marked) {
    printf "%s:1: %s\n", name, "a jq program; use the structs verbs in the shell code that calls it"
  }
}

function start_file() {
  name = FILENAME
  reading = 1
  marked = 0
}

function is_allow_marker(line) {
  return line ~ /^[ \t]*#.*jq-program-check:[ \t]*allow/
}

{ main($0) }
END { report_unmarked() }
