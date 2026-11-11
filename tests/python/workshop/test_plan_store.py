"""Covers workshop.stores.plan: the plan store passes the store contract suite,
and over the plan of workshop/stores/plan/plan.fixture.yaml, in a copy of the
golden case `installed`, it lists a ticket per record, creates a ticket
under the next key in the default state, changes one ticket without making
another stale, refuses what a ticket does not take without touching the
file, and deletes a ticket along with the edges that reach it. A project
with no plan file has an empty plan, which the first ticket creates.
"""

import shutil
import tempfile
import unittest
from pathlib import Path

from tests.python.workshop.store_contract import StoreContract
from workshop.project.yaml_loader import load_yaml
from workshop.stores import kinds, registry
from workshop.stores.contract import Change
from workshop.stores.outcomes import NotFound, Refused, Stale, StoreFailure
from workshop.stores.plan.document import next_key
from workshop.stores.plan.store import PlanStore

REPOSITORY = Path(__file__).resolve().parents[3]
FIXTURE = REPOSITORY / "workshop" / "stores" / "plan" / "plan.fixture.yaml"
INSTALLED = Path(__file__).parent / "goldens" / "cases" / "installed" / "input"
PLAN = "data/plan.yaml"


class AProject(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.mkdtemp()
    self.root = Path(self.scratch) / "demo"
    shutil.copytree(INSTALLED, self.root)
    self.file = self.root / ".ops" / "data" / "plan.yaml"
    self.file.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(FIXTURE, self.file)
    self.store = PlanStore()
    self.source = PLAN

  def tearDown(self):
    shutil.rmtree(self.scratch)

  def change(self, key, change):
    """Applies one change to the ticket key at its current revision and answers the record after it."""

    record = self.store.read(self.root, PLAN, key)
    return self.store.write(self.root, PLAN, key, change, record["revision"])

  def on_disk(self):
    """The plan file as it parses now."""

    return load_yaml(self.file.read_text())


class PlanStoreContract(StoreContract, AProject):
  creates_records = True

  def accepted_change(self):
    """Moves the ticket to in review."""

    return Change("set", "state", "in_review")

  def refused_change(self):
    """Removes the title, which a ticket needs."""

    return Change("reset", "title")

  def unread_source(self):
    """The manifest, which is not a plan."""

    return "config/manifest.yaml"


class Registering(unittest.TestCase):
  def test_the_routes_serve_it_as_the_kind_plan(self):
    self.assertIs(registry.store_for("plan"), kinds.PLAN)


class Describing(AProject):
  def test_the_state_is_one_of_the_default_states_and_starts_as_todo(self):
    state = self.store.describe(self.root, PLAN)["properties"]["state"]
    self.assertEqual(state["enum"], ["backlog", "todo", "in_progress", "in_review", "done", "cancelled"])
    self.assertEqual(state["default"], "todo")

  def test_a_plan_that_names_its_states_has_those_and_starts_in_its_first_of_type_todo(self):
    self.file.write_text("states:\n  - {name: Idea, type: backlog}\n  - {name: Next, type: todo}\n  - {name: Shipped, type: done}\n")
    state = self.store.describe(self.root, PLAN)["properties"]["state"]
    self.assertEqual((state["enum"], state["default"]), (["Idea", "Next", "Shipped"], "Next"))

  def test_a_ticket_needs_only_a_title(self):
    self.assertEqual(self.store.describe(self.root, PLAN)["required"], ["title"])


class Reading(AProject):
  def test_lists_one_record_per_ticket_in_the_files_order_with_the_key_as_the_id(self):
    records = self.store.list(self.root, PLAN)
    self.assertEqual([record["id"] for record in records], ["PLAN-1", "PLAN-2", "PLAN-3"])
    self.assertEqual(records[1]["values"], {"title": "Post the video", "state": "todo", "blocked_by": ["PLAN-1"]})

  def test_a_project_with_no_plan_file_has_an_empty_plan(self):
    self.file.unlink()
    self.assertEqual(self.store.list(self.root, PLAN), [])
    with self.assertRaises(NotFound):
      self.store.read(self.root, PLAN, "PLAN-1")

  def test_a_plan_that_does_not_parse_is_a_store_failure(self):
    self.file.write_text("tickets: [unclosed\n")
    with self.assertRaises(StoreFailure):
      self.store.list(self.root, PLAN)


class Creating(AProject):
  def test_a_new_ticket_takes_the_next_key_and_the_default_state_and_goes_last(self):
    record = self.store.create(self.root, PLAN, {"title": "Thank the judges"})
    self.assertEqual((record["id"], record["values"]), ("PLAN-4", {"state": "todo", "title": "Thank the judges"}))
    self.assertEqual(self.on_disk()["tickets"][-1], {"key": "PLAN-4", "state": "todo", "title": "Thank the judges"})
    self.assertEqual(self.store.read(self.root, PLAN, "PLAN-4"), record)

  def test_a_new_ticket_keeps_the_state_and_the_blockers_it_names(self):
    record = self.store.create(self.root, PLAN, {"title": "Celebrate", "state": "backlog", "blocked_by": ["PLAN-3"]})
    self.assertEqual(record["values"], {"state": "backlog", "title": "Celebrate", "blocked_by": ["PLAN-3"]})

  def test_the_first_ticket_of_a_project_creates_the_plan_file(self):
    shutil.rmtree(self.file.parent)
    record = self.store.create(self.root, PLAN, {"title": "Start"})
    self.assertEqual(record["id"], "PLAN-1")
    self.assertEqual(self.on_disk(), {"tickets": [{"key": "PLAN-1", "state": "todo", "title": "Start"}]})

  def test_a_ticket_without_a_title_or_with_something_a_ticket_does_not_take_is_refused_and_writes_nothing(self):
    before = self.file.read_text()
    for values in ({}, {"title": "  "}, {"title": "x", "state": "someday"}, {"title": "x", "colour": "red"}, {"title": "x", "blocked_by": ["PLAN-9"]}):
      with self.assertRaises(Refused):
        self.store.create(self.root, PLAN, values)

    self.assertEqual(self.file.read_text(), before)

  def test_the_next_key_is_one_past_the_highest_of_the_plans_prefix(self):
    self.assertEqual(next_key({"prefix": "T", "tickets": [{"key": "T-1"}, {"key": "T-7"}, {"key": "OTHER-9"}]}), "T-8")
    self.assertEqual(next_key({}), "PLAN-1")


class Writing(AProject):
  def test_a_set_changes_that_ticket_and_keeps_the_rest_of_the_file(self):
    after = self.change("PLAN-2", Change("set", "description", "Tag NousResearch.\nLink the pull request."))
    self.assertEqual(after["values"]["description"], "Tag NousResearch.\nLink the pull request.")
    tickets = self.on_disk()["tickets"]
    self.assertEqual(tickets[1]["description"], "Tag NousResearch.\nLink the pull request.")
    self.assertEqual((tickets[0]["title"], tickets[2]["blocked_by"], self.on_disk()["prefix"]), ("Record the demo", ["PLAN-2"], "PLAN"))

  def test_a_change_to_one_ticket_does_not_make_a_write_to_another_stale(self):
    other = self.store.read(self.root, PLAN, "PLAN-3")
    self.change("PLAN-2", Change("set", "state", "done"))
    after = self.store.write(self.root, PLAN, "PLAN-3", Change("set", "state", "in_progress"), other["revision"])
    self.assertEqual(after["values"]["state"], "in_progress")

  def test_a_write_at_an_old_revision_of_the_same_ticket_is_stale(self):
    old = self.store.read(self.root, PLAN, "PLAN-2")
    self.change("PLAN-2", Change("set", "state", "done"))
    with self.assertRaises(Stale):
      self.store.write(self.root, PLAN, "PLAN-2", Change("set", "title", "Post it"), old["revision"])

  def test_a_clear_reads_back_as_null_and_a_reset_as_absent(self):
    self.assertIsNone(self.change("PLAN-1", Change("clear", "estimate"))["values"]["estimate"])
    self.assertNotIn("estimate", self.change("PLAN-1", Change("reset", "estimate"))["values"])

  def test_what_a_ticket_does_not_take_is_refused_and_writes_nothing(self):
    before = self.file.read_text()
    refused = (
      Change("set", "title", ""),
      Change("set", "state", "someday"),
      Change("set", "estimate", "two"),
      Change("clear", "title"),
      Change("set", "colour", "red"),
    )

    for change in refused:
      with self.assertRaises(Refused):
        self.change("PLAN-2", change)

    self.assertEqual(self.file.read_text(), before)


class Blocking(AProject):
  def test_a_ticket_takes_other_tickets_of_the_plan_as_its_blockers(self):
    after = self.change("PLAN-3", Change("set", "blocked_by", ["PLAN-1", "PLAN-2"]))
    self.assertEqual(after["values"]["blocked_by"], ["PLAN-1", "PLAN-2"])

  def test_a_ticket_is_not_blocked_by_itself_an_unknown_ticket_or_the_same_ticket_twice(self):
    for blockers in (["PLAN-2"], ["PLAN-9"], ["PLAN-1", "PLAN-1"], [3]):
      with self.assertRaises(Refused):
        self.change("PLAN-2", Change("set", "blocked_by", blockers))

  def test_a_ticket_is_not_blocked_by_one_it_blocks_even_through_others(self):
    with self.assertRaises(Refused) as raised:
      self.change("PLAN-1", Change("set", "blocked_by", ["PLAN-3"]))

    self.assertEqual(raised.exception.reason, "PLAN-3 is already blocked by PLAN-1, so PLAN-1 cannot be blocked by it.")


class Deleting(AProject):
  def test_a_delete_removes_the_ticket_and_drops_it_from_every_tickets_blockers(self):
    record = self.store.read(self.root, PLAN, "PLAN-2")
    self.store.delete(self.root, PLAN, "PLAN-2", record["revision"])
    self.assertEqual([record["id"] for record in self.store.list(self.root, PLAN)], ["PLAN-1", "PLAN-3"])
    self.assertNotIn("blocked_by", self.store.read(self.root, PLAN, "PLAN-3")["values"])

  def test_a_delete_at_an_old_revision_is_stale_and_removes_nothing(self):
    old = self.store.read(self.root, PLAN, "PLAN-2")
    self.change("PLAN-2", Change("set", "state", "done"))
    with self.assertRaises(Stale):
      self.store.delete(self.root, PLAN, "PLAN-2", old["revision"])

    self.assertEqual(len(self.store.list(self.root, PLAN)), 3)

  def test_a_deleted_key_is_not_given_to_the_next_ticket_while_a_higher_one_remains(self):
    record = self.store.read(self.root, PLAN, "PLAN-2")
    self.store.delete(self.root, PLAN, "PLAN-2", record["revision"])
    self.assertEqual(self.store.create(self.root, PLAN, {"title": "New"})["id"], "PLAN-4")
