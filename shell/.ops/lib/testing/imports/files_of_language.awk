# Prints the paths in language__of_paths' "<language>TAB<path>" lines whose
# language is the -v language, one per line.

BEGIN {
  FS = "\t"
}

$1 == language {
  print $2
}
