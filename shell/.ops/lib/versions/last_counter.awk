# The highest counter among the tag names on stdin that are in the counter
# form, printed once at the end; nothing when none is. A name in the
# increment form, or a tier alone, carries no counter and is passed over, as
# is anything that is not a release name.
#
#   printf '%s\n' 1.2.0-1.dev v1.2.0-3.alpha 1.2.0-dev.9 | awk -f last_counter.awk  ->  3

# The counter a release name carries in the counter form, and nothing when
# the name is in another form.
function counter_of(name, __bare, __pre, __piece) {
  __bare = name
  sub(/^v/, "", __bare)
  if (__bare !~ /^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[A-Za-z]+$/) {
    return ""
  }
  __pre = substr(__bare, index(__bare, "-") + 1)
  split(__pre, __piece, ".")
  return __piece[1]
}

{
  counter = counter_of($0)
  if (counter != "" && counter + 0 > highest + 0) {
    highest = counter + 0
    seen = 1
  }
}

END {
  if (seen) {
    print highest
  }
}
