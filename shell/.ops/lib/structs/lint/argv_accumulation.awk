# Detector for the structs-lint scanners (loaded via `awk -f` alongside
# scan_file.awk / scan_diff.awk). Returns true when a comment-stripped source
# line grows the positional parameters by hand -- `set -- "$@" ...` -- where
# `@apply` runs a command over a struct array's elements as its arguments.
#
# The idiom is recognised by its opening: `set --` followed by `"$@"` as the
# first word kept, which is an argument list being appended to. A plain
# `set --` that resets the list, or one that binds new positionals outright,
# is not the shape.
function lint_is_violation(line) {
  return line ~ /(^|[[:space:];&|{(])[[:space:]]*set[[:space:]]+--[[:space:]]+"\$@"([[:space:]]|$)/
}
