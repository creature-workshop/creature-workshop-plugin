"""Holds the convention that the backend's routes and the pane's client mirror
each other: one module under workshop/routes/ for each module under
desktop/src/client/ (api.js and index.js aside), with the same name, and the
paths each client module requests are exactly the paths the backend module
of the same name registers. A route with no call, a call with no route, or a
path one side spells differently fails here.
"""

import importlib.util
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ROUTES = ROOT / "workshop" / "routes"
CLIENT = ROOT / "desktop" / "src" / "client"
BACKEND = ROOT / "dashboard" / "plugin_api.py"

CLIENT_PLUMBING = {"api", "index"}

REQUESTED = re.compile(r"rest\(\s*[`'\"](/[^`'\"?$]*)")


def route_topics():
  """The names of the modules under workshop/routes/."""

  return {path.stem for path in ROUTES.glob("*.py") if path.stem != "__init__"}


def client_topics():
  """The names of the modules under desktop/src/client/ that register calls."""

  return {path.stem for path in CLIENT.glob("*.js") if path.stem not in CLIENT_PLUMBING}


def registered_paths():
  """Each route topic's registered paths, read from the router the backend mounts."""

  spec = importlib.util.spec_from_file_location("plugin_api", BACKEND)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  paths = {}
  for route in module.router.routes:
    paths.setdefault(route.endpoint.__module__.rsplit(".", 1)[-1], set()).add(route.path)

  return paths


def requested_paths(topic):
  """The paths a client module requests, without their queries."""

  return set(REQUESTED.findall((CLIENT / f"{topic}.js").read_text()))


class RouteMirror(unittest.TestCase):
  def test_every_route_module_has_a_client_module_of_the_same_name(self):
    self.assertEqual(route_topics(), client_topics())

  def test_each_client_module_requests_the_paths_its_route_module_registers(self):
    registered = registered_paths()
    for topic in sorted(client_topics()):
      with self.subTest(topic=topic):
        self.assertEqual(requested_paths(topic), registered.get(topic, set()))


if __name__ == "__main__":
  unittest.main()
