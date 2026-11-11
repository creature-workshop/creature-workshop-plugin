"""Covers workshop.project.guess: the agent's description and command for a checkout, from its files."""

import asyncio
import tempfile
import unittest
from pathlib import Path

from workshop.project.guess import evidence, guess


class Answer:
  """What PluginLlm's structured call returns, as far as the guess reads it."""

  def __init__(self, parsed):
    """Keeps the parsed answer."""

    self.parsed = parsed


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


def checkout(root):
  """A checkout with a README and two top-level names."""

  root.mkdir(parents=True)
  (root / "README.md").write_text("# Notes\n\nNotes kept in git, with a CLI to search them.\n")
  (root / "src").mkdir()
  return root


class Guess(unittest.TestCase):
  def test_answers_the_models_description_and_command_trimmed(self):
    with tempfile.TemporaryDirectory() as tmp:
      llm = StandInLlm({"description": " Notes kept in git. ", "command": "notes "})
      self.assertEqual(asyncio.run(guess(checkout(Path(tmp) / "notes"), llm)), {"description": "Notes kept in git.", "command": "notes"})

  def test_shows_the_model_the_readme_and_the_top_level_names(self):
    with tempfile.TemporaryDirectory() as tmp:
      llm = StandInLlm({"description": "x", "command": ""})
      asyncio.run(guess(checkout(Path(tmp) / "notes"), llm))
      text = llm.asked[0]["input"][0]["text"]
      self.assertIn("Notes kept in git, with a CLI", text)
      self.assertIn("Top-level names: README.md, src", text)
      self.assertEqual(llm.asked[0]["purpose"], "creature-workshop.adoption")

  def test_no_guess_when_the_call_fails_or_the_answer_is_not_both_values(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = checkout(Path(tmp) / "notes")
      self.assertIsNone(asyncio.run(guess(root, StandInLlm(error=TimeoutError("slow")))))
      self.assertIsNone(asyncio.run(guess(root, StandInLlm({"description": "x"}))))

  def test_says_when_there_is_no_readme(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp) / "bare"
      root.mkdir()
      self.assertIn("README:\n(none)", evidence(root))
