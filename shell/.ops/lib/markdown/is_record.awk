# Exits 0 when the path in the variable `path` names a decision record under
# the folder in the variable `folder`, 1 when it does not. Reads no input.
# Loaded after records.awk.

BEGIN { exit !is_record(path, folder) }
