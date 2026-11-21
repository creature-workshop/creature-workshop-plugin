# results.awk -- the outcome of every doctest a `cargo test --doc` run
# reports, one per line as crate, file, name and status, tab-separated.
#
# Under a crate's "Doc-tests <crate>" line rustdoc reports each doctest as
# "test <file> - <item> (line N) ... ok", the last word FAILED or ignored when
# it is; a doctest that only has to compile carries " - compile" in its name.
#
#   test src/lib.rs - add (line 5) ... FAILED
#   ->  foo<TAB>src/lib.rs<TAB>add (line 5)<TAB>FAILED

function doctest_of(line) {
  sub(/^test /, "", line)
  sub(/ \.\.\. [A-Za-z]+$/, "", line)
  return line
}

function file_of(doctest) {
  sub(/ - .*$/, "", doctest)
  return doctest
}

function name_of(doctest) {
  sub(/^[^ ]+ - /, "", doctest)
  return doctest
}

/^ *Doc-tests / {
  crate = $2
  next
}

/^test [^ ]+ - .* \.\.\. (ok|FAILED|ignored)$/ {
  doctest = doctest_of($0)
  print crate "\t" file_of(doctest) "\t" name_of(doctest) "\t" $NF
}
