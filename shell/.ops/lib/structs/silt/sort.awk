# Print a SILT list with its members in the order of their values: null,
# then false, then true, then numbers by value, then strings by code point,
# then lists member by member, then maps by their keys and then by their
# values in key order. The members are renumbered from 0, and every line
# beneath a member keeps its text.
#
# Every line is "<depth>.<key>:<type>" or "<depth>.<key>:<type>=<value>".
# A member of the list is a line at depth 0 with the lines beneath it, up
# to the next line at depth 0.

function main(line) {
  N++
  L[N] = line
  parse(N)
}

# Sets D (depth), K (key, quoted for a map), T (type) and V (value) of line i.
function parse(i, __rest, __end) {
  D[i] = substr(L[i], 1, index(L[i], ".") - 1) + 0
  __rest = substr(L[i], index(L[i], ".") + 1)
  if (substr(__rest, 1, 1) == "\"") {
    __end = closing_quote(__rest)
    K[i] = substr(__rest, 1, __end)
    __rest = substr(__rest, __end + 2)
  } else {
    K[i] = substr(__rest, 1, index(__rest, ":") - 1)
    __rest = substr(__rest, index(__rest, ":") + 1)
  }
  if (index(__rest, "=") > 0) {
    T[i] = substr(__rest, 1, index(__rest, "=") - 1)
    V[i] = substr(__rest, index(__rest, "=") + 1)
  } else {
    T[i] = __rest
    V[i] = ""
  }
}

# The position of the quote that closes the JSON string opening text.
function closing_quote(text, __i, __c) {
  for (__i = 2; __i <= length(text); __i++) {
    __c = substr(text, __i, 1)
    if (__c == "\\") {
      __i++
      continue
    }
    if (__c == "\"") {
      return __i
    }
  }
  return length(text)
}

# Fills out[1..n] with the lines of the members of the value at line i, and
# returns n.
function children(i, out, __j, __n) {
  __n = 0
  for (__j = i + 1; __j <= N && D[__j] > D[i]; __j++) {
    if (D[__j] == D[i] + 1) {
      out[++__n] = __j
    }
  }
  return __n
}

# Where the value at line i stands in the order of types.
function rank(i) {
  if (T[i] == "null") {
    return 0
  }
  if (T[i] == "bool") {
    return V[i] == "false" ? 1 : 2
  }
  if (T[i] == "int" || T[i] == "float") {
    return 3
  }
  if (T[i] == "str") {
    return 4
  }
  if (T[i] == "list") {
    return 5
  }
  return 6
}

# Negative, zero or positive as the value at line a comes before, equals or
# follows the value at line b.
function compare(a, b, __ra, __rb) {
  __ra = rank(a)
  __rb = rank(b)
  if (__ra != __rb) {
    return __ra < __rb ? -1 : 1
  }
  if (__ra == 3) {
    return compare_numbers(V[a] + 0, V[b] + 0)
  }
  if (__ra == 4) {
    return compare_text(V[a], V[b])
  }
  if (__ra == 5) {
    return compare_lists(a, b)
  }
  if (__ra == 6) {
    return compare_maps(a, b)
  }
  return 0
}

function compare_numbers(x, y) {
  if (x < y) {
    return -1
  }
  return x > y ? 1 : 0
}

function compare_text(x, y) {
  if (x < y) {
    return -1
  }
  return x > y ? 1 : 0
}

# Lists compare member by member, and a shorter list comes first.
function compare_lists(a, b, __ca, __cb, __na, __nb, __k, __c) {
  __na = children(a, __ca)
  __nb = children(b, __cb)
  for (__k = 1; __k <= __na && __k <= __nb; __k++) {
    __c = compare(__ca[__k], __cb[__k])
    if (__c != 0) {
      return __c
    }
  }
  return compare_numbers(__na, __nb)
}

# Maps compare by their sorted keys first, then by their values in that
# order.
function compare_maps(a, b, __ca, __cb, __na, __nb, __k, __c) {
  __na = children(a, __ca)
  __nb = children(b, __cb)
  sort_by_key(__ca, __na)
  sort_by_key(__cb, __nb)
  for (__k = 1; __k <= __na && __k <= __nb; __k++) {
    __c = compare_text(K[__ca[__k]], K[__cb[__k]])
    if (__c != 0) {
      return __c
    }
  }
  if (__na != __nb) {
    return compare_numbers(__na, __nb)
  }
  for (__k = 1; __k <= __na; __k++) {
    __c = compare(__ca[__k], __cb[__k])
    if (__c != 0) {
      return __c
    }
  }
  return 0
}

# Prints the members in order, renumbered, each with the lines beneath it.
function print_sorted(__m, __i, __j, __b) {
  __m = 0
  for (__i = 1; __i <= N; __i++) {
    if (D[__i] == 0 && K[__i] != "") {
      __b[++__m] = __i
    }
  }
  if (__m == 0) {
    print_lines(1, N)
    return
  }
  insertion_sort(__b, __m)
  for (__j = 1; __j <= __m; __j++) {
    print_member(__b[__j], __j - 1)
  }
}

# Orders the member lines in c[1..n] by their keys, in place.
function sort_by_key(c, n, __i, __j, __x) {
  for (__i = 2; __i <= n; __i++) {
    __x = c[__i]
    for (__j = __i - 1; __j >= 1 && K[c[__j]] > K[__x]; __j--) {
      c[__j + 1] = c[__j]
    }
    c[__j + 1] = __x
  }
}

# Orders the member lines in b[1..m] in place.
function insertion_sort(b, m, __i, __j, __x) {
  for (__i = 2; __i <= m; __i++) {
    __x = b[__i]
    for (__j = __i - 1; __j >= 1 && compare(b[__j], __x) > 0; __j--) {
      b[__j + 1] = b[__j]
    }
    b[__j + 1] = __x
  }
}

# Prints the member at line i under the index n, then the lines beneath it.
function print_member(i, n, __j) {
  if (V[i] != "") {
    print "0." n ":" T[i] "=" V[i]
  } else {
    print "0." n ":" T[i]
  }
  for (__j = i + 1; __j <= N && D[__j] > 0; __j++) {
    print L[__j]
  }
}

function print_lines(from, to, __j) {
  for (__j = from; __j <= to; __j++) {
    print L[__j]
  }
}

{ main($0) }
END { print_sorted() }
