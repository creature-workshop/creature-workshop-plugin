# Orders a queue's entries by readiness alone: the earliest first, then the
# lowest iid. A missing readiness counts as 0. Loaded after order.awk.
#
#   [{"iid":2,"ready_at":9},{"iid":1,"ready_at":5}]
#   -> [{"iid":1,"ready_at":5},{"iid":2,"ready_at":9}]

function main(line) {
  tree_line(line)
}

# The numbers one entry is ordered by: its readiness, then its iid.
function rank_entry(i, entry) {
  RANK[i, 1] = number_or_zero(member(entry, "ready_at"))
  RANK[i, 2] = number_or_zero(member(entry, "iid"))
}

BEGIN {
  ROOT = tree_open()
  KEYS = 2
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
