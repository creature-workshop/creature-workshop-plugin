# Prints the files a shell command loads, one per line as "<file>TAB<target>":
# the FILENAME the command sits in, and the argument as written, quotes bound
# away but variables unexpanded ("$SHELLOPS_DIR/lib/git/api.sh"). A loading
# command is a segment whose command word is one of the -v loaders
# (space-separated); every command word after it is a target, redirections
# excluded. Loaded after shell_lex.awk, whose reading keeps a word inside
# quotes or a heredoc body from ever standing as a command.

# Fill is_loader[word] from the space-separated spec.
function read_loaders(spec, __list, __n, __i) {
  __n = split(spec, __list, " ")
  for (__i = 1; __i <= __n; __i++) {
    is_loader[__list[__i]] = 1
  }
}

function print_targets(__s) {
  for (__s = 1; __s <= nsegs; __s++) {
    print_segment_targets(__s)
  }
}

# Print segment s's targets, or nothing when its command word loads no file.
function print_segment_targets(s, __ci, __i) {
  __ci = command_index(s)
  if (__ci == 0 || !(words[__ci] in is_loader)) {
    return
  }
  for (__i = __ci + 1; __i <= nwords && seg[__i] == s; __i++) {
    if (is_command_word(__i)) {
      printf "%s\t%s\n", FILENAME, words[__i]
    }
  }
}

BEGIN {
  read_loaders(loaders)
}

{
  print_targets()
}
