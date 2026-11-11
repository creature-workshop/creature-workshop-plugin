# Prints whether a merge request's approval rules are met, and since when.
#
# The rules' own verdict is what GitLab answers with, so nobody here counts
# approvals or reads a name (ADR.6@global). The moment the merge request
# became ready is the earliest approval standing on it: a later approval
# adds nothing to a merge request the rules already cleared, and the queue
# orders by how long an entry has been waiting (ADR.19@global).
#
# Input:  the approvals payload, {approved, approved_by: [{approved_at}]}
# Output: {approved, approved_at}, the time empty when nobody has approved
#
#   {"approved":true,"approved_by":[{"approved_at":"2026-09-24T23:36:37.454Z"}]}
#     ->  {"approved":true,"approved_at":"2026-09-24T23:36:37.454Z"}

function main(line) {
  tree_line(line)
}

# The earliest time an approval was given, and the empty string when the
# payload has none.
function ready_at(__approval, __at, __earliest, __found) {
  __found = 0

  for (__approval = NODE_FIRST[member(ROOT, "approved_by")]; __approval != 0; __approval = NODE_NEXT[__approval]) {
    __at = member(__approval, "approved_at")
    if (is_present(__at) && (!__found || (text_of(__at) "") < (__earliest ""))) {
      __earliest = text_of(__at)
      __found = 1
    }
  }

  return __found ? __earliest : ""
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_or(member(ROOT, "approved"), 0, "approved", "bool=false")
  print_str(0, "approved_at", ready_at())
}

{ main($0) }
