# Exits 0 when the variable `line` is a pipe table's alignment row, 1 when it
# is not. Reads no input. Loaded after lines.awk.

BEGIN { exit !is_table_separator(line) }
