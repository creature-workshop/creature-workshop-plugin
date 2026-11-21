# Reads paths on stdin, one per line, and prints each that names a table file
# of a decision record under the folder in the variable `folder`, in the order
# read. Loaded after records.awk, which says what a table file is.
#
#     adrs/000007-fragments/tables/kinds.md  ->  adrs/000007-fragments/tables/kinds.md
#     adrs/000007-fragments/adr.md           ->  (nothing)

is_table($0, folder) { print }
