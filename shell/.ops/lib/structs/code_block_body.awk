# Prints the body of a markdown code block: the text without the line that
# opens the fence, ``` or ```<language>, and without the line that closes
# it. Blank lines before the fence and after it are left out. Text that
# opens with no fence is printed as it is, without the blank lines around
# it.
#
#   ```json
#   {"a": 1}
#   ```
#   ->  {"a": 1}

function main(line) {
  if (COUNT == 0 && line ~ /^[[:space:]]*$/) {
    return
  }

  LINE[++COUNT] = line
  if (line !~ /^[[:space:]]*$/) {
    LAST = COUNT
  }
}

# Whether a line opens a fence: three backticks, and a language or
# nothing.
function opens_fence(line) {
  return line ~ /^[[:space:]]*```[A-Za-z0-9]*[[:space:]]*$/
}

# Whether a line closes a fence: three backticks alone.
function closes_fence(line) {
  return line ~ /^[[:space:]]*```[[:space:]]*$/
}

END {
  first = 1
  if (LAST >= 1 && opens_fence(LINE[1])) {
    first = 2
    if (LAST >= 2 && closes_fence(LINE[LAST])) {
      LAST--
    }
  }

  for (i = first; i <= LAST; i++) {
    print LINE[i]
  }
}

{ main($0) }
