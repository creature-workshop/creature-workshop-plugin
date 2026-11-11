# paths.awk -- questions about where a path sits, answered from its text
# alone. Pure functions of their arguments, shared so two programs cannot
# place one path two ways.

# True when FOLDER, a relative path of whole segments, is one of the
# directories PATH sits under, whether PATH is relative or absolute.
#
#     is_under("adrs/0007-fragments/adr.md", "adrs")            ->  1
#     is_under("/repo/docs/decisions/000034-a.md", "docs/decisions")  ->  1
#     is_under("notes/adrs.md", "adrs")                         ->  0
function is_under(path, folder) {
  return index(path, folder "/") == 1 || index(path, "/" folder "/") > 0
}

# The last segment of PATH.
#
#     basename("adrs/000007-fragments/tables/kinds.md")  ->  "kinds.md"
function basename(path, __parts, __count) {
  __count = split(path, __parts, "/")
  return __parts[__count]
}
