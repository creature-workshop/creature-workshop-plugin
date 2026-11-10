"""The YAML loader the plugin uses everywhere.

Tries hermes_yaml.safe_load first (the canonical YAML reader Hermes ships),
then ruamel.yaml directly, then PyYAML. Every module that reads YAML imports
load_yaml from here; nothing else in the codebase imports a YAML library
directly. shell/lint/yaml_imports.py enforces this.
"""

def load_yaml(text):
  """The document in text, parsed by the best YAML library available at runtime."""

  loader = _yaml_loader()
  return loader(text)


def _yaml_loader():
  """The load function for the YAML library that is installed, checked once."""

  try:
    from hermes_yaml import safe_load

    return safe_load
  except ImportError:
    pass

  try:
    from ruamel.yaml import YAML

    def load_ruamel(text):
      """Parse text with ruamel.yaml through a StringIO (ruamel wants a stream)."""
      from io import StringIO

      return YAML(typ="safe").load(StringIO(text))

    return load_ruamel
  except ImportError:
    pass

  try:
    import yaml

    return yaml.safe_load
  except ImportError:
    pass

  def load_missing(text):
    """Raise when no YAML library is installed; text is unused."""
    raise ImportError(
      "No YAML library is available. "
      "Run inside Hermes (which ships hermes_yaml), or install ruamel.yaml or PyYAML."
    )

  return load_missing
