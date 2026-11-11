# What a path says about the decision record it names: the markdown documents
# a repository keeps as records, and the table files beside them. Every
# program that reads records loads this file first, so they agree on which
# file is a record and which number it carries. Loaded after
# lib/path/paths.awk, which says whether a path sits under a folder.
#
# A record is either a file named <number>-<slug>.md, or the file adr.md in a
# directory named <number>-<slug>:
#
#     record_name("docs/decisions/000034-a-climb.md")  ->  "000034-a-climb.md"
#     record_name("adrs/000007-fragments/adr.md")      ->  "000007-fragments"
#     record_name("adrs/template/adr.md")              ->  "template"
#     number_of("000007-fragments")                    ->  "000007"
#     number_of("template")                            ->  ""
#     plain_number("000007")                           ->  7
#
# A table file is a figure of a record in a directory, never a record itself:
# the file <name>.md in the directory tables under <number>-<slug>:
#
#     table_record("adrs/000007-fragments/tables/kinds.md")  ->  "000007-fragments"
#     table_record("adrs/000007-fragments/adr.md")           ->  ""

function record_name(path, __parts, __count) {
  __count = split(path, __parts, "/")
  if (__parts[__count] == "adr.md" && __count > 1) {
    return __parts[__count - 1]
  }
  return __parts[__count]
}

function number_of(name) {
  if (match(name, /^[0-9]+-/)) {
    return substr(name, 1, RLENGTH - 1)
  }
  return ""
}

function plain_number(number) {
  return number + 0
}

function table_record(path, __parts, __count) {
  __count = split(path, __parts, "/")
  if (__count < 3 || __parts[__count - 1] != "tables" || __parts[__count] !~ /\.md$/) {
    return ""
  }
  if (number_of(__parts[__count - 2]) == "") {
    return ""
  }
  return __parts[__count - 2]
}

function is_record(path, folder) {
  return is_under(path, folder) && number_of(record_name(path)) != "" && table_record(path) == ""
}

function is_table(path, folder) {
  return is_under(path, folder) && table_record(path) != ""
}
