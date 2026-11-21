# Reads paths on stdin, one per line, and prints for each the one-page record
# it belongs to under the folder in the variable `folder`: the path itself
# when it is a record named adr.md, the adr.md beside its tables directory
# when it is a table file, and nothing for any other path. One awk answers for
# the whole list. Loaded after lib/markdown/records.awk, which says what a
# record and a table file are.
#
#     adrs/000007-fragments/adr.md            ->  adrs/000007-fragments/adr.md
#     adrs/000007-fragments/tables/kinds.md   ->  adrs/000007-fragments/adr.md
#     adrs/000007-fragments/notes.md          ->  (nothing)

function record_of(path) {
  if (is_table(path, folder)) {
    return beside_tables(path) "/adr.md"
  }
  if (path ~ /\/adr\.md$/ && is_record(path, folder)) {
    return path
  }
  return ""
}

# The directory that holds the tables directory of the table file at `path`.
function beside_tables(path) {
  sub(/\/tables\/[^\/]*$/, "", path)
  return path
}

record_of($0) != "" { print record_of($0) }
