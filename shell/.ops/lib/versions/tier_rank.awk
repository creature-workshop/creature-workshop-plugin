# The rank of a tier among the tiers, read from the variable tiers, the
# tier words space-joined in certification order: dev ranks 0, and a word
# naming no tier ranks with dev. Loaded beside a program that keys parts,
# so every format ranks a tier the same way.
#
#   awk -v tiers="dev alpha beta rc" ... tier_rank("beta")  ->  2

function tier_rank(tier, __words, __n, __i) {
  __n = split(tiers, __words, " ")
  for (__i = 1; __i <= __n; __i++) {
    if (__words[__i] == tier) {
      return __i - 1
    }
  }
  return 0
}
