# Renders the red-run ticket kept in report-run.ticket.json: in every field
# of the template, a {name} placeholder becomes the argument of that name.
#
# Input: the template, an object of texts.
# Argument "names": the names of the arguments to fill in, with a space
#                   between them, in the order they are filled in.
#
#   input      {"title": "Red run on {status_name}"}
#   arguments  names=status_name, status_name=forgejo/site
#   ->         {"title": "Red run on forgejo/site"}

function main(line) {
  tree_line(line)
}

# The text with every place it writes one text replaced by another, read
# as plain text and not as a pattern.
function replaced(text, old, new, __out, __at) {
  __out = ""

  while ((__at = index(text, old)) > 0) {
    __out = __out substr(text, 1, __at - 1) new
    text = substr(text, __at + length(old))
  }

  return __out text
}

# The text of a field with every placeholder filled in.
function filled(text, __names, __count, __i) {
  __count = split(arg("names"), __names, " ")

  for (__i = 1; __i <= __count; __i++) {
    text = replaced(text, "{" __names[__i] "}", arg(__names[__i]))
  }

  return text
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  fields = 0
  for (field = NODE_FIRST[ROOT]; field != 0; field = NODE_NEXT[field]) {
    print "0." NODE_KEY[field] ":str=" wrap(filled(text_of(field)))
    fields++
  }

  if (fields == 0) {
    print "0.:map"
  }
}

{ main($0) }
