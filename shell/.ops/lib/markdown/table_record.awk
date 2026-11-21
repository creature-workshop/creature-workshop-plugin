# Prints the name of the record whose table file the path in the variable
# `path` is, or nothing when it is no table file. Reads no input. Loaded after
# records.awk.

BEGIN { print table_record(path) }
