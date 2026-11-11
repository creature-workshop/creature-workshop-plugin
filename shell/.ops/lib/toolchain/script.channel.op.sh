#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/toolchain/tool.sh"

: <<'DOC'
Channel plugin for the tools shellops and a project provision themselves:
through the tool's plugin (lib/toolchain/tool.sh) when one is registered
under its name and answers @install, and otherwise through its installer script pair from
`plugins/tools` and the project's scripts directory, whose exit status is
the tool's: an installer that ends in a failing command fails the install,
and `ops install` reports the tool as failed.

Requirements:
  version           the pinned version, which a plugin reads
  installer_path    path to the installer script, for a tool with no plugin
  uninstaller_path  path to the uninstaller script, likewise
DOC

: <<'FUN'
Provisions the tool $1 from its requirements $2: by its plugin when one is
registered and answers @install, by its installer script otherwise.
FUN
__toolchain__script_channel__install() {
  if @is_true "$(toolchain__tool__answers "$1" install)"; then
    toolchain__tool__install "$1" "$2"
  else
    @get __toolchain__script_channel__install__get_1 "$2" '.installer_path'
    __toolchain__script_channel__run_script "$1" "$2" "$__toolchain__script_channel__install__get_1"
  fi
}

: <<'FUN'
Removes the tool $1 from its requirements $2: by its plugin when one is
registered and answers @uninstall, by its uninstaller script otherwise.
FUN
__toolchain__script_channel__uninstall() {
  if @is_true "$(toolchain__tool__answers "$1" uninstall)"; then
    toolchain__tool__uninstall "$1" "$2"
  else
    @get __toolchain__script_channel__uninstall__get_2 "$2" '.uninstaller_path'
    __toolchain__script_channel__run_script "$1" "$2" "$__toolchain__script_channel__uninstall__get_2"
  fi
}

: <<'FUN'
Prints true when the tool $1 with requirements $2 is installed: as its
plugin judges when it has one answering @installed, as its library judges
when lib/<tool>/api.sh answers <tool>__installed <version> <requirements>,
and otherwise by whether a command of its name is on PATH.

The library's answer is the difference between "the pinned build is
installed" and "a command of that name is on PATH", which a snap or a
distro package satisfies just as well. The library reads the version from
its first argument and anything else it pins, such as a toolchain and its
components, from the requirements.

  __toolchain__script_channel__installed tectonic '{"version":"0.15.0"}'  ->  true
FUN
__toolchain__script_channel__installed() {
  if @is_true "$(toolchain__tool__answers "$1" installed)"; then
    toolchain__tool__installed "$1" "$2"
  elif __toolchain__script_channel__library_answers "$1"; then
    @get __toolchain__script_channel__installed__get_3 "$2" '.version' ''
    "${1}__installed" "$__toolchain__script_channel__installed__get_3" "$2"
  else
    @succeeds __toolchain__script_channel__installed__out __toolchain__script_channel__on_path "$1"
    println "$__toolchain__script_channel__installed__out"
  fi
}

: <<'FUN'
Records an installed tool's environment in the checkout by running its
installer, for a tool whose plugin or library can say it is installed: such
an install on a version already in the tools home puts it on PATH and into
the env fragment and does nothing else, which is what a checkout that
skipped the install is missing. A tool judged installed from PATH alone has
no environment to record and runs nothing.
FUN
__toolchain__script_channel__activate() {
  if @is_true "$(toolchain__tool__answers "$1" installed)"; then
    __toolchain__script_channel__install "$1" "$2"
  elif __toolchain__script_channel__library_answers "$1"; then
    __toolchain__script_channel__install "$1" "$2"
  fi
}

: <<'FUN'
Succeeds when lib/<tool>/api.sh exists and defines <tool>__installed, with
the library imported into this shell so the caller can call it. The import
happens here rather than in a command substitution, which would load the
library into a subshell and leave the caller a name it cannot call.
FUN
__toolchain__script_channel__library_answers() {
  __toolchain__script_channel__library_answers__api="$SHELLOPS_DIR/lib/$1/api.sh"

  if [ -f "$__toolchain__script_channel__library_answers__api" ]; then
    import "$__toolchain__script_channel__library_answers__api"
  fi

  __toolchain__script_channel__on_path "${1}__installed"
}

: <<'FUN'
Sources the script $3 for the tool $1 with its requirements $2 in the
environment, and returns the script's status.
FUN
__toolchain__script_channel__run_script() {
  export SHELLOPS_TOOL_NAME="$1"
  export SHELLOPS_TOOL_REQUIREMENTS="$2"
  . "$3"
  __toolchain__script_channel__run_script__status=$?
  unset SHELLOPS_TOOL_NAME
  unset SHELLOPS_TOOL_REQUIREMENTS
  return "$__toolchain__script_channel__run_script__status"
}

: <<'FUN'
Succeeds when a command named $1 is on PATH, printing nothing either way.
FUN
__toolchain__script_channel__on_path() {
  command -v "$1" >/dev/null 2>&1
}

:<<'DOC'
The script channel: one channel plugin, which a lock may also name local.
See lib/toolchain/channel.sh for what the roles mean. It names no
dependency: sh is the one thing it needs, so it is always installed.
DOC
@channel.script() {
  @summary() {
    println "The tools shellops and a project provision themselves, by plugin or installer script."
  }

  @aliases() {
    @arr __channel_script__out local
    println "$__channel_script__out"
  }

  @install_tool() {
    __toolchain__script_channel__install "$@"
  }

  @uninstall_tool() {
    __toolchain__script_channel__uninstall "$@"
  }

  @probe() {
    __toolchain__script_channel__installed "$@"
  }

  @activate() {
    __toolchain__script_channel__activate "$@"
  }
}
