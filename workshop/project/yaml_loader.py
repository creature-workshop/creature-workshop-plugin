"""Reading YAML: the one module of the plugin that imports a YAML library.

The plugin reads YAML with PyYAML, which plugin.yaml declares under
python_dependencies, so Hermes installs it with the plugin on every Python
it runs on. Every module that reads YAML calls load_yaml;
shell/lint/yaml_imports.py reports a YAML library imported anywhere else.
"""

import yaml


def load_yaml(text):
  """The YAML document in text as plain Python data, None for an empty document.

    load_yaml("name: Recording rig\\ntools: [ffmpeg]\\n")  ->  {"name": "Recording rig", "tools": ["ffmpeg"]}
  """

  return yaml.safe_load(text)
