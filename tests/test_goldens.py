"""Every golden case under tests/goldens/cases/ produces its expected.txt.

UPDATE_GOLDENS=1 rewrites the expected transcripts instead of comparing them;
read the diff before committing one.
"""

import os
import unittest

from tests.goldens import runner


class Goldens(unittest.TestCase):
  def test_every_case_produces_its_expected_transcript(self):
    for case in runner.cases():
      with self.subTest(case=runner.name_of(case)):
        check(self, case)


def check(test, case):
  """Compares a golden case's transcript with its expected.txt, or writes the file when UPDATE_GOLDENS is 1."""

  actual = runner.transcript(case)
  expected_file = case / "expected.txt"
  if os.environ.get("UPDATE_GOLDENS") == "1":
    expected_file.write_text(actual)
    return

  name = runner.name_of(case)
  test.assertTrue(expected_file.is_file(), f"{name}: no expected.txt; run with UPDATE_GOLDENS=1 to write it")
  test.assertEqual(expected_file.read_text(), actual, f"{name}: the transcript changed, see {case / 'about.txt'}")


if __name__ == "__main__":
  unittest.main()
