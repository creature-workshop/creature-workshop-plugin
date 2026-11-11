# Detector for the structs-lint scanners (loaded via `awk -f` alongside
# scan_file.awk / scan_diff.awk). Returns true when a comment-stripped source
# line spells an empty struct as a quoted `[]` or `{}` literal, where the `@arr`
# / `@obj` constructors belong.
#
# The literal must be a whole quoted word -- preceded by start of line,
# whitespace, or `=` -- so type-spec suffixes keep working: `*'[]')` and
# `${spec%'[]'}` match those two characters without meaning an empty array.
function lint_is_violation(line) {
  return line ~ /(^|[[:space:]]|=)('\[[[:space:]]*\]'|"\[[[:space:]]*\]"|'\{[[:space:]]*\}'|"\{[[:space:]]*\}")/
}
