# Skips the lines the lexer need not read. Outside a heredoc body, a line
# that carries neither a heredoc operator nor one of the -v loaders as a
# word can neither open a body nor load a file, and lexing it character by
# character is most of the cost of reading a tree. Loaded after
# continuations.awk, so a joined command is judged whole, and before
# shell_lex.awk, whose own rule closes an open body on the line that ends it.

# A regex matching a line that has one of the space-separated loaders as a
# word: preceded by the line's start or a non-word character, and followed
# by its end or one, with "/" counted as a word character so "./x" and "a.b"
# never read as the word ".".
function loader_pattern(spec, __list, __n, __i, __alternatives) {
  __n = split(spec, __list, " ")
  __alternatives = ""
  for (__i = 1; __i <= __n; __i++) {
    __alternatives = __alternatives (__i > 1 ? "|" : "") regex_literal(__list[__i])
  }
  return "(^|[^A-Za-z0-9_/])(" __alternatives ")([^A-Za-z0-9_/]|$)"
}

# A word as a regex matching exactly it: every character that is not a
# letter, digit or underscore is backslash-escaped.
function regex_literal(word, __out, __i, __c) {
  __out = ""
  for (__i = 1; __i <= length(word); __i++) {
    __c = substr(word, __i, 1)
    if (__c ~ /[A-Za-z0-9_]/) {
      __out = __out __c
    } else {
      __out = __out "\\" __c
    }
  }
  return __out
}

BEGIN {
  loader_re = loader_pattern(loaders)
}

in_heredoc == "" && $0 !~ /<</ && $0 !~ loader_re {
  next
}
