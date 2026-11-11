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


class BlockDumper(yaml.SafeDumper):
  """A safe dumper that writes a string of several lines as a literal block, one line of the file per line of the string."""


def text_node(dumper, text):
  """The YAML node for text: a literal block when it has a line break, a plain or quoted scalar otherwise."""

  style = "|" if "\n" in text else None
  return dumper.represent_scalar("tag:yaml.org,2002:str", text, style=style)


BlockDumper.add_representer(str, text_node)


def dump_yaml(data):
  """data as a YAML document, its keys in the order data has them, block style, unicode kept, and a string of several lines as a literal block.

    dump_yaml({"name": "Notes", "org": "someone"})  ->  "name: Notes\\norg: someone\\n"
    dump_yaml({"description": "One.\\nTwo."})          ->  "description: |-\\n  One.\\n  Two.\\n"
  """

  return yaml.dump(data, Dumper=BlockDumper, sort_keys=False, allow_unicode=True, default_flow_style=False)
