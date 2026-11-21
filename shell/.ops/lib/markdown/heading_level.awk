# Prints the level of the heading in the variable `line`, 0 for a line that is
# no heading. Reads no input. Loaded after lines.awk.

BEGIN { print heading_level(line) }
