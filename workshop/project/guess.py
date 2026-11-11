"""The agent's guesses for a branch's first manifest: a one-line description,
and the command the project ships, from what its files say about it.

The guess is one structured call to the model the user is using, through
Hermes's ctx.llm surface (agent.plugin_llm), with the README's opening, the
names at the top of the checkout and the repository's name as its input.
Secrets in that text are masked before it leaves the machine. Outside
Hermes, or when the call fails, there is no guess, and the form starts
those fields empty. The answer's schema allows no other property, which
Anthropic's models require of every object in a schema.
"""

import logging
from pathlib import Path

log = logging.getLogger("creature-workshop")

PLUGIN_ID = "creature-workshop"

README_NAMES = ("README.md", "README", "README.rst", "README.txt", "readme.md")

README_CHARS = 4000

LISTED_NAMES = 40

TIMEOUT_SECONDS = 30

INSTRUCTIONS = (
  "You suggest two values for a software project's manifest. "
  "description: one plain sentence, under 120 characters, saying what the project is for, "
  "written for someone who has never seen it. "
  "command: the name of the command-line program the project ships, lowercase with hyphens, "
  "or an empty string when the project does not ship one. "
  "Use only what the input shows; do not invent features."
)

SCHEMA = {
  "type": "object",
  "properties": {
    "description": {"type": "string"},
    "command": {"type": "string"},
  },
  "required": ["description", "command"],
  "additionalProperties": False,
}


async def guess(root, llm=None):
  """The agent's description and command for the checkout at root, or None
  when there is no model to ask or the call fails. llm is the PluginLlm to
  ask; the plugin's own when not given.

    await guess("/code/notes")  ->  {"description": "Notes kept in git, with a CLI to search them.", "command": "notes"}
  """

  model = llm or host_llm()
  if model is None:
    return None

  try:
    result = await model.acomplete_structured(
      instructions=INSTRUCTIONS,
      input=[{"type": "text", "text": masked(evidence(Path(root)))}],
      json_schema=SCHEMA,
      schema_name="workshop.manifest-guess",
      purpose="creature-workshop.adoption",
      temperature=0.2,
      max_tokens=200,
      timeout=TIMEOUT_SECONDS,
    )
  except Exception as error:  # noqa: BLE001 - any failure of the model call means no guess
    log.warning("The manifest guess for %s failed: %s", root, error)
    return None

  return cleaned(result.parsed)


def host_llm():
  """The plugin's PluginLlm, or None outside Hermes."""

  try:
    from agent.plugin_llm import PluginLlm
  except ImportError:
    return None

  return PluginLlm(plugin_id=PLUGIN_ID)


def evidence(root):
  """What the model is shown: the repository's name, the names at the top of the checkout, and the README's opening."""

  names = sorted(path.name for path in root.iterdir() if not path.name.startswith("."))[:LISTED_NAMES]
  return f"Repository folder: {root.name}\nTop-level names: {', '.join(names)}\n\nREADME:\n{readme(root)}"


def readme(root):
  """The opening of the checkout's README, or "(none)" when it has none."""

  for name in README_NAMES:
    path = root / name
    if path.is_file():
      return path.read_text(errors="replace")[:README_CHARS]

  return "(none)"


def masked(text):
  """text with secrets masked, even when the user turned redaction off; text unchanged outside Hermes."""

  try:
    from agent.redact import redact_sensitive_text
  except ImportError:
    return text

  return redact_sensitive_text(text, force=True)


def cleaned(parsed):
  """The guess as the form takes it, or None when the model did not answer with both values."""

  if not isinstance(parsed, dict):
    return None

  description = parsed.get("description")
  command = parsed.get("command")
  if not isinstance(description, str) or not isinstance(command, str):
    return None

  return {"description": description.strip(), "command": command.strip()}
