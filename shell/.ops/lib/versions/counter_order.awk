# The key ranking each counter part on stdin, one per line in the same
# order: the format's precedence, then for a counted part the counter and
# 0, and for a tier alone ten nines and the tier's rank, the last two ten
# digits wide. Ten nines sort above every counter. They are written as text,
# because some awks print no whole number above 2147483647. Loaded after
# tier_rank.awk, with the variables it and this read.
#
#   printf '%s\n' 3.alpha dev | awk -v tiers="dev alpha beta rc" -v precedence=0 -f tier_rank.awk -f counter_order.awk
#   ->  0.0000000003.0000000000
#       0.9999999999.0000000000

index($0, ".") > 0 {
  split($0, piece, ".")
  printf "%s.%010d.%010d\n", precedence, piece[1], 0
  next
}

{
  printf "%s.%s.%010d\n", precedence, "9999999999", tier_rank($0)
}
