# How a shell line uses a name it holds. Loaded ahead of a check that reads
# names off a line:
#
#   awk -f scan.awk -f words.awk -f <check>.awk
#
# A check hands each function the text before the name, and for an
# assignment the two characters after it. The text is split into words on
# blanks and the separators a shell command list uses, so the word that
# governs the name is read without a pattern over the whole line.

# True when the text BEFORE a name reads it: it ends on $ or ${, or it opens
# an arithmetic expansion the name sits in.
function words_read(before, __open) {
  if (before ~ /[${]$/) {
    return 1
  }
  __open = before
  sub(/.*\)\)/, "", __open)
  return (__open ~ /\$\(\(/)
}

# True when the text BEFORE and the character AFTER show the name is not a
# whole shell name: a property after a dot, a path piece before an @, a
# piece of a name built around an expansion, or a word quoted on its own,
# which is a string such as a heredoc's terminator.
function words_foreign(before, after) {
  if (before ~ /[.}]$/ || after ~ /^[@$]/) {
    return 1
  }
  return (before ~ /['"]$/ && after == substr(before, length(before)))
}

# True when a name with the text BEFORE it and the two characters AFTER it is
# being assigned: `name=`, `name+=`, or the name after a binding word.
function words_assigned(before, after) {
  if (after ~ /^\+?=/) {
    return 1
  }
  return (words_governing(before) in words_assigning)
}

# The command word that governs the name after BEFORE: the last word once
# the flags between it and the name are dropped, or nothing when the name is
# not a word of its own.
function words_governing(before, __words, __count) {
  if (before !~ /[ \t]$/) {
    return ""
  }
  __count = split(before, __words, /[ \t;|&(]+/)
  while (__count > 0 && (__words[__count] == "" || __words[__count] ~ /^-/)) {
    __count--
  }
  return (__count > 0 ? __words[__count] : "")
}

# The words that bind the name after them, as read, for and unset do.
BEGIN {
  words_assigning["for"] = 1
  words_assigning["read"] = 1
  words_assigning["mapfile"] = 1
  words_assigning["readarray"] = 1
  words_assigning["local"] = 1
  words_assigning["declare"] = 1
  words_assigning["typeset"] = 1
  words_assigning["export"] = 1
  words_assigning["readonly"] = 1
  words_assigning["unset"] = 1
}
