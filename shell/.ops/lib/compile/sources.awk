# Keeps the lines naming a source the compile reads: a library module,
# lib/**/*.sh that is no plugin, or a type plugin, lib/**/*.type.op.sh. A line
# is a path, or an index entry whose path follows its tab; the path decides.
# With paths_only set, the path alone is printed.
function main(line, __path) {
  __path = path_of(line)
  if (!compiles(__path)) {
    return
  }
  if (paths_only) {
    print __path
  } else {
    print line
  }
}

function path_of(line, __tab) {
  __tab = index(line, "\t")
  if (__tab) {
    return substr(line, __tab + 1)
  }
  return line
}

function compiles(path) {
  if (path ~ /^lib\/.*\.type\.op\.sh$/) {
    return 1
  }
  return path ~ /^lib\/.*\.sh$/ && path !~ /\.op\.sh$/
}

{ main($0) }
