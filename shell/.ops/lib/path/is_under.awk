# Exits 0 when the path in the variable `path` sits under the folder in the
# variable `folder`, 1 when it does not. Reads no input. Loaded after
# paths.awk.

BEGIN { exit !is_under(path, folder) }
