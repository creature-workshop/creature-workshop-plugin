# Exits 0 when the variable `line` is a row of a pipe table, 1 when it is not.
# Reads no input. Loaded after lines.awk.

BEGIN { exit !is_table_row(line) }
