"""Reading and writing YAML: the one module of the plugin that imports a YAML library.

The plugin reads and writes YAML with PyYAML, which plugin.yaml declares
under python_dependencies, so Hermes installs it with the plugin on every
Python it runs on. Every module that reads YAML calls load_yaml, and every
module that writes a new YAML file calls dump_yaml;
shell/lint/yaml_imports.py reports a YAML library imported anywhere else.
"""

import yaml


def load_yaml(text):
  """The YAML document in text as plain Python data, None for an empty document.

    load_yaml("name: Recording rig\\ntools: [ffmpeg]\\n")  ->  {"name": "Recording rig", "tools": ["ffmpeg"]}
  """

  return yaml.safe_load(text)


def dump_yaml(data):
  """data as a YAML document, its keys in the order data has them, block style, unicode kept.

    dump_yaml({"name": "Notes", "org": "someone"})  ->  "name: Notes\\norg: someone\\n"
  """

  return yaml.safe_dump(data, sort_keys=False, allow_unicode=True, default_flow_style=False)
