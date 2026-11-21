# Drops code in whichever notation carries it, printing the prose around it:
# fenced blocks go with their fences, and inline backtick spans go from the lines
# that survive.
#
# For readers deciding what an author said. Code is a sample or a paste either
# way -- `Closes OPS-1` shown as syntax is not a closure, exactly as a fenced job
# log reporting one is not.
#
# An unterminated fence swallows the rest of the input. That is deliberate: a
# document that opens a block and never closes it renders as code to the end in
# every markdown implementation, so treating the tail as prose would disagree
# with what the author sees.

is_code_fence($0) { next }
in_fence          { next }
{ print strip_code_spans($0) }
