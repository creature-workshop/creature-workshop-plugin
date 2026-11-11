# Prints the number the record name in the variable `name` carries, as
# written, or nothing when it carries none. Reads no input. Loaded after
# records.awk.

BEGIN { print number_of(name) }
