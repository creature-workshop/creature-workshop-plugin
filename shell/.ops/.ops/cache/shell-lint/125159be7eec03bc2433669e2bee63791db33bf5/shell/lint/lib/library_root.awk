# The roots a library file sits under, for every check that judges a file
# by where it sits. Loaded ahead of such a check:
#
#   awk -v root=<repository root> -v library_roots="lib interpreter scripts shell src" \
#     -f scan.awk -f library_root.awk -f <check>.awk
#
# library_roots is the repository's list, relative to its root and space
# separated, as lint__config__library_roots prints it: scripts/, shell/ and
# src/, the homes a consumer keeps its shell in, lib/ and interpreter/ for
# shellops itself, or whatever lint.json names (ADR 000045). A key is a
# file's path under the repository root, as library_key spells it.

# The root KEY sits under, or nothing when it sits under none.
function library_root_of(key, __i) {
  for (__i = 1; __i <= library_root_count; __i++) {
    if (index(key, library_root_list[__i] "/") == 1) {
      return library_root_list[__i]
    }
  }
  return ""
}

# True when KEY sits under a library root.
function under_library_root(key) {
  return (library_root_of(key) != "")
}

# KEY with its root dropped: the module path begins where the root ends,
# whichever root it is.
#
#     without_library_root("lib/git/api.sh")    ->  "git/api.sh"
#     without_library_root("src/tool/api.sh")   ->  "tool/api.sh"
function without_library_root(key, __root) {
  __root = library_root_of(key)
  if (__root == "") {
    return key
  }
  return substr(key, length(__root) + 2)
}

# PATH under the repository root when it sits there, `lib/git/api.sh`; PATH
# itself otherwise.
function repo_key(path) {
  if (root != "" && index(path, root "/") == 1) {
    return substr(path, length(root) + 2)
  }
  return path
}

# The path from the last library-root component of KEY, so a fixture nested
# anywhere is still keyed as a library file; nothing when KEY has none.
function last_root_key(key, __i, __rest, __at, __start, __best, __found) {
  __best = 0
  __found = ""
  for (__i = 1; __i <= library_root_count; __i++) {
    __rest = key
    __start = 0
    while ((__at = index(__rest, "/" library_root_list[__i] "/")) > 0) {
      __start += __at
      __rest = substr(__rest, __at + 1)
    }
    if (__start > __best) {
      __best = __start
      __found = substr(key, __start + 1)
    }
  }
  return __found
}

# The library key PATH is judged by: its path under the repository root when
# that sits under a library root, `lib/git/api.sh`; otherwise the path from
# its last library-root component, wherever a fixture has nested it; nothing
# when it has none.
function library_key(path, __key) {
  __key = repo_key(path)
  if (under_library_root(__key)) {
    return __key
  }
  return last_root_key(__key)
}

BEGIN {
  if (library_roots == "") {
    library_roots = "scripts shell src"
  }
  library_root_count = split(library_roots, library_root_list, " ")
}
