"""Runs one golden case of the tools and writes its transcript.

A case is a directory under tests/goldens/cases/ with the same shape as a
shell-goldens fileset:

  name.txt      one line that names the case
  about.txt     prose: what the case shows and why it is worth keeping
  calls.txt     the input: one tool call per line, `<tool> <json arguments>`
  input/        the input: the project the calls run in, as a directory tree
         (its shell/ops is a stub that prints what the case needs)
  expected.txt  the output: the transcript the calls must produce

The transcript has one block per call: `## <call>`, then the tool's reply as
sorted, indented JSON, or `!! <error>` when the handler raised. The project is
copied to a fresh directory before the calls run, so the replies name it as
`<root>`, and `duration_ms` is written as `<ms>`; nothing else is normalised.
A case without an input/ runs in an empty directory, which is how the tools
answer outside any project.
"""

import json
import shutil
import tempfile
from pathlib import Path

from workshop import tools

CASES = Path(__file__).parent / "cases"
HANDLERS = {
  "workshop_project": tools.workshop_project,
  "workshop_install": tools.workshop_install,
  "workshop_test": tools.workshop_test,
  "workshop_lint": tools.workshop_lint,
}


def cases():
  """The case directories, in directory order. The directory only locates a
  case; its name is in name.txt, through name_of."""

  return sorted(path for path in CASES.iterdir() if (path / "calls.txt").is_file())


def name_of(case):
  """The case's name, the one line of its name.txt."""

  return (case / "name.txt").read_text().strip()


def transcript(case):
  """The transcript of a case's calls, run in a fresh copy of its input."""

  with tempfile.TemporaryDirectory() as scratch:
    root = Path(scratch) / "project"
    copy_input(case, root)
    blocks = [block(line, root) for line in calls_of(case)]

  return "".join(blocks)


def copy_input(case, root):
  """Copies the case's input/ tree to root, or makes root empty when there is none."""

  source = case / "input"
  if source.is_dir():
    shutil.copytree(source, root)
  else:
    root.mkdir()


def calls_of(case):
  """The call lines of the case, without blank lines and # comments."""

  lines = (case / "calls.txt").read_text().splitlines()
  return [line for line in lines if line.strip() and not line.lstrip().startswith("#")]


def block(line, root):
  """One transcript block: the call line and the reply it produced in root."""

  return f"## {line}\n{reply(line, root)}\n"


def reply(line, root):
  """The transcript entry for one tool call in a case: the tool's answer with the case's root replaced, or the error it raised."""

  tool, arguments = parse_call(line)
  arguments.setdefault("path", str(root))
  try:
    answer = json.loads(HANDLERS[tool](arguments))
  except Exception as error:
    return f"!! {type(error).__name__}: {error}"

  return json.dumps(normalised(answer, root), indent=2, sort_keys=True, ensure_ascii=False)


def normalised_field(key, item, root):
  """One field of a reply: a duration as <ms>, anything else normalised like the reply."""

  if key == "duration_ms":
    return "<ms>"

  return normalised(item, root)


def parse_call(line):
  """`workshop_test {"verb": "plan"}`  ->  ("workshop_test", {"verb": "plan"})"""

  tool, _, rest = line.partition(" ")
  return tool, json.loads(rest or "{}")


def normalised(value, root):
  """The reply with the scratch root written as <root> and durations as <ms>."""

  if isinstance(value, dict):
    return {key: normalised_field(key, item, root) for key, item in value.items()}

  if isinstance(value, list):
    return [normalised(item, root) for item in value]

  if isinstance(value, str):
    return value.replace(str(root), "<root>")

  return value
