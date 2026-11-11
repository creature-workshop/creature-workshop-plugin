# Prints the target of the inline link in the variable `link`. Reads no input.
# Loaded after lines.awk.

BEGIN { print link_target(link) }
