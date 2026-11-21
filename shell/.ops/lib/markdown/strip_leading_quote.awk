# Drops a leading blockquote, printing whatever follows it.
#
# On a forge without real reply threads, quoting the parent is how a reply is
# spelled, so that quote is scaffolding rather than something its author said.
# Blank lines around the quote go with it, since they only separate it from the
# reply proper.
#
# Only a leading run counts. A quote further down is the author quoting
# something mid-thought, which is theirs and stays.

BEGIN { leading = 1 }

leading && (is_blank($0) || is_quoted($0)) { next }
{ leading = 0; print }
