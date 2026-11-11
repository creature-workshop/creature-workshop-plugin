# paths.awk -- the path arithmetic a trace reader needs: an absolute path
# with "." and ".." folded away, and its repository-relative form under a
# root. Pure functions of their arguments, shared so the readers cannot
# place one path two ways.

# The parts of an absolute path with "." and ".." folded away, rejoined.
function normalize(path, __parts, __depth) {
  __depth = folded(path, __parts)
  return joined(__parts, __depth)
}

# Fills parts[1..depth] with the path's segments, "." dropped and ".." taking
# the segment before it away, and returns depth.
function folded(path, parts, __raw, __n, __i, __depth) {
  __n = split(path, __raw, "/")
  __depth = 0
  for (__i = 1; __i <= __n; __i++) {
    __depth = folded_step(__raw[__i], parts, __depth)
  }
  return __depth
}

# One segment folded onto parts[1..depth]: the depth after it.
function folded_step(segment, parts, depth) {
  if (segment == "" || segment == ".") {
    return depth
  }
  if (segment == "..") {
    return depth > 0 ? depth - 1 : 0
  }
  parts[depth + 1] = segment
  return depth + 1
}

# parts[1..depth] as one absolute path.
function joined(parts, depth, __i, __out) {
  __out = ""
  for (__i = 1; __i <= depth; __i++) {
    __out = __out "/" parts[__i]
  }
  return __out
}

# The repository-relative form of a normalized absolute path under the
# normalized root, or nothing for the root itself or a path outside it.
function relative_to(abs, root) {
  if (index(abs, root "/") == 1) {
    return substr(abs, length(root) + 2)
  }
  return ""
}
