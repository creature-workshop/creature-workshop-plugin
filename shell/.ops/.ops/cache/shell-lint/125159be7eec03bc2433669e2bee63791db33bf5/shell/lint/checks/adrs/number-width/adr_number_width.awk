# Prints a finding for each decision record whose number is not written with
# `number_digits` digits, zeros in front. Records sort by name, and a folder
# that pads some numbers to four digits and others to six sorts wrongly and
# reads as two series. Reads every record named on the command line, one awk
# for the whole list, and looks at each one's name on its first line. Exits 1
# when there is a finding in any of them. Loaded after
# lib/markdown/records.awk.
#
#     adrs/0007-fragments/adr.md, number_digits=6
#       ->  adrs/0007-fragments/adr.md:1: the record's number is written with 6 digits: 000007

function padded(number) {
  return sprintf("%0" number_digits "d", plain_number(number))
}

function report(number) {
  printf "%s:1: the record's number is written with %d digits: %s\n", \
    FILENAME, number_digits, padded(number)
  found = 1
}

FNR == 1 && number_of(record_name(FILENAME)) != padded(number_of(record_name(FILENAME))) {
  report(number_of(record_name(FILENAME)))
}

END { exit found }
