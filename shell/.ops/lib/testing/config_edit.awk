# Prints what kind of edit a testing config took between the base and the
# head of a review. An edit is additive when it only adds areas, tests or
# suites, or drops tests from an area. It is remapping when it changes
# what an area or a suite that the base has selects. Loaded after
# tree_equal.awk and testing.awk.
#
# An additive edit cannot change what an area of the base selects, so the
# review's labels still say which tests to run. A remapped area is
# selected as if the review had touched it. The paths of a removed area
# are selected through the head's areas that cover them. A changed suite
# or setting may send any file somewhere else, and so may a removed
# area's path that no area of the head covers, so only the full suite
# covers those. The edit names every remapping, and says how far it
# reaches: no further for an additive edit, the areas in widen_to when
# every remapping is of an area and every path of a removed area has an
# area at the head, and the full suite otherwise.
#
# Input: {base: {config, areas}, head: {config, areas}}: each side's
#        config (from areas__load_areas_config) with its flat area map
#        (from areas__compute_areas).
#
#   {kind: "additive", added_areas: ["lib.beta"], remapped: [], scope: "none", widen_to: []}
#   {kind: "remapping", added_areas: [], remapped: ["area lib.alpha remapped"], scope: "areas", widen_to: ["lib.alpha"]}
#   {kind: "remapping", added_areas: [], remapped: ["suite unit changed"], scope: "full", widen_to: []}

function main(line) {
  tree_line(line)
}

# Fills names with the names of the members of a map, in byte order.
# Returns how many there are.
function sorted_names(map, names, __member, __count) {
  __count = 0
  for (__member = NODE_FIRST[map]; __member != 0; __member = NODE_NEXT[__member]) {
    names[++__count] = name_of(__member)
  }

  sort_texts(names, __count)
  return __count
}

# Whether an area at the head no longer selects what it selected at the
# base: its paths or its full_suite mark changed, or it became inert.
function is_remapped(base, head) {
  return !same_value(member(base, "paths"), member(head, "paths")) \
    || !same_value(member(base, "full_suite"), member(head, "full_suite")) \
    || (!is_truthy(member(base, "inert")) && is_truthy(member(head, "inert")))
}

# Sorts the areas of the base into REMOVED and REMAPPED, in byte order,
# and notes the head's areas that the base does not have in ADDED.
function read_areas(__names, __count, __i, __base, __head) {
  __count = sorted_names(BASE_AREAS, __names)
  for (__i = 1; __i <= __count; __i++) {
    __base = member(BASE_AREAS, __names[__i])
    __head = member(HEAD_AREAS, __names[__i])

    if (!is_present(__head)) {
      REMOVED[++REMOVEDS] = __names[__i]
    } else if (is_remapped(__base, __head)) {
      REMAPPED[++REMAPPEDS] = __names[__i]
    }
  }

  __count = sorted_names(HEAD_AREAS, __names)
  for (__i = 1; __i <= __count; __i++) {
    if (!is_present(member(BASE_AREAS, __names[__i]))) {
      ADDED[++ADDEDS] = __names[__i]
    }
  }
}

# Notes the suites of the base that are gone or different at the head, in
# byte order. A suite that only the head has is additive.
function read_suites(__base, __head, __names, __count, __i) {
  __base = member(member(member(ROOT, "base"), "config"), "suites")
  __head = member(member(member(ROOT, "head"), "config"), "suites")

  __count = sorted_names(__base, __names)
  for (__i = 1; __i <= __count; __i++) {
    if (!same_value(member(__base, __names[__i]), member(__head, __names[__i]))) {
      CHANGED_SUITE[++CHANGED_SUITES] = __names[__i]
    }
  }
}

# Whether the settings changed: everything in the config that is not the
# areas, the suites or the coverage gate, which selection does not read.
# A side with no config differs from a side with one.
function settings_changed(__base, __head) {
  __base = member(member(ROOT, "base"), "config")
  __head = member(member(ROOT, "head"), "config")
  if (is_present(__base) != is_present(__head)) {
    return 1
  }

  return !same_settings(__base, __head) || !same_settings(__head, __base)
}

# Whether every setting of one config is in another with the same value.
function same_settings(config, other, __setting) {
  for (__setting = NODE_FIRST[config]; __setting != 0; __setting = NODE_NEXT[__setting]) {
    if (is_setting(name_of(__setting)) && !same_setting(__setting, other)) {
      return 0
    }
  }

  return 1
}

# Whether a member of a config is a setting.
function is_setting(name) {
  return name != "areas" && name != "suites" && name != "coverage"
}

# Whether a config has a setting, with the same value. A setting that is
# a null is not the same as one that is missing.
function same_setting(setting, config, __other) {
  __other = child(config, NODE_KEY[setting])

  return __other != 0 && same_value(setting, __other)
}

# Reads the area of the head that covers each path of each removed area,
# by the longest path that covers it, into CLAIMANT. Returns whether
# every such path has one.
function read_claimants(__i, __path, __every) {
  __every = 1

  for (__i = 1; __i <= REMOVEDS; __i++) {
    for (__path = NODE_FIRST[member(member(BASE_AREAS, REMOVED[__i]), "paths")]; __path != 0; __path = NODE_NEXT[__path]) {
      if (source_area(HEAD_AREAS, text_of(__path))) {
        CLAIMANT[++CLAIMANTS] = SOURCE_AREA
      } else {
        __every = 0
      }
    }
  }

  return __every
}

# Prints the names of the areas that only the head has.
function print_added() {
  print_open(0, wrap("added_areas"), "list")
  print_texts(ADDED, ADDEDS, 0)
}

# Prints every remapping by name: the removed areas, the remapped areas,
# the changed suites and the changed settings.
function print_remapped(__lines, __count, __i) {
  __count = 0
  for (__i = 1; __i <= REMOVEDS; __i++) {
    __lines[++__count] = "area " REMOVED[__i] " removed"
  }
  for (__i = 1; __i <= REMAPPEDS; __i++) {
    __lines[++__count] = "area " REMAPPED[__i] " remapped"
  }
  for (__i = 1; __i <= CHANGED_SUITES; __i++) {
    __lines[++__count] = "suite " CHANGED_SUITE[__i] " changed"
  }
  if (SETTINGS_CHANGED) {
    __lines[++__count] = "settings changed"
  }

  print_open(0, wrap("remapped"), "list")
  print_texts(__lines, __count, 0)
}

# Prints how far the edit reaches: its scope, and the areas to widen to
# when the scope is areas, in byte order with each once.
function print_reach(__every_claimed, __areas, __count, __i) {
  __every_claimed = read_claimants()
  __count = 0

  if (REMOVEDS + REMAPPEDS + CHANGED_SUITES + SETTINGS_CHANGED == 0) {
    print_str(0, "scope", "none")
  } else if (CHANGED_SUITES + SETTINGS_CHANGED > 0 || !__every_claimed) {
    print_str(0, "scope", "full")
  } else {
    print_str(0, "scope", "areas")
    for (__i = 1; __i <= REMAPPEDS; __i++) {
      __areas[++__count] = REMAPPED[__i]
    }
    for (__i = 1; __i <= CLAIMANTS; __i++) {
      __areas[++__count] = CLAIMANT[__i]
    }
  }

  print_open(0, wrap("widen_to"), "list")
  print_texts(__areas, unique_texts(__areas, __count), 0)
}

BEGIN {
  ROOT = tree_open()
  REMOVEDS = 0
  REMAPPEDS = 0
  ADDEDS = 0
  CHANGED_SUITES = 0
  CLAIMANTS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  BASE_AREAS = member(member(ROOT, "base"), "areas")
  HEAD_AREAS = member(member(ROOT, "head"), "areas")
  read_areas()
  read_suites()
  SETTINGS_CHANGED = settings_changed()

  print_str(0, "kind", (REMOVEDS + REMAPPEDS + CHANGED_SUITES + SETTINGS_CHANGED == 0) ? "additive" : "remapping")
  print_added()
  print_remapped()
  print_reach()
}

{ main($0) }
