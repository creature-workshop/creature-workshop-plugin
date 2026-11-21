# Exits 0 when the variable `line` is a heading, 1 when it is not. Reads no
# input. Loaded after lines.awk.

BEGIN { exit !is_heading(line) }
