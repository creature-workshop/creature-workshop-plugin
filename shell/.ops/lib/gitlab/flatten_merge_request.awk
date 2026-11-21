# Reshapes a GitLab GraphQL mergeRequest node into a flatter object that
# parallels the pull request Forgejo's REST API answers, so a caller such
# as pr-hygiene reads both forges the same way.
#
# Input: {iid, title, description, labels: {nodes: [{title,...}]},
#         assignees: {nodes: [{username,...}]}, ...}
# Output: {iid, number, title, body, state, sha, draft, head, base,
#          html_url, labels: [{name, color, description}],
#          assignees: [{login, name}], user: {login, name} | null}

function main(line) {
  tree_line(line)
}

# Prints the iid as a number under "number" when it is a str that spells
# one, and as it is otherwise.
function print_number(iid, __text) {
  __text = text_of(iid)

  if (NODE_TYPE[iid] == "str" && __text ~ /^-?[0-9]+$/) {
    print "0." wrap("number") ":int=" __text
  } else if (NODE_TYPE[iid] == "str" && __text ~ /^-?[0-9]+\.[0-9]+$/) {
    print "0." wrap("number") ":float=" __text
  } else {
    print_as(iid, 0, "number")
  }
}

# Prints the labels, each {name, color, description}.
function print_labels(__label, __labels) {
  print_open(0, wrap("labels"), "list")

  __labels = 0
  for (__label = NODE_FIRST[member(member(ROOT, "labels"), "nodes")]; __label != 0; __label = NODE_NEXT[__label]) {
    print_open(1, __labels, "map")
    print_as(member(__label, "title"), 2, "name")
    print_as(member(__label, "color"), 2, "color")
    print_as(member(__label, "description"), 2, "description")
    __labels++
  }
}

# Prints the assignees, each {login, name}.
function print_assignees(__assignee, __assignees) {
  print_open(0, wrap("assignees"), "list")

  __assignees = 0
  for (__assignee = NODE_FIRST[member(member(ROOT, "assignees"), "nodes")]; __assignee != 0; __assignee = NODE_NEXT[__assignee]) {
    print_open(1, __assignees, "map")
    print_as(member(__assignee, "username"), 2, "login")
    print_as(member(__assignee, "name"), 2, "name")
    __assignees++
  }
}

# Prints the author as {login, name}, or a null when GitLab names none.
function print_user(author) {
  if (!is_present(author)) {
    print "0." wrap("user") ":null"
    return
  }

  print_open(0, wrap("user"), "map")
  print_as(member(author, "username"), 1, "login")
  print_as(member(author, "name"), 1, "name")
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_as(member(ROOT, "iid"), 0, "iid")
  print_number(member(ROOT, "iid"))
  print_as(member(ROOT, "title"), 0, "title")
  print_or(member(ROOT, "description"), 0, "body", "str=\"\"")
  print_as(member(ROOT, "state"), 0, "state")
  print_as(member(ROOT, "diffHeadSha"), 0, "sha")
  print_or(member(ROOT, "draft"), 0, "draft", "bool=false")
  print_as(member(ROOT, "sourceBranch"), 0, "head")
  print_as(member(ROOT, "targetBranch"), 0, "base")
  print_as(member(ROOT, "webUrl"), 0, "html_url")
  print_labels()
  print_assignees()
  print_user(member(ROOT, "author"))
}

{ main($0) }
