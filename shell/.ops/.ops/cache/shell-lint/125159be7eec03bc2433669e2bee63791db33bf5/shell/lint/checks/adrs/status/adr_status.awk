# Prints a finding for each decision record whose Status line says anything
# but that the record is approved, or which record superseded it. A record
# reaches the default branch by being approved, so "proposed" there is never
# true. A record with no Status line is adr_shape.awk's to report, and only
# the header, the lines above the first section, is read, so a Status line
# quoted in an example is left alone. Reads every record named on the command
# line, one awk for the whole list. Exits 1 when there is a finding in any of
# them.
#
#     "- Status: proposed" on line 3 of adrs/000007-fragments/adr.md
#       ->  adrs/000007-fragments/adr.md:3: the status is "approved", or "superseded by" and a link to the ADR that did

function is_status(line) {
  return line ~ /^- Status: /
}

function status_stands(line) {
  return line ~ /^- Status: (approved|superseded by \[ADR\.[0-9]+@[^]]+\]\([^)]+\))$/
}

function report(line_number) {
  printf "%s:%s: the status is \"approved\", or \"superseded by\" and a link to the ADR that did\n", \
    FILENAME, line_number
  found = 1
}

function opens_section(line) {
  return line ~ /^## /
}

FNR == 1                                            { past_header = 0 }
opens_section($0)                                   { past_header = 1 }
!past_header && is_status($0) && !status_stands($0) { report(FNR) }

END { exit found }
