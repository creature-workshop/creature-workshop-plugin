# Reads the git invocation of a lexed segment, over shell_lex.awk (load that
# first, then this, then the classifier). git_verb_index(s) is the index of
# segment s's git verb -- the first command word after the `git` program word
# and git's own flags, of which -C and -c carry an argument -- or 0 when the
# segment's command word is not git or no verb follows it. It leaves the
# segment's `git -C` path, possibly empty, in segment_cpath.

function git_verb_index(s, __ci, __i) {
  segment_cpath = ""
  __ci = command_index(s)
  if (__ci == 0 || !is_program(words[__ci], "git")) {
    return 0
  }
  for (__i = __ci + 1; __i <= nwords && seg[__i] == s; __i++) {
    if (!is_command_word(__i)) {
      continue
    }
    if (words[__i] == "-C" || words[__i] == "-c") {
      __i += note_git_option(__i)
      continue
    }
    if (words[__i] ~ /^-/) {
      continue
    }
    return __i
  }
  return 0
}

# Record a -C path; returns the one extra word -C and -c each carry.
function note_git_option(i) {
  if (words[i] == "-C") {
    segment_cpath = words[i + 1]
  }
  return 1
}
