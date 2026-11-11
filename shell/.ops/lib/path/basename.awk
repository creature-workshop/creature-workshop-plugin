# Prints the last segment of the path in the variable `path`. Reads no input.
# Loaded after paths.awk.

BEGIN { print basename(path) }
