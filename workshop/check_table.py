"""Reading the table `ops install --check` prints into one record per declared tool.

The dispatcher logs the table on stderr, so rows reads both streams of the
run.
"""

INSTALLED_MARK = "✓"


def rows(outcome):
  """The text of `ops install --check` as rows. The dispatcher logs the table on
  stderr, so both streams are read."""

  return parse(outcome["stdout"] + "\n" + outcome["stderr"])


def parse(text):
  """The rows of `ops install --check` as records.

  The table is a header, a rule and one line per tool with a status mark, the
  tool, its version and its channel:

    parse("  ✓      ffmpeg    6.1.1    system\\n")
     ->  [{"tool": "ffmpeg", "version": "6.1.1", "channel": "system", "installed": True}]
  """

  rows = []
  for line in text.splitlines():
    parts = line.split()
    if len(parts) < 4 or parts[0] in ("Status",) or set(line.strip()) <= {"-"}:
      continue

    mark, tool, version, channel = parts[0], parts[1], parts[2], parts[3]
    rows.append({"tool": tool, "version": version, "channel": channel, "installed": mark == INSTALLED_MARK})

  return rows
