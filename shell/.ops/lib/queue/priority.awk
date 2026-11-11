# Orders a queue's entries by score: the highest priority first, then the
# earliest readiness, then the lowest iid, so entries scored equal keep a
# fixed order. A missing priority or readiness counts as 0. Loaded after
# order.awk.
#
#   [{"iid":1,"priority":0,"ready_at":5},{"iid":2,"priority":2,"ready_at":9}]
#   -> [{"iid":2,"priority":2,"ready_at":9},{"iid":1,"priority":0,"ready_at":5}]

function main(line) {
  tree_line(line)
}

# The numbers one entry is ordered by: its priority with the sign changed,
# so the highest orders first, then its readiness, then its iid.
function rank_entry(i, entry) {
  RANK[i, 1] = -number_or_zero(member(entry, "priority"))
  RANK[i, 2] = number_or_zero(member(entry, "ready_at"))
  RANK[i, 3] = number_or_zero(member(entry, "iid"))
}

BEGIN {
  ROOT = tree_open()
  KEYS = 3
}

END {
  if (REFUSED) {
    exit 1
  }

  read_entries(ROOT)
  sort_entries()
  print_ordered()
}

{ main($0) }
