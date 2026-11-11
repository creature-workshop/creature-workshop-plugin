# Scans a Cargo.toml for a dep key under any [*dependencies*] section header.
# Exit 0 when found, 1 otherwise.
#
#   awk -f has_dep.awk -v dep=serde Cargo.toml

/^\[.*dependencies.*\]/ { s = 1; next }
/^\[/                   { s = 0; next }
s && $0 ~ "^[[:space:]]*\"?" dep "\"?[[:space:]]*=" { found = 1 }
END { exit !found }
