# Joins a backslash-continued command into the one line the shell runs before
# the lexer reads it, so `import \` followed by one path per line lexes as a
# single command. Loaded before shell_lex.awk. A continuation inside a heredoc
# body is text and is left alone, and a file's open heredoc and pending
# continuation both end with the file.

FNR == 1 {
  in_heredoc = ""
  pending = ""
}

in_heredoc == "" && /\\$/ {
  pending = pending substr($0, 1, length($0) - 1)
  next
}

pending != "" {
  $0 = pending $0
  pending = ""
}
