# Exits 0 when the variable `text` holds an inline link, 1 when it does not.
# Reads no input. Loaded after lines.awk.

BEGIN { exit !has_link(text) }
