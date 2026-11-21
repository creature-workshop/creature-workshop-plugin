# Reads paths on stdin, one per line, and prints each that names a decision
# record under the folder in the variable `folder`, in the order read. Loaded
# after records.awk, which says what a record is.
#
#     adrs/000007-fragments/adr.md   ->  adrs/000007-fragments/adr.md
#     adrs/template/adr.md           ->  (nothing)

is_record($0, folder) { print }
