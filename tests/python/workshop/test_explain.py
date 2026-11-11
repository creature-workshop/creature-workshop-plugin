"""Covers workshop.project.explain and /project/dependencies/explain: why a project has a declared tool, from its files."""

import asyncio
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from fastapi import HTTPException

from workshop.project.explain import NO_ANSWER, NO_MODEL, NOUS_FREE, OPENROUTER_FREE, TASK, evidence, explain, mentions, register_task, unexplained
from workshop.routes.project import declared_tool, explain_dependency

FFMPEG = {"tool": "ffmpeg", "channel": "system", "version": "6.1.1"}
"""The declaration every explanation here is asked about."""


class Answer:
  """What PluginLlm's structured call returns, as far as the explanation reads it."""

  def __init__(self, parsed, model="stepfun/step-3.7-flash:free"):
    """Keeps the parsed answer and the model that gave it."""

    self.parsed = parsed
    self.model = model


class StandInLlm:
  """A PluginLlm that records what it was asked and answers `parsed`, or raises `error`."""

  def __init__(self, parsed=None, error=None):
    """Keeps the answer or the error, and no calls yet."""

    self.parsed = parsed
    self.error = error
    self.asked = []

  async def acomplete_structured(self, **request):
    """Records the request, then answers or raises."""

    self.asked.append(request)
    if self.error is not None:
      raise self.error

    return Answer(self.parsed)


def rig(root):
  """A git repository with a script that runs ffmpeg, a README, a declaration of ffmpeg and rsync, and a lock naming ffmpeg."""

  (root / ".ops" / "config").mkdir(parents=True)
  (root / "rec").write_text("#!/bin/sh\nffmpeg -i camera out.mkv\necho ffmpegs are not a word\n")
  (root / "README.md").write_text("# Rig\n\nRecords every session.\n")
  (root / ".ops" / "config" / "tools.yaml").write_text("system:\n  ffmpeg:\n    version: 6.1.1\n  rsync:\n    version: 3.2.7\n")
  (root / ".ops" / "lock").write_text('{"ffmpeg": "6.1.1"}\n')
  for args in (["init", "-q", "-b", "main"], ["add", "-A"], ["-c", "user.email=t@example.com", "-c", "user.name=T", "commit", "-q", "-m", "first"]):
    subprocess.run(["git", "-C", str(root), *args], check=True)

  return root


class Context:
  """A plugin context that records each auxiliary task registered with it."""

  def __init__(self):
    """No tasks yet."""

    self.tasks = []

  def register_auxiliary_task(self, key, **settings):
    """Records the task's key and settings."""

    self.tasks.append((key, settings))


class RegisterTask(unittest.TestCase):
  def test_registers_the_task_starting_on_a_free_model(self):
    ctx = Context()
    register_task(ctx)
    key, settings = ctx.tasks[0]
    defaults = settings["defaults"]
    self.assertEqual((key, defaults["provider"], defaults["model"]), (TASK, "nous", "stepfun/step-3.7-flash:free"))
    self.assertEqual(settings["display_name"], "Workshop: explain a dependency")

  def test_falls_back_through_every_other_free_model_and_no_paid_one(self):
    ctx = Context()
    register_task(ctx)
    chain = ctx.tasks[0][1]["defaults"]["fallback_chain"]
    self.assertEqual(len(chain), len(NOUS_FREE) - 1 + len(OPENROUTER_FREE))
    self.assertEqual([entry["provider"] for entry in chain[:2]], ["nous", "nous"])
    self.assertTrue(all(entry["model"].endswith(":free") for entry in chain))
    self.assertNotIn("stepfun/step-3.7-flash:free", [entry["model"] for entry in chain])

  def test_hands_hermes_its_own_copy_of_the_defaults(self):
    ctx = Context()
    register_task(ctx)
    ctx.tasks[0][1]["defaults"]["fallback_chain"].clear()
    register_task(ctx)
    self.assertTrue(ctx.tasks[1][1]["defaults"]["fallback_chain"])

  def test_registers_nothing_on_a_hermes_without_auxiliary_tasks(self):
    register_task(object())


class Mentions(unittest.TestCase):
  def test_lists_the_lines_that_hold_the_name_as_a_whole_word_and_leaves_out_the_lock(self):
    with tempfile.TemporaryDirectory() as tmp:
      found = mentions(rig(Path(tmp) / "rig"), "ffmpeg")
      self.assertEqual(found, ".ops/config/tools.yaml:2:  ffmpeg:\nrec:2:ffmpeg -i camera out.mkv")

  def test_nothing_for_a_name_no_line_holds_and_outside_a_repository(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertEqual(mentions(rig(Path(tmp) / "rig"), "sox"), "")
      self.assertEqual(mentions(Path(tmp), "ffmpeg"), "")


class Explain(unittest.TestCase):
  def test_answers_the_models_explanation_trimmed(self):
    with tempfile.TemporaryDirectory() as tmp:
      llm = StandInLlm({"explanation": " rec records the cameras through ffmpeg. "})
      answer = asyncio.run(explain(rig(Path(tmp) / "rig"), FFMPEG, llm))
      self.assertEqual(answer, {"found": True, "explanation": "rec records the cameras through ffmpeg.", "reason": "", "model": "stepfun/step-3.7-flash:free"})

  def test_shows_the_model_the_tool_its_mentions_and_the_readme(self):
    with tempfile.TemporaryDirectory() as tmp:
      llm = StandInLlm({"explanation": "x"})
      asyncio.run(explain(rig(Path(tmp) / "rig"), FFMPEG, llm))
      text = llm.asked[0]["input"][0]["text"]
      self.assertIn("Tool: ffmpeg\nChannel: system\nDeclared version: 6.1.1", text)
      self.assertIn("rec:2:ffmpeg -i camera out.mkv", text)
      self.assertIn("Records every session.", text)

  def test_says_none_when_nothing_mentions_the_tool(self):
    with tempfile.TemporaryDirectory() as tmp:
      text = evidence(rig(Path(tmp) / "rig"), {"tool": "sox", "channel": "system", "version": ""})
      self.assertIn("Lines that mention the tool:\n(none)", text)
      self.assertIn("Declared version: (none)", text)

  def test_asks_for_an_object_that_allows_no_other_property(self):
    with tempfile.TemporaryDirectory() as tmp:
      llm = StandInLlm({"explanation": "x"})
      asyncio.run(explain(rig(Path(tmp) / "rig"), FFMPEG, llm))
      self.assertIs(llm.asked[0]["json_schema"]["additionalProperties"], False)

  def test_routes_through_the_auxiliary_task_only_when_hermes_has_it_registered(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = rig(Path(tmp) / "rig")
      llm = StandInLlm({"explanation": "x"})
      for registered in (False, True):
        with mock.patch("workshop.project.explain.task_registered", return_value=registered):
          asyncio.run(explain(root, FFMPEG, llm))

      self.assertNotIn("task", llm.asked[0])
      self.assertEqual(llm.asked[1]["task"], TASK)

  def test_gives_the_reason_when_the_call_fails_or_answers_nothing(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = rig(Path(tmp) / "rig")
      self.assertEqual(asyncio.run(explain(root, FFMPEG, StandInLlm(error=RuntimeError("Error code: 400")))), unexplained("Error code: 400"))
      self.assertEqual(asyncio.run(explain(root, FFMPEG, StandInLlm({"explanation": "  "}))), unexplained(NO_ANSWER))
      self.assertEqual(asyncio.run(explain(root, FFMPEG, StandInLlm("not an object"))), unexplained(NO_ANSWER))


class Route(unittest.TestCase):
  def test_finds_a_declared_tool_with_its_channel_and_version(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = rig(Path(tmp) / "rig")
      self.assertEqual(declared_tool(str(root), "rsync"), {"tool": "rsync", "channel": "system", "version": "3.2.7"})
      self.assertIsNone(declared_tool(str(root), "sox"))

  def test_refuses_a_tool_the_project_does_not_declare(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = rig(Path(tmp) / "rig")
      with self.assertRaises(HTTPException) as refused:
        asyncio.run(explain_dependency(root=str(root), tool="sox"))

      self.assertEqual((refused.exception.status_code, refused.exception.detail), (404, "rig declares no tool named sox."))

  def test_answers_found_false_and_the_reason_with_no_model_to_ask(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = rig(Path(tmp) / "rig")
      with mock.patch("workshop.project.explain.host_llm", return_value=None):
        answer = asyncio.run(explain_dependency(root=str(root), tool="ffmpeg"))

      self.assertEqual((answer.found, answer.explanation, answer.reason), (False, "", NO_MODEL))

  def test_answers_the_explanation_the_model_gives(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = rig(Path(tmp) / "rig")
      llm = StandInLlm({"explanation": "rec records the cameras through ffmpeg."})
      with mock.patch("workshop.project.explain.host_llm", return_value=llm):
        answer = asyncio.run(explain_dependency(root=str(root), tool="ffmpeg"))

      self.assertEqual((answer.found, answer.explanation, answer.reason), (True, "rec records the cameras through ffmpeg.", ""))
      self.assertEqual(answer.model, "stepfun/step-3.7-flash:free")
