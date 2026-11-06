"""The plugin's settings, as the user set them in Hermes or as the manifest declares them.

Hermes keeps a plugin's settings under plugins.entries.<id>.settings in its
own configuration, and the manifest's config_schema gives each one a default.
This module answers a setting by name from that configuration, and gives the
manifest's default when the user has not set it or when the plugin runs
outside Hermes, as the tests do.
"""
PLUGIN_ID = "creature-workshop"

DEFAULTS = {
  "ops_timeout_seconds": 120,
  "pane_refresh_seconds": 20,
}


def value(key):
  """The setting as the user set it, or the manifest's default.

    value("pane_refresh_seconds")  ->  20
  """
  return from_config(hermes_config(), key)


def from_config(config, key):
  """The setting named by key out of a Hermes configuration, or its default.

    from_config({"plugins": {"entries": {"creature-workshop": {"settings": {"pane_refresh_seconds": 5}}}}},
                "pane_refresh_seconds")  ->  5
  """
  entries = (config.get("plugins") or {}).get("entries") or {}
  settings = (entries.get(PLUGIN_ID) or {}).get("settings") or {}
  return settings.get(key, DEFAULTS[key])


def hermes_config():
  """Hermes's configuration, read without copying, or an empty one outside Hermes."""
  try:
    from hermes_cli.config import load_config_readonly
  except ImportError:
    return {}

  return load_config_readonly() or {}
