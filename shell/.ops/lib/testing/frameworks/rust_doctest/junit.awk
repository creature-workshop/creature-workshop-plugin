# junit.awk -- a JUnit report from results.awk's lines, for the escape join.
# Loaded after paths.awk, which supplies repo_path, xml and the crate
# directories.
#
# Each doctest becomes a testcase whose classname is the repo-relative file it
# lives in, the key the join reads under file-path, and whose name is its item
# and line. FAILED adds a failure child, ignored a skipped one. One testsuite
# per crate, in the order the run reported them.

function close_suite() {
  if (suite != "") {
    print "  </testsuite>"
  }
}

function open_suite(crate) {
  close_suite()
  suite = crate
  printf "  <testsuite name=\"%s\">\n", xml(crate)
}

function testcase(file, name, status) {
  printf "    <testcase classname=\"%s\" name=\"%s\"", xml(file), xml(name)
  if (status == "FAILED") {
    printf ">\n      <failure type=\"failure\">%s</failure>\n    </testcase>\n", xml(name)
  } else if (status == "ignored") {
    print "><skipped/></testcase>"
  } else {
    print "/>"
  }
}

BEGIN {
  FS = "\t"
  print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  print "<testsuites name=\"rust_doctest\">"
}

{
  if ($1 != suite) {
    open_suite($1)
  }
  testcase(repo_path(root_of[$1], $2), $3, $4)
}

END {
  close_suite()
  print "</testsuites>"
}
