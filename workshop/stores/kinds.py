"""Registers every store the plugin ships under its kind. Importing this module is what makes them available to the /store routes."""

from workshop.stores.file.store import FileStore
from workshop.stores.plan.store import PlanStore
from workshop.stores.registry import register

FILE = register("file", FileStore())

PLAN = register("plan", PlanStore())
