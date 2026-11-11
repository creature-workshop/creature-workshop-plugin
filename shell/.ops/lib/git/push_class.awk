# Classifies the git pushes in a command. Prints exactly one line:
#   protected     a push names a protected branch (-v branches="main master")
#   bare\t<path>  a push gives no refspec; <path> is its `git -C` argument,
#                 possibly empty
#   none          no push does either
# A protected finding outranks a bare one; the first bare finding wins.
# Loaded after shell_lex.awk and git_lex.awk: the lexing keeps quoted
# arguments and heredoc bodies from ever standing as commands, and
# git_verb_index finds each segment's verb and `git -C` path.

function judge_record(__s) {
  for (__s = 1; __s <= nsegs; __s++) {
    judge_segment(__s)
  }
}

function judge_segment(s, __start) {
  __start = push_args_start(s)
  if (__start == 0) {
    return
  }
  grade_push(s, __start)
}

# The index of segment s's first word after a `git ... push`, or 0 when the
# segment runs no push. git_verb_index leaves the segment's `git -C` path in
# segment_cpath.
function push_args_start(s, __vi) {
  __vi = git_verb_index(s)
  if (__vi == 0 || words[__vi] != "push") {
    return 0
  }
  return __vi + 1
}

# Grade the push whose arguments start at index start: count positionals (the
# first is the remote) and test each later one's target branch against the
# protected set. -o/--push-option carry an argument, other flags skip.
function grade_push(s, start, __i, __positionals, __protected) {
  __positionals = 0
  __protected = 0
  for (__i = start; __i <= nwords && seg[__i] == s; __i++) {
    if (!is_command_word(__i)) {
      continue
    }
    if (words[__i] == "-o" || words[__i] == "--push-option") {
      __i++
      continue
    }
    if (words[__i] ~ /^-/) {
      continue
    }
    __positionals++
    if (__positionals >= 2 && protected_set[target_branch(words[__i])]) {
      __protected = 1
    }
  }
  fold_grade(__protected, __positionals)
}

# Fold one push's grade into the record-wide class.
function fold_grade(protected, positionals) {
  if (protected) {
    class = "protected"
    return
  }
  if (positionals <= 1 && class == "none") {
    class = "bare"
    bare_cpath = segment_cpath
  }
}

# The branch a refspec token lands on: the part after the last colon, without
# a leading + or a refs/heads/ prefix.
function target_branch(word, __n, __part) {
  sub(/^\+/, "", word)
  __n = split(word, __part, ":")
  word = __part[__n]
  sub(/^refs\/heads\//, "", word)
  return word
}

BEGIN {
  split(branches, __b, /[ \t]+/)
  for (__i in __b) {
    if (__b[__i] != "") {
      protected_set[__b[__i]] = 1
    }
  }
  class = "none"
  bare_cpath = ""
}

{
  judge_record()
}

END {
  if (class == "bare") {
    printf "bare\t%s\n", bare_cpath
  } else {
    print class
  }
}
