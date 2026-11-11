# Pairs the two lines language__of_paths prints per file into one
# "<language>TAB<path>" record: a line led by a tab names the file and closes
# the record, and the line before it, when there is one, is the language.

/^\t/ {
  printf "%s\t%s\n", language, substr($0, 2)
  language = ""
  next
}

{
  language = $0
}
