"""The files under a project's .ops/ that the pane reads and writes as records.

A file is named by its kind and its source, such as the kind `document` and
the source `config/manifest.yaml`. The source is the file's path under
.ops/. The kind says how the file reads as records, each
`{id, revision, values}`, described by a JSON Schema. Each kind fills the
Files contract in contract.py and registers in registry.py, and the /file
routes serve every kind the same way. What a kind answers other than a
plain success is an outcome from outcomes.py, each with its HTTP status.
"""
