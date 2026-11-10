"""Covers the /store routes over the file store: each answer's HTTP status and
its GraphQL-shaped body, `{data}` on success and `{data: null, errors}` with
the code and status in the error's extensions otherwise; a 3xx travelling as
HTTP 200; a mutation's operation checked for what it needs; and the project
root and store kind checked first.

The backend is loaded the way Hermes loads it, and each route is called
directly; the project is the one test_file_store builds.
"""

import asyncio
import importlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from fastapi.responses import JSONResponse

from tests.python.workshop.test_file_store import MANIFEST, project_copy
from workshop.models.store import MutateBody

BACKEND = Path(__file__).resolve().parents[3] / "dashboard" / "plugin_api.py"


def route_module():
  """workshop.routes.store, once the backend is loaded the way Hermes loads it."""

  spec = importlib.util.spec_from_file_location("plugin_api", BACKEND)
  spec.loader.exec_module(importlib.util.module_from_spec(spec))
  return importlib.import_module("workshop.routes.store")


def answer_of(result):
  """(HTTP status, body) of what a route returned: a JSONResponse as it is, a model as HTTP 200."""

  if isinstance(result, JSONResponse):
    return result.status_code, json.loads(result.body)

  return 200, result.model_dump()


def error_of(body):
  """(code, status) of the one error in a body."""

  extensions = body["errors"][0]["extensions"]
  return extensions["code"], extensions["status"]


class TheStoreRoutes(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.mkdtemp()
    self.root = str(project_copy(self.scratch))
    self.route = route_module()

  def tearDown(self):
    shutil.rmtree(self.scratch)

  def call(self, handler, **arguments):
    """The (HTTP status, body) of one route call."""

    return answer_of(asyncio.run(handler(**arguments)))

  def query(self, revision=""):
    """GET /store/query for the manifest."""

    return self.call(self.route.query, kind="file", root=self.root, source=MANIFEST, id="document", revision=revision)

  def revision(self):
    """The manifest's current revision."""

    return self.query()[1]["data"]["record"]["revision"]

  def mutate(self, **fields):
    """POST /store/mutate on the manifest with fields."""

    return self.call(self.route.mutate, body=MutateBody(kind="file", root=self.root, source=MANIFEST, **fields))

  def test_a_query_answers_the_record_as_data(self):
    status, body = self.query()
    self.assertEqual(status, 200)
    self.assertEqual(body["data"]["record"]["values"]["name"], "Recording rig")

  def test_a_query_without_an_id_answers_every_record(self):
    status, body = self.call(self.route.query, kind="file", root=self.root, source=MANIFEST, id="", revision="")
    self.assertEqual([record["id"] for record in body["data"]["records"]], ["document"])

  def test_a_query_at_the_current_revision_is_unchanged_as_304_in_an_http_200(self):
    status, body = self.query(self.revision())
    self.assertEqual(status, 200)
    self.assertIsNone(body["data"])
    self.assertEqual(error_of(body), ("UNCHANGED", 304))

  def test_a_set_answers_the_record_after_it(self):
    status, body = self.mutate(op="set", id="document", revision=self.revision(), key="description", value="A demo project.")
    self.assertEqual(status, 200)
    self.assertEqual(body["data"]["record"]["values"]["description"], "A demo project.")

  def test_a_stale_mutation_answers_409_with_the_current_record(self):
    revision = self.revision()
    current = self.mutate(op="set", id="document", revision=revision, key="description", value="A demo project.")[1]["data"]["record"]
    status, body = self.mutate(op="set", id="document", revision=revision, key="description", value="Another.")
    self.assertEqual((status, error_of(body)), (409, ("STALE", 409)))
    self.assertEqual(body["errors"][0]["extensions"]["record"], current)

  def test_a_refused_mutation_answers_400_with_the_reason_as_the_message(self):
    status, body = self.mutate(op="reset", id="document", revision=self.revision(), key="org")
    self.assertEqual((status, error_of(body)), (400, ("REFUSED", 400)))
    self.assertIn("requires", body["errors"][0]["message"])

  def test_a_mutation_missing_what_its_operation_needs_is_refused(self):
    status, body = self.mutate(op="set", id="document", key="description", value="x")
    self.assertEqual((status, error_of(body)[0]), (400, "REFUSED"))
    self.assertIn("needs revision", body["errors"][0]["message"])

  def test_introspect_answers_the_schema(self):
    status, body = self.call(self.route.introspect, kind="file", root=self.root, source=MANIFEST)
    self.assertEqual(status, 200)
    self.assertIn("name", body["data"]["schema"]["required"])

  def test_create_and_delete_on_the_file_store_answer_405(self):
    self.assertEqual(self.mutate(op="create", values={})[0], 405)
    self.assertEqual(self.mutate(op="delete", id="document", revision="x")[0], 405)

  def test_an_unknown_kind_answers_404(self):
    status, body = self.call(self.route.query, kind="nothing", root=self.root, source=MANIFEST, id="", revision="")
    self.assertEqual((status, error_of(body)[0]), (404, "NOT_FOUND"))

  def test_a_folder_inside_a_project_is_not_its_root(self):
    status, body = self.call(self.route.query, kind="file", root=str(Path(self.root) / "shell"), source=MANIFEST, id="", revision="")
    self.assertEqual((status, error_of(body)[0]), (400, "REFUSED"))
