# paths.awk -- the repo-relative path of a doctest's file and XML escaping,
# for junit.awk, which reads rustdoc's output.
#
# rustdoc names a doctest's file relative to its package: src/lib.rs, or
# src/../README.md for a file the crate includes. The package's directory goes
# in front and the ../ segments collapse, so "crates/foo" and
# "src/../README.md" is crates/foo/README.md. A root package (".") adds no
# prefix.
#
# The package directories arrive as -v roots="<crate>=<dir> <crate>=<dir>",
# read once into root_of[<crate>] before any line is read.

function repo_path(dir, file, __path) {
  __path = file
  if (dir != "" && dir != ".") {
    __path = dir "/" file
  }
  for (;;) {
    if (!sub(/[^\/]+\/\.\.\//, "", __path)) {
      break
    }
  }
  return __path
}

function xml(text) {
  gsub(/&/, "\\&amp;", text)
  gsub(/</, "\\&lt;", text)
  gsub(/>/, "\\&gt;", text)
  gsub(/"/, "\\&quot;", text)
  return text
}

function read_roots(spec, __pairs, __n, __i, __eq) {
  __n = split(spec, __pairs, " ")
  for (__i = 1; __i <= __n; __i++) {
    __eq = index(__pairs[__i], "=")
    if (__eq > 0) {
      root_of[substr(__pairs[__i], 1, __eq - 1)] = substr(__pairs[__i], __eq + 1)
    }
  }
}

BEGIN {
  read_roots(roots)
}
