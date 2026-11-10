"""The file store: a shellops document under a project's .ops/config/, as one
record described by the project's own pinned shellops schema.

location.py turns a source into a file, schema.py finds its schema,
types.py and checks.py decide whether the schema takes a change, lines.py
rewrites only the changed key's lines, and store.py fills the Store contract
with them.
"""
