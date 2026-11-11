# Reads markdown on stdin and prints the first paragraph under the heading named
# by -v heading=..., as one line, its line breaks turned into single spaces. The
# heading matches on its text at any level, and the paragraph is the first run
# of prose lines after it: blank lines between the two are looked past, and a
# blank line, the next heading, or a code fence ends it. A fenced block before
# the paragraph is skipped rather than read as prose, since a sample of syntax
# is not what a reader was promised under a heading. Nothing is printed when the
# heading is absent or only another heading follows it. The input is read to
# its end once the paragraph has ended, so a writer on a pipe is never cut off.
#
#   ## About / Two lines / of text  ->  "Two lines of text"
#
# is_heading and heading_text come from lines.awk.

ended { next }
is_code_fence($0) {
  if (started) {
    ended = 1
  }
  next
}
in_fence { next }
!found && is_heading($0) && heading_text($0) == heading { found = 1; next }
!found { next }
is_heading($0) { ended = 1; next }
is_blank($0) && started { ended = 1; next }
is_blank($0) { next }
{
  paragraph = (started ? paragraph " " : "") squeeze($0)
  started = 1
}

END { print paragraph }
