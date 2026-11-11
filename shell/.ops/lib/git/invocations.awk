# Prints the git invocations in a command, one per line, as
# <dir>TAB<verb>TAB<args>: dir the segment's `git -C` path (possibly empty),
# verb the git verb (empty for a bare `git`), args the verb's arguments joined
# by -v sep. A segment whose command word is not git prints nothing. Loaded
# after shell_lex.awk and git_lex.awk, whose lexing keeps quoted arguments and
# heredoc bodies from ever standing as commands and redirections from counting
# as arguments.

function print_invocations(__s) {
  for (__s = 1; __s <= nsegs; __s++) {
    print_invocation(__s)
  }
}

# Print segment s's git invocation, or nothing when its command word is not
# git.
function print_invocation(s, __ci, __vi) {
  __ci = command_index(s)
  if (__ci == 0 || !is_program(words[__ci], "git")) {
    return
  }
  __vi = git_verb_index(s)
  printf "%s\t%s\t%s\n", segment_cpath, verb_word(__vi), verb_args(s, __vi)
}

# The verb at index vi, or nothing for a bare `git`.
function verb_word(vi) {
  return vi == 0 ? "" : words[vi]
}

# Segment s's command words after the verb at index vi, joined by sep.
function verb_args(s, vi, __i, __args) {
  __args = ""
  if (vi == 0) {
    return __args
  }
  for (__i = vi + 1; __i <= nwords && seg[__i] == s; __i++) {
    if (is_command_word(__i)) {
      __args = (__args == "" ? words[__i] : __args sep words[__i])
    }
  }
  return __args
}

{
  print_invocations()
}
