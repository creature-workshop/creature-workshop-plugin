# Prints the value of the trailer named by -v token, read from the
# `git interpret-trailers --parse` lines on stdin: the last such trailer when
# the message carries several, and nothing when it carries none.

$1 == token ":" {
  line = $0
  sub(/^[^:]*:[[:space:]]*/, "", line)
  value = line
}

END {
  if (value != "") {
    print value
  }
}
