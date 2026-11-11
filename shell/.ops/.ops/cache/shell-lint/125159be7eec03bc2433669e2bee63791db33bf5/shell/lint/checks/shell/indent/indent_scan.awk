# Heredoc-aware, line-level indentation scanner. Prints one
#   <file>:<lineno>: <message>
# line per offending source line and nothing for clean input; the exit status
# is always 0 (the caller decides severity from the presence of output).
#
# Two rules apply to every line that carries indentation: the leading
# whitespace must contain no hard tabs (unless -v allow_tabs=1), and a leading
# run of spaces must be a multiple of -v width (default 2). Trailing whitespace
# is reported as well. Heredoc bodies are skipped, and findings go through note();
# both live in the shared runtime. Load it first: `awk -f scan.awk -f indent_scan.awk`.

# Default the indentation width when the caller leaves -v width unset (an empty
# or non-positive value), so the modulo rule below never divides by zero.
BEGIN {
  if (width + 0 <= 0) {
    width = 2
  }
}

# Reset per-file state so a single awk run can scan many files.
FNR == 1 { in_heredoc = 0 }

{
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
    }
    next
  }

  # The opener line is real code: check its own indentation below, then skip
  # its body on the following lines.
  if (opens_heredoc($0)) {
    in_heredoc = 1
  }

  match($0, /^[ \t]*/)
  indent = substr($0, 1, RLENGTH)

  if (!allow_tabs && index(indent, "\t") > 0) {
    note(FNR, "tab in indentation (use spaces)")
  } else if (index(indent, "\t") == 0 && RLENGTH < length($0) && (RLENGTH % width) != 0) {
    note(FNR, "indentation is not a multiple of " width " (" RLENGTH " spaces)")
  }

  if (length($0) > 0 && $0 ~ /[ \t]$/) {
    note(FNR, "trailing whitespace")
  }
}
