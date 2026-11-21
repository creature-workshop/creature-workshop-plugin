# Each line on stdin a release name, a tab and the key its format gave its
# part, printed as the name's sort key, a tab and the name: the three
# numbers ten digits wide, then 1 for a clean version and 0 for a
# prerelease, then the part's key. Byte order then sorts the keys the way
# the names rank.
#
#   printf '1.2.0-beta.2\t1.0000000002.0000000002\n' | awk -f sort_key.awk
#   ->  0000000001.0000000002.0000000000.0.1.0000000002.0000000002<TAB>1.2.0-beta.2

BEGIN {
  FS = "\t"
}

{
  name = $1
  sub(/^v/, "", name)
  clean = (index(name, "-") == 0)
  version = name
  sub(/-.*$/, "", version)
  split(version, number, ".")
  printf "%010d.%010d.%010d.%d.%s\t%s\n", number[1], number[2], number[3], clean, $2, $1
}
