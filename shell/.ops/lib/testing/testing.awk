# The rules every program that selects tests shares: pathname arithmetic,
# the glob rules a name or a path matches a suite's patterns by, which
# files discovery may list, which area a file belongs to, and which areas
# import which. Two programs that load this cannot answer "does this area
# cover that file?" differently. It holds functions alone. Loaded after
# tree.awk.

# Whether a node holds a value that counts as true: any value but a null
# and false. No node holds none.
function is_truthy(node) {
  return is_present(node) && !(NODE_TYPE[node] == "bool" && text_of(node) == "false")
}

# Everything after the last slash of a path.
function base_name(path) {
  sub(/^.*\//, "", path)

  return path
}

# A base name without its last extension: lib/string/api.sh is api, and a
# name with no extension is itself.
function stem(path) {
  path = base_name(path)
  sub(/\.[^.]*$/, "", path)

  return path
}

# Fills list with a path and every directory above it, the one nearest
# the root first. Returns how many there are.
#
#   ancestors("lib/string/api.sh", list)
#   ->  3, and list is lib, lib/string, lib/string/api.sh
function ancestors(path, list, __parts, __count, __i) {
  __count = split(path, __parts, "/")
  for (__i = 1; __i <= __count; __i++) {
    list[__i] = (__i == 1) ? __parts[1] : list[__i - 1] "/" __parts[__i]
  }

  return __count
}

# Whether a path is a file or a directory above it.
#
#   covers("lib/string", "lib/string/api.sh")  ->  1
function covers(path, file) {
  return file == path || index(file, path "/") == 1
}

# Whether any of the paths under a node covers a file.
function covered_by(paths, file, __path) {
  for (__path = NODE_FIRST[paths]; __path != 0; __path = NODE_NEXT[__path]) {
    if (covers(text_of(__path), file)) {
      return 1
    }
  }

  return 0
}

# Whether a name matches a shell glob, the way fnmatch matches a name with
# no slash in it: "*" is any run of characters, "?" is any one, and "[...]"
# is one character of a class, or one outside it when the class opens with
# "!". A "[" that the glob never closes is a literal.
function glob_matches(name, glob) {
  return glob_matches_from(name, 1, glob, 1)
}

# Whether the name from one place on matches the glob from one place on.
function glob_matches_from(name, at, glob, glob_at, __char, __end) {
  while (glob_at <= length(glob)) {
    __char = substr(glob, glob_at, 1)

    if (__char == "*") {
      return star_matches(name, at, glob, glob_at + 1)
    }
    if (at > length(name)) {
      return 0
    }

    __end = (__char == "[") ? class_end(glob, glob_at) : 0
    if (__end > 0) {
      if (!in_class(substr(name, at, 1), substr(glob, glob_at + 1, __end - glob_at - 1))) {
        return 0
      }
      glob_at = __end + 1
    } else {
      if (__char != "?" && __char != substr(name, at, 1)) {
        return 0
      }
      glob_at++
    }
    at++
  }

  return at > length(name)
}

# Whether what follows a "*" in the glob matches some end of the name.
function star_matches(name, at, glob, glob_at, __from) {
  for (__from = at; __from <= length(name) + 1; __from++) {
    if (glob_matches_from(name, __from, glob, glob_at)) {
      return 1
    }
  }

  return 0
}

# The place of the "]" that closes the class opening at a place in the
# glob, and 0 when the glob never closes it.
function class_end(glob, at, __end) {
  __end = index(substr(glob, at + 1), "]")

  return (__end == 0) ? 0 : at + __end
}

# Whether a character is in a class, given as what the glob writes between
# its brackets: characters, ranges such as a-z, and a leading "!" for
# every character that is not in it.
function in_class(char, class, __negated, __i, __found) {
  __negated = (substr(class, 1, 1) == "!")
  if (__negated) {
    class = substr(class, 2)
  }

  __found = 0
  for (__i = 1; __i <= length(class); __i++) {
    if (substr(class, __i + 1, 1) == "-" && __i + 2 <= length(class)) {
      if (char >= substr(class, __i, 1) && char <= substr(class, __i + 2, 1)) {
        __found = 1
      }
      __i += 2
    } else if (char == substr(class, __i, 1)) {
      __found = 1
    }
  }

  return __negated ? !__found : __found
}

# Whether a name matches any of the globs under a node.
function matches_any(name, globs, __glob) {
  for (__glob = NODE_FIRST[globs]; __glob != 0; __glob = NODE_NEXT[__glob]) {
    if (glob_matches(name, text_of(__glob))) {
      return 1
    }
  }

  return 0
}

# Whether a word has a glob character in it, which is the shell's rule for
# whether it is a pattern and not a literal name.
function has_glob_chars(word) {
  return word ~ /[*?[]/
}

# Whether a whole path matches a whole path glob, the way the shell
# expands one: part by part, so "*" and "?" never cross a "/". A glob of
# two parts never matches a path of three.
function matches_path_glob(path, glob, __parts, __globs, __count, __i) {
  __count = split(path, __parts, "/")
  if (split(glob, __globs, "/") != __count) {
    return 0
  }

  for (__i = 1; __i <= __count; __i++) {
    if (!glob_matches(__parts[__i], __globs[__i])) {
      return 0
    }
  }

  return 1
}

# Whether the base name of a path matches one of the globs and none of the
# excludes.
function matching(path, globs, excludes) {
  return matches_any(base_name(path), globs) && !matches_any(base_name(path), excludes)
}

# Whether a path may be listed by discovery: nothing hidden, nothing inside
# a vendored test framework's lib, and no fixture. A fixture is a sample a
# test feeds to the unit under test, named <module>.fixture.<ext>, so it
# matches a suite's glob without being a test.
function discoverable(path) {
  return path !~ /(^|\/)\./ \
    && path !~ /(^|\/)lib\/bats-[^\/]*\// \
    && base_name(path) !~ /\.fixture\./
}

# The area whose source path covers a file most specifically: the longest
# path that covers it, so a catch-all never hides a nested area. Of two
# paths of one length, the later wins. Sets SOURCE_AREA to the area's name
# and returns 1, or returns 0 when no area's source covers the file.
function source_area(areas, file, __area, __path, __longest, __found) {
  __found = 0
  __longest = -1

  for (__area = NODE_FIRST[areas]; __area != 0; __area = NODE_NEXT[__area]) {
    for (__path = NODE_FIRST[member(__area, "paths")]; __path != 0; __path = NODE_NEXT[__path]) {
      if (covers(text_of(__path), file) && length(text_of(__path)) >= __longest) {
        __longest = length(text_of(__path))
        SOURCE_AREA = name_of(__area)
        __found = 1
      }
    }
  }

  return __found
}

# The tests of an area as a map of suite to files, and no node when the
# area has no tests block or one that is not a map.
function normalized_tests(area, __tests) {
  __tests = member(area, "tests")

  return (NODE_TYPE[__tests] == "map") ? __tests : 0
}

# Whether a file is listed in the tests of an area, under any suite.
function in_tests(area, file, __suite, __test) {
  for (__suite = NODE_FIRST[member(area, "tests")]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    for (__test = NODE_FIRST[__suite]; __test != 0; __test = NODE_NEXT[__test]) {
      if (text_of(__test) == file) {
        return 1
      }
    }
  }

  return 0
}

# Puts texts in byte order in place: a merge sort from the bottom up, runs
# of one, then two, then four.
function sort_texts(texts, count, __width, __left, __i) {
  for (__width = 1; __width < count; __width = __width * 2) {
    for (__left = 1; __left <= count; __left = __left + 2 * __width) {
      merge_texts(texts, __left, lesser(__left + __width, count + 1), lesser(__left + 2 * __width, count + 1))
    }
    for (__i = 1; __i <= count; __i++) {
      texts[__i] = SORT_MERGED[__i]
    }
  }
}

# Merges two sorted runs of texts into SORT_MERGED.
function merge_texts(texts, left, middle, end, __i, __j, __k) {
  __i = left
  __j = middle

  for (__k = left; __k < end; __k++) {
    if (__i < middle && (__j >= end || (texts[__i] "") <= (texts[__j] ""))) {
      SORT_MERGED[__k] = texts[__i]
      __i++
    } else {
      SORT_MERGED[__k] = texts[__j]
      __j++
    }
  }
}

# The lesser of two numbers.
function lesser(a, b) {
  return (a < b) ? a : b
}

# Puts texts in byte order and leaves each once. Returns how many are
# left.
function unique_texts(texts, count, __i, __kept) {
  sort_texts(texts, count)
  __kept = 0

  for (__i = 1; __i <= count; __i++) {
    if (__kept == 0 || (texts[__i] "") != (texts[__kept] "")) {
      __kept++
      texts[__kept] = texts[__i]
    }
  }

  return __kept
}

# Prints texts as the elements of a list, each a str, one level under a
# depth. The caller prints the line that opens the list.
function print_texts(texts, count, depth, __i) {
  for (__i = 1; __i <= count; __i++) {
    print (depth + 1) "." (__i - 1) ":str=" wrap(texts[__i])
  }
}

# Reads the file edges of the import graph under a node, each {from, to},
# into the area edges they make: the importer's area and the imported
# file's area, by source_area. An edge whose end no area's source covers,
# or that stays inside one area, makes none. Each area edge is kept once,
# and IMPORTERS_OF[area] lists the areas that import an area, with a
# newline after each, in the order of the importer's name.
function read_area_edges(areas, edges, __edge, __from, __to, __pairs, __count, __i, __parts) {
  __count = 0

  for (__edge = NODE_FIRST[edges]; __edge != 0; __edge = NODE_NEXT[__edge]) {
    __from = area_of_file(areas, text_of(member(__edge, "from")))
    __to = area_of_file(areas, text_of(member(__edge, "to")))
    if (__from == "" || __to == "" || __from == __to) {
      continue
    }

    __count++
    __pairs[__count] = __from "\n" __to
  }

  __count = unique_texts(__pairs, __count)
  for (__i = 1; __i <= __count; __i++) {
    split(__pairs[__i], __parts, "\n")
    IMPORTERS_OF[__parts[2]] = IMPORTERS_OF[__parts[2]] __parts[1] "\n"
  }
}

# The name of the area a file belongs to by source_area, looked up once
# for each file, and the empty string when no area's source covers it.
function area_of_file(areas, file) {
  if (!(file in AREA_OF_FILE)) {
    AREA_OF_FILE[file] = source_area(areas, file) ? SOURCE_AREA : ""
  }

  return AREA_OF_FILE[file]
}

# Fills reached with every area that reaches one of the areas given over
# IMPORTERS_OF, those areas among them, in byte order and each once.
# Returns how many there are. seen holds the areas to start from.
function reach(seen, count, reached, __i, __j, __importers, __added, __names, __held) {
  for (__i = 1; __i <= count; __i++) {
    if (!(seen[__i] in __held)) {
      __held[seen[__i]] = 1
      __added++
      reached[__added] = seen[__i]
    }
  }

  for (__i = 1; __i <= __added; __i++) {
    __importers = split(IMPORTERS_OF[reached[__i]], __names, "\n")
    for (__j = 1; __j < __importers; __j++) {
      if (!(__names[__j] in __held)) {
        __held[__names[__j]] = 1
        __added++
        reached[__added] = __names[__j]
      }
    }
  }

  sort_texts(reached, __added)
  return __added
}
