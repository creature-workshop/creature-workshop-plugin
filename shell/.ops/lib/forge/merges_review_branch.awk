# Succeeds when any command in the input runs one of the review-merge
# signatures handed in as -v signatures="..." — adaptor-supplied command
# words joined by ";", e.g. each forge's CLI merge invocation. A segment
# matches when its command word names the signature's program and its
# following positionals spell the signature's remaining words. Loaded after
# lib/git's shell_lex.awk, whose lexing keeps quoted arguments and heredoc
# bodies from ever standing as commands. Signals by exit status, as a
# standalone awk program answering yes/no does.

function judge_record(__s) {
  for (__s = 1; __s <= nsegs; __s++) {
    if (segment_merges_review_branch(__s)) {
      found = 1
    }
  }
}

# True when segment s runs one of the signatures, flags between the words
# notwithstanding.
function segment_merges_review_branch(s, __ci, __k) {
  __ci = command_index(s)
  if (__ci == 0) {
    return 0
  }
  for (__k = 1; __k <= nsigs; __k++) {
    if (matches_signature(s, __ci, __k)) {
      return 1
    }
  }
  return 0
}

# True when the command at index ci of segment s spells signature k: its
# program word first, then each remaining signature word as a positional.
function matches_signature(s, ci, k, __i, __j) {
  if (!is_program(words[ci], sig[k, 1])) {
    return 0
  }
  __i = ci
  for (__j = 2; __j <= sig_len[k]; __j++) {
    __i = next_positional(s, __i)
    if (__i == 0 || words[__i] != sig[k, __j]) {
      return 0
    }
  }
  return 1
}

# The index of the next non-flag command word of segment s after index i, or
# 0; redirections and their targets are no positionals.
function next_positional(s, i, __j) {
  for (__j = i + 1; __j <= nwords; __j++) {
    if (seg[__j] != s) {
      return 0
    }
    if (!is_command_word(__j) || words[__j] ~ /^-/) {
      continue
    }
    return __j
  }
  return 0
}

BEGIN {
  nsigs = 0
  __n = split(signatures, __raw, ";")
  for (__i = 1; __i <= __n; __i++) {
    if (__raw[__i] != "") {
      nsigs++
      sig_len[nsigs] = split(__raw[__i], __w, /[ \t]+/)
      for (__j = 1; __j <= sig_len[nsigs]; __j++) {
        sig[nsigs, __j] = __w[__j]
      }
    }
  }
}

{
  judge_record()
}

END {
  exit !found
}
