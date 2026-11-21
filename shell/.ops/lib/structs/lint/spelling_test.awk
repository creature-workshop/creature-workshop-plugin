# Detector for the structs-lint scanners: a comment-stripped line that holds a
# value to a spelling by hand, where a type plugin's is role belongs. Three
# shapes: a case arm whose pattern runs a character class naming a range or a
# negation across the value (`*[!0-9]*`, `[0-9]*`), a grep handed a pattern
# anchored at both ends and no file to read, so the value comes down a pipe,
# and a bash `=~` against a regex anchored at its start. A class over one
# character (`[Yy]`) or of listed punctuation (`*[,;]*`) is a choice, not a
# spelling, and passes; so does a grep over a file, which searches rather than
# checks.
function lint_is_violation(line) {
  return (is_class_arm(line) || is_anchored_grep(line) || is_anchored_match(line))
}

# True when LINE is a case arm whose pattern holds a class across the value.
function is_class_arm(line, __pattern) {
  if (line !~ /^[[:space:]]*[^()]*\)([[:space:]]|$)/) {
    return 0
  }
  __pattern = line
  sub(/^[[:space:]]*/, "", __pattern)
  sub(/\).*/, "", __pattern)
  return spans_value(__pattern)
}

# True when PATTERN joins a class naming a range or a negation to a star, so
# the class is held across the whole value rather than one character. An
# escaped character is a literal, not a class, and is dropped first.
function spans_value(pattern) {
  gsub(/\\./, "", pattern)
  if (pattern ~ /\*\[(![^]]+|[^]]*[A-Za-z0-9]-[A-Za-z0-9][^]]*)\]/) {
    return 1
  }
  return (pattern ~ /\[(![^]]+|[^]]*[A-Za-z0-9]-[A-Za-z0-9][^]]*)\]\*/)
}

# True when LINE runs grep with a pattern anchored at both ends and nothing
# after it but the end of the command.
function is_anchored_grep(line) {
  return line ~ /grep([[:space:]]+-[A-Za-z]+)*[[:space:]]+['"]\^[^'"]*\$['"][[:space:]]*(\\|[;&|)]|$)/
}

# True when LINE matches a value against a regex anchored at its start.
function is_anchored_match(line) {
  return line ~ /=~[[:space:]]*\^/
}
