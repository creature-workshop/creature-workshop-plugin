# The key ranking each increment part on stdin, one per line in the same
# order: the format's precedence, the tier's rank and the count, the last
# two ten digits wide. Loaded after tier_rank.awk, with the variables it and
# this read.
#
#   printf '%s\n' beta.2 | awk -v tiers="dev alpha beta rc" -v precedence=1 -f tier_rank.awk -f increment_order.awk  ->  1.0000000002.0000000002

{
  split($0, piece, ".")
  printf "%s.%010d.%010d\n", precedence, tier_rank(piece[1]), piece[2]
}
