"""Why a project has one of its declared tools, in the model's words, from what the project's files show.

The explanation is one structured call to a model through Hermes's ctx.llm
surface (agent.plugin_llm). Its input is the tool with its channel and
version, the lines of the repository that mention the tool, and the README's
opening. Secrets in that text are masked before it leaves the machine.
Nothing here runs a command of the project: the mentions come from git grep.

The call is routed through the auxiliary task TASK, which the plugin
registers with Hermes, so the model is a setting of its own under Settings →
Models → Auxiliary and is not the model the user chats with. The task
starts on TASK_DEFAULTS: a free model on Nous Portal, since an explanation
of a few sentences needs no more, with every other free model as its
fallback chain. NOUS_FREE lists the free models Nous Portal serves, the
first being the one the task starts on; OPENROUTER_FREE lists those
OpenRouter serves, which Hermes reaches only for a user who has an
OpenRouter key. Hermes tries that
chain when the model before it is rate limited or unreachable, and passes
over an entry whose provider the user has no account with. The chain is
long on purpose: Hermes falls back to the model the user chats with, which
may cost them, only when it can set up no entry of the chain. The user's
choice under Settings replaces all of this. Where Hermes has no such task
registered, the call uses the model the user is using.

The answer names the model that gave it, so the pane can say so. The answer's schema allows no other
property, which Anthropic's models require of every object in a schema.

When there is no explanation, the caller gets the reason instead, so the
pane can show it: there was no model to ask, the call failed with what the
provider said, or the model answered without an explanation.
"""

import copy
import logging
from pathlib import Path

from ..run.git import git
from .guess import host_llm, masked, readme

log = logging.getLogger("creature-workshop")

TASK = "workshop_explain"

TASK_NAME = "Workshop: explain a dependency"

TASK_DESCRIPTION = "Says why a project has one of its declared tools, when you press Explain on the Workshop pane's Dependencies tab."

NOUS_FREE = (
  "stepfun/step-3.7-flash:free",
  "upstage/solar-mini4:free",
  "meituan/longcat-2.5:free",
)

OPENROUTER_FREE = (
  "nvidia/nemotron-3.5-lightning:free",
  "nvidia/nemotron-3-ultra-550b-a55b:free",
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
  "cohere/north-mini-code:free",
  "thinkingmachines/inkling-2-small:free",
  "baidu/ernie-5.5-flash-preview:free",
  "recursive/flint-v1.0:free",
  "dots-studio/dots-3-note-preview:free",
  "nvidia/nemotron-3.5-super-vl:free",
  "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
  "liquid/lfm-3-1.7b:free",
  "liquid/lfm-2.5-2.6b:free",
)

TASK_DEFAULTS = {
  "provider": "nous",
  "model": NOUS_FREE[0],
  "fallback_chain": [
    *({"provider": "nous", "model": model} for model in NOUS_FREE[1:]),
    *({"provider": "openrouter", "model": model} for model in OPENROUTER_FREE),
  ],
}

MENTION_LINES = 40

MENTION_CHARS = 200

TIMEOUT_SECONDS = 30

NO_MODEL = "Hermes has no model to ask."

NO_ANSWER = "The model answered without an explanation."

INSTRUCTIONS = (
  "You explain why a software project depends on one tool. "
  "Answer in two or three plain sentences, under 400 characters, for someone new to the project. "
  "Use only what the input shows: the lines of the repository that mention the tool, and the README. "
  "If nothing shows a use of the tool, say that the project declares it and that you found no use of it; "
  "do not invent one."
)

SCHEMA = {
  "type": "object",
  "properties": {"explanation": {"type": "string"}},
  "required": ["explanation"],
  "additionalProperties": False,
}


def register_task(ctx):
  """Registers TASK with Hermes, starting on TASK_DEFAULTS, through the plugin's context ctx; nothing on a Hermes that has no auxiliary tasks."""

  register = getattr(ctx, "register_auxiliary_task", None)
  if register is not None:
    register(TASK, display_name=TASK_NAME, description=TASK_DESCRIPTION, defaults=copy.deepcopy(TASK_DEFAULTS))


async def explain(root, tool, llm=None):
  """Why the checkout at root has the declared tool, as an answer with the
  keys found, explanation, reason and model: the explanation and the model
  that gave it, or why there is none. tool is its declaration, with the keys
  tool, channel and version. llm is the PluginLlm to ask; the plugin's own
  when not given.

    await explain("/code/rig", {"tool": "ffmpeg", "channel": "system", "version": "6.1.1"})
     ->  {"found": True, "explanation": "rec records each camera through ffmpeg.", "reason": "", "model": "stepfun/step-3.7-flash:free"}
  """

  model = llm or host_llm()
  if model is None:
    return unexplained(NO_MODEL)

  try:
    result = await model.acomplete_structured(**request(Path(root), tool))
  except Exception as error:  # noqa: BLE001 - any failure of the model call means no explanation
    log.warning("The explanation of %s for %s failed: %s", tool["tool"], root, error)
    return unexplained(masked(str(error)))

  explanation = cleaned(result.parsed)
  if explanation is None:
    return unexplained(NO_ANSWER)

  return {"found": True, "explanation": explanation, "reason": "", "model": str(getattr(result, "model", "") or "")}


def unexplained(reason):
  """The answer when there is no explanation, with why."""

  return {"found": False, "explanation": "", "reason": reason, "model": ""}


def request(root, tool):
  """The structured call that asks for the explanation, routed through TASK when Hermes has it registered."""

  call = {
    "instructions": INSTRUCTIONS,
    "input": [{"type": "text", "text": masked(evidence(root, tool))}],
    "json_schema": SCHEMA,
    "schema_name": "workshop.dependency-explanation",
    "purpose": "creature-workshop.explain-dependency",
    "temperature": 0.2,
    "max_tokens": 250,
    "timeout": TIMEOUT_SECONDS,
  }

  if task_registered():
    call["task"] = TASK

  return call


def task_registered():
  """Whether Hermes holds the auxiliary task TASK; False outside Hermes."""

  try:
    from hermes_cli.plugins import get_plugin_auxiliary_tasks
  except ImportError:
    return False

  return any(entry.get("key") == TASK for entry in get_plugin_auxiliary_tasks())


def evidence(root, tool):
  """What the model is shown: the tool with its channel and version, the lines that mention it, and the README's opening."""

  found = mentions(root, tool["tool"])
  return (
    f"Repository folder: {root.name}\n"
    f"Tool: {tool['tool']}\nChannel: {tool['channel']}\nDeclared version: {tool['version'] or '(none)'}\n\n"
    f"Lines that mention the tool:\n{found or '(none)'}\n\n"
    f"README:\n{readme(root)}"
  )


def mentions(root, name):
  """The tracked lines under root that hold name as a whole word, as git grep prints them, `path:line:text`:
  the first MENTION_LINES, each cut to MENTION_CHARS. The lock is left out, since it lists every tool. "" when
  there is none or root is not a git repository.

    mentions("/code/rig", "ffmpeg")  ->  "rec:290:    print(f\"laptop ffmpeg: ...\")\n..."
  """

  found = git(root, "grep", "-n", "-I", "-w", "-F", "-e", name, "--", ".", ":(exclude).ops/lock")
  return "\n".join(line[:MENTION_CHARS] for line in found.splitlines()[:MENTION_LINES])


def cleaned(parsed):
  """The explanation as the pane shows it, or None when the model gave none."""

  if not isinstance(parsed, dict):
    return None

  explanation = parsed.get("explanation")
  if not isinstance(explanation, str) or not explanation.strip():
    return None

  return explanation.strip()
