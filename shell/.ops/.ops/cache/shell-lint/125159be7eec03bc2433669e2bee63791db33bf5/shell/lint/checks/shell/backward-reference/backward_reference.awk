# Flags comment prose that describes the code's past. A comment states what the
# code does now; the reader has only the file in front of them, so a sentence
# about what it did before sends them looking for something that is not there.
# History is what the commit log is for. Loaded with the scanner runtime and the
# doc-block library:
#   awk -f scan.awk -f doc_block.awk -f backward_reference.awk
#
# Prose means doc blocks and `#` comments. Data heredocs are skipped: usage text
# and embedded programs are output, not commentary about the source.
#
# The marker set is deliberately narrow. Each phrase below is past-tense about
# its subject in every English reading, so a match is a finding rather than a
# candidate. The near misses were measured and left out: "used to" alone is
# usually purpose ("used to guard mutations"), and "no longer" alone is usually
# a present-tense condition ("dropped when no longer due"). Both run about half
# false positives on this corpus, which is worse than missing the few real ones.
#
# Emits "<name>:<lineno>: <message>" anchored to the offending line.
# Vars: -v fname=<display name> (default FILENAME).

# True when TEXT contains a phrase that can only be talking about the past.
# "previously" is excluded when hyphen-joined, where it modifies a noun and
# describes a state rather than a change ("a previously-clean repo").
function has_backward_reference(text) {
  if (text ~ /(^|[^A-Za-z])[Ff]ormerly([^A-Za-z]|$)/) {
    return 1
  }
  if (text ~ /(^|[^A-Za-z])[Pp]reviously([^A-Za-z-]|$)/) {
    return 1
  }
  if (text ~ /(^|[^A-Za-z])[Uu]sed to be([^A-Za-z]|$)/) {
    return 1
  }
  if (text ~ /(^|[^A-Za-z])[Rr]enamed from([^A-Za-z]|$)/) {
    return 1
  }
  return 0
}

# The commentary on a code line: everything from its first `#`, or nothing when
# it carries no comment.
function comment_text(line, __text) {
  if (line !~ /#/) {
    return ""
  }
  __text = line
  sub(/^[^#]*#/, "", __text)
  return __text
}

function report(line) {
  note(line, "comment describes what the code used to do; state what it does now and leave the history to git")
}

FNR == 1 {
  in_heredoc = 0
  in_doc = 0
}

{
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
      in_doc = 0
    } else if (in_doc && has_backward_reference($0)) {
      report(FNR)
    }
    next
  }

  if (has_backward_reference(comment_text($0))) {
    report(FNR)
  }

  if (opens_heredoc($0)) {
    in_heredoc = 1
    in_doc = opens_doc_block($0)
  }
}
