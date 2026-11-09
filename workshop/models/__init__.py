"""The data models of the plugin: what its backend answers with, one module per concept.

Each module here defines the shape of one answer as Pydantic models, so the
pane and the tests can hold the backend to it. The field names are the ones
the pane reads, so a change here is a change to the pane. A caller imports a
model from the module of its concept, workshop.models.about for About, so a
new model needs nothing added here.
"""
