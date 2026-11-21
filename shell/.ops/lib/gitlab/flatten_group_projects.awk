# Reshapes GitLab's group.projects.nodes into the shape Forgejo lists an
# organisation's repositories in: a list of {name, full_name, description,
# archived, html_url, ssh_url, clone_url}.

function main(line) {
  tree_line(line)
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  projects = 0
  for (project = NODE_FIRST[ROOT]; project != 0; project = NODE_NEXT[project]) {
    print_open(0, projects, "map")
    print_as(member(project, "path"), 1, "name")
    print_as(member(project, "fullPath"), 1, "full_name")
    print_or(member(project, "description"), 1, "description", "str=\"\"")
    print_or(member(project, "archived"), 1, "archived", "bool=false")
    print_as(member(project, "webUrl"), 1, "html_url")
    print_as(member(project, "sshUrlToRepo"), 1, "ssh_url")
    print_as(member(project, "httpUrlToRepo"), 1, "clone_url")
    projects++
  }

  if (projects == 0) {
    print "0.:list"
  }
}

{ main($0) }
