# Rewrites bare Linear issue IDs in prose into markdown links, leaving fenced
# blocks and backtick spans as they are.
#
# team is the pattern matching any team key, as linear__keys_pattern prints
# it, for example (OPS|BIZ); one bare key such as OPS is that team alone.
# prefix is the directory an issue URL sits in; each mention becomes
# PREFIX/ID. An ID that is already a link label or sits inside a link URL is
# left alone, so a second pass is a no-op.

function already_link_label(before, after) {
  return (before ~ /\[$/ && after ~ /^\]\(/)
}

function inside_markdown_url(before) {
  return (before ~ /\]\([^)]*$/)
}

# Same close-on-equal-run walk as strip_code_spans in lines.awk: a span is
# copied through, and only the prose around it is rewritten. An unclosed
# opener is stray punctuation and the remainder is left untouched.
function map_prose(line, __kept, __at, __rest, __run, __delim, __body, __closes_at) {
  __kept = ""
  while ((__at = index(line, "`")) > 0) {
    __kept = __kept rewrite_prose(substr(line, 1, __at - 1))
    __rest = substr(line, __at)
    __run = 0
    while (substr(__rest, __run + 1, 1) == "`") {
      __run++
    }
    __delim = substr(__rest, 1, __run)
    __body = substr(__rest, __run + 1)
    __closes_at = index(__body, __delim)
    if (__closes_at == 0) {
      return __kept __delim __body
    }
    __kept = __kept __delim substr(__body, 1, __closes_at - 1) __delim
    line = substr(__body, __closes_at + __run)
  }
  return __kept rewrite_prose(line)
}

function rewrite_prose(text, __out, __id, __key, __before, __after) {
  __out = ""
  while (match(text, /[A-Za-z]+-[0-9]+/)) {
    __id = substr(text, RSTART, RLENGTH)
    __key = toupper(__id)
    __before = substr(text, 1, RSTART - 1)
    __after = substr(text, RSTART + RLENGTH)
    if (__key !~ ("^" toupper(team) "-")) {
      __out = __out __before __id
      text = __after
      continue
    }
    if (already_link_label(__before, __after) || inside_markdown_url(__before)) {
      __out = __out __before __id
      text = __after
      continue
    }
    if (prefix == "") {
      __out = __out __before __id
      text = __after
      continue
    }
    __out = __out __before "[" __id "](" prefix "/" __id ")"
    text = __after
  }
  return __out text
}

is_code_fence($0) {
  print
  next
}
in_fence {
  print
  next
}
{
  print map_prose($0)
}
