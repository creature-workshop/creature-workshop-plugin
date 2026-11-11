# Prints the resolver with each tool's installer and uninstaller script
# path recorded on its registry entry, and every complaint about the
# scripts, as {resolver, errors}. Loaded after names.awk and
# resolver.awk.
#
# Input: the resolver, and ahead of it, with --with, the names of the
#        tools a registered tool plugin provisions, a list.
# Arguments: "installers" and "uninstallers", each the paths of script
#            files, one on each line, the project's last so that its
#            scripts win; and "scripts_dir", the directory a complaint
#            names as the place a script belongs.
#
# The complaints are: a tool of the script or the local channel that no
# plugin provisions and that has no installer or no uninstaller, in the
# order of the tools' names; then each installer with no uninstaller of
# the same tool; then each uninstaller with no installer.

function main(line) {
  tree_line(line)
}

# Reads a list of script paths, one on each line, into paths by the tool
# each names: its base name without the suffix. A later path of one tool
# replaces an earlier one. Fills names with the tools in byte order and
# returns how many there are.
function read_scripts(list, suffix, paths, names, __lines, __count, __i, __tool, __tools) {
  __count = split(list, __lines, "\n")
  __tools = 0

  for (__i = 1; __i <= __count; __i++) {
    if (__lines[__i] == "") {
      continue
    }

    __tool = __lines[__i]
    sub(/^.*\//, "", __tool)
    if (length(__tool) >= length(suffix) && substr(__tool, length(__tool) - length(suffix) + 1) == suffix) {
      __tool = substr(__tool, 1, length(__tool) - length(suffix))
    }
    if (!(__tool in paths)) {
      __tools++
      names[__tools] = __tool
    }
    paths[__tool] = __lines[__i]
  }
  sort_texts(names, __tools)

  return __tools
}

# Prints the registry with the script paths recorded on each tool that has
# a script.
function print_registry(depth, __tool) {
  print_open(depth, wrap("registry"), "map")

  for (__tool = NODE_FIRST[member(ROOT, "registry")]; __tool != 0; __tool = NODE_NEXT[__tool]) {
    print_open(depth + 1, NODE_KEY[__tool], "map")
    print_fields_with_scripts(__tool, depth + 2)
  }
}

# Prints the fields of a tool with its script paths: each where the tool
# has the field, and after its other fields when it has none, the
# installer's before the uninstaller's.
function print_fields_with_scripts(tool, depth, __field, __name, __installer_set, __uninstaller_set) {
  __name = name_of(tool)
  __installer_set = !(__name in INSTALLER)
  __uninstaller_set = !(__name in UNINSTALLER)

  for (__field = NODE_FIRST[tool]; __field != 0; __field = NODE_NEXT[__field]) {
    if (NODE_KEY[__field] == wrap("installer_path") && (__name in INSTALLER)) {
      print_str(depth, "installer_path", INSTALLER[__name])
      __installer_set = 1
    } else if (NODE_KEY[__field] == wrap("uninstaller_path") && (__name in UNINSTALLER)) {
      print_str(depth, "uninstaller_path", UNINSTALLER[__name])
      __uninstaller_set = 1
    } else {
      print_node(__field, depth, NODE_KEY[__field])
    }
  }

  if (!__installer_set) {
    print_str(depth, "installer_path", INSTALLER[__name])
  }
  if (!__uninstaller_set) {
    print_str(depth, "uninstaller_path", UNINSTALLER[__name])
  }
}

# Adds a complaint.
function complain(message) {
  print "1." COMPLAINTS ":str=" wrap(message)
  COMPLAINTS++
}

# Complains about each tool of the script or the local channel that no
# plugin provisions and that has no installer or no uninstaller.
function complain_of_missing(__tools, __count, __i, __channel) {
  __count = sorted_names(member(ROOT, "registry"), __tools)

  for (__i = 1; __i <= __count; __i++) {
    __channel = text_of(member(member(member(ROOT, "registry"), __tools[__i]), "channel"))
    if ((__channel != "script" && __channel != "local") || (__tools[__i] in HAS_PLUGIN)) {
      continue
    }

    if (!(__tools[__i] in INSTALLER)) {
      complain("script tool '" __tools[__i] "' is missing a .installer.sh in " arg("scripts_dir"))
    }
    if (!(__tools[__i] in UNINSTALLER)) {
      complain("script tool '" __tools[__i] "' is missing a .uninstaller.sh in " arg("scripts_dir"))
    }
  }
}

# Complains about each script that has no counterpart: the installers
# first, then the uninstallers.
function complain_of_unpaired(__i) {
  for (__i = 1; __i <= INSTALLERS; __i++) {
    if (!(INSTALLER_NAME[__i] in UNINSTALLER)) {
      complain("Found " INSTALLER_NAME[__i] ".installer.sh but no matching " INSTALLER_NAME[__i] ".uninstaller.sh")
    }
  }
  for (__i = 1; __i <= UNINSTALLERS; __i++) {
    if (!(UNINSTALLER_NAME[__i] in INSTALLER)) {
      complain("Found " UNINSTALLER_NAME[__i] ".uninstaller.sh but no matching " UNINSTALLER_NAME[__i] ".installer.sh")
    }
  }
}

BEGIN {
  PLUGINS = tree_ahead()
  ROOT = tree_open()
  COMPLAINTS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  for (plugin = NODE_FIRST[PLUGINS]; plugin != 0; plugin = NODE_NEXT[plugin]) {
    HAS_PLUGIN[text_of(plugin)] = 1
  }
  INSTALLERS = read_scripts(arg("installers"), ".installer.sh", INSTALLER, INSTALLER_NAME)
  UNINSTALLERS = read_scripts(arg("uninstallers"), ".uninstaller.sh", UNINSTALLER, UNINSTALLER_NAME)

  print_open(0, wrap("resolver"), "map")
  print_resolver(ROOT, 1)
  print_open(0, wrap("errors"), "list")
  complain_of_missing()
  complain_of_unpaired()
}

{ main($0) }
