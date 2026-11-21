# Prints the record name the path in the variable `path` carries. Reads no
# input. Loaded after records.awk.

BEGIN { print record_name(path) }
