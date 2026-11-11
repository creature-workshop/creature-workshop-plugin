# The submodules a checkout pins, read off git ls-tree -r: a gitlink is
# the line "<mode> commit <commit>\t<path>", and prints as "<path> <commit>".
#
#   git ls-tree -r HEAD | awk -f gitlinks.awk

function main(line, __field) {
  split(line, __field)
  if (is_gitlink(__field)) {
    print __field[4], __field[3]
  }
}

function is_gitlink(field) {
  return field[2] == "commit"
}

{ main($0) }
