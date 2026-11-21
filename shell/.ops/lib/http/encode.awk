# Percent-encodes text as one URL component. Reads the text on stdin, with
# one newline after it, and prints the encoded text on one line. A newline
# inside the text becomes %0A. Loaded after uri.awk.
#
#   'Over cap'!A1:Y  ->  %27Over%20cap%27%21A1%3AY

function main(line) {
  if (NR > 1) {
    printf "%%0A"
  }
  printf "%s", encoded(line)
}

BEGIN {
  load_codes()
}

END {
  printf "\n"
}

{ main($0) }
