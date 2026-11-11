# Answers whether the text opens with a blockquote, through exit status: 0 when
# the first line with anything on it is quoted, 1 otherwise.
#
# "First line with anything on it" rather than "first line", so that a reply
# whose editor left a blank line above the quotation still reads as one.
#
# The input is read to its end once the answer is known: a program that exits
# with input unread closes the pipe on a writer still writing, and under
# pipefail that writer's SIGPIPE fails a pipeline whose answer was right.

decided { next }
is_blank($0) { next }
{ quoted = is_quoted($0); decided = 1 }

END { exit !quoted }
