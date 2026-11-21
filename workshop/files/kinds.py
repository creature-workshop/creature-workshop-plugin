"""Registers every kind of file the plugin ships. Importing this module is what makes them available to the /file routes."""

from workshop.files.document.files import DocumentFiles
from workshop.files.plan.files import PlanFiles
from workshop.files.registry import register

DOCUMENT = register("document", DocumentFiles())

PLAN = register("plan", PlanFiles())
