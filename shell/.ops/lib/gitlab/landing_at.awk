# Prints the iid of the merge request whose merge landed a commit, among
# the merge requests the commit is part of: the one whose merge commit it
# is. Prints a null when it is none's, which is a commit that reached the
# branch some other way.
#
# Input:  {reviews: [{iid, merge_commit_sha, ...}], sha}
# Output: iid | null
#
#   {"reviews": [{"iid": 12, "merge_commit_sha": "7d68"}], "sha": "7d68"}  ->  12

function main(line) {
  tree_line(line)
}

# The first merge request whose merge commit is the commit asked about,
# and 0 when none is.
function landing_review(__review, __sha, __merged) {
  __sha = member(ROOT, "sha")

  for (__review = NODE_FIRST[member(ROOT, "reviews")]; __review != 0; __review = NODE_NEXT[__review]) {
    __merged = member(__review, "merge_commit_sha")
    if (written(__merged) == written(__sha)) {
      return __review
    }
  }

  return 0
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  review = landing_review()
  print "0.:" written(member(review, "iid"))
}

{ main($0) }
