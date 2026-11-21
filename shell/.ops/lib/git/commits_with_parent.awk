# Prints the commit of each `rev-list --parents` line whose first parent is
# the commit named by -v parent.
$2 == parent { print $1 }
