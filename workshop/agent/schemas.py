"""What each tool looks like to the model: the JSON schema Hermes registers it under.

Hermes hands a tool's schema to the model as part of its prompt. The `name` is
what the model calls, the `description` is the whole of what it knows about
when to call it, and `parameters` is a JSON Schema of the arguments it may
pass; a handler then receives those arguments as a mapping. Nothing here runs
anything.
"""

PROJECT_SCHEMA = {
  "name": "workshop_project",
  "description": "What the session's selected project declares (its manifest, tools, ecosystems, imports and lint declarations), its release record, and which declared tools are installed right now. Call this first in a project that has shell/ops.",
  "parameters": {"type": "object", "properties": {}, "required": []},
}

INSTALL_SCHEMA = {
  "name": "workshop_install",
  "description": "Check which of the project's declared tools are installed (check true, the default), or install the missing ones (check false), optionally only the tools named. Installing fetches from the channel the declaration names. Nothing runs in a project the user has not approved.",
  "parameters": {
    "type": "object",
    "properties": {
      "check": {"type": "boolean", "description": "true to only report; false to install what is missing."},
      "tools": {"type": "array", "items": {"type": "string"}, "description": "Only these tools, by name."},
    },
    "required": [],
  },
}

TEST_SCHEMA = {
  "name": "workshop_test",
  "description": "The project's tests through shellops' selection: 'plan' prints which areas, suites and test files the given paths touch and runs nothing; 'files' runs exactly those; 'all' runs the full suite.",
  "parameters": {
    "type": "object",
    "properties": {
      "verb": {"type": "string", "enum": ["plan", "files", "all"], "description": "plan by default."},
      "paths": {"type": "array", "items": {"type": "string"}, "description": "The paths you changed, relative to the project."},
    },
    "required": [],
  },
}

LINT_SCHEMA = {
  "name": "workshop_lint",
  "description": "Run the project's house-style lint over the paths named, or over the whole project when none are. Findings come back as the lint prints them.",
  "parameters": {
    "type": "object",
    "properties": {
      "paths": {"type": "array", "items": {"type": "string"}, "description": "Files or directories to lint, relative to the project."},
    },
    "required": [],
  },
}
