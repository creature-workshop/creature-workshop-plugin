# Reports every decision record whose number another record already carries.
# Loaded after lib/markdown/records.awk, which says what a record's name and number are.
#
# Reads tab-separated lines on stdin. "taken<TAB><path>" names a record that
# holds its number; "file<TAB><path>" names a file under check, read only when
# it is a record in the folder the variable `folder` names. A finding is
# printed for each checked record whose number a taken record of a different
# name also carries, as "<path>:1: <why>". Exits 1 when there is a finding.

function holder_other_than(name, number, __i) {
  for (__i = 1; __i <= holders[number]; __i++) {
    if (holder[number, __i] != name) {
      return holder[number, __i]
    }
  }
  return ""
}

function record_taken(name, __number) {
  __number = number_of(name)
  if (__number == "") {
    return
  }
  holder[__number, ++holders[__number]] = name
}

function record_checked(path) {
  if (is_record(path, folder)) {
    checked[++checked_count] = path
  }
}

function report(path, __name, __number, __other) {
  __name = record_name(path)
  __number = number_of(__name)
  if (__number == "") {
    return
  }

  __other = holder_other_than(__name, __number)
  if (__other != "") {
    printf "%s:1: number %s is taken by %s\n", path, __number, __other
    found = 1
  }
}

BEGIN { FS = "\t" }

$1 == "taken" { record_taken(record_name($2)) }
$1 == "file"  { record_checked($2) }

END {
  for (i = 1; i <= checked_count; i++) {
    report(checked[i])
  }
  exit found
}
