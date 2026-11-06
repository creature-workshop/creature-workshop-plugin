# Rewrite the sha and version lines of a catalog entry, leaving every other
# line as it is. The caller passes -v sha=<commit> -v version=<label>.

function main(line) {
  if (is_sha_line(line)) {
    print "sha: " sha
    return
  }
  if (is_version_line(line)) {
    print "version: \"" version "\""
    return
  }
  print line
}

function is_sha_line(line) {
  return line ~ /^sha:[[:space:]]/
}

function is_version_line(line) {
  return line ~ /^version:[[:space:]]/
}

{ main($0) }
