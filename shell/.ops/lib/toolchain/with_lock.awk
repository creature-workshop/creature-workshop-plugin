# Prints the resolver with the tools a lock names laid onto its registry.
# Each entry is the lock's own fields for that tool, with the channel it
# was listed under and the directory the lock is in. A tool the registry
# already has takes the lock's entry whole, in its place. Loaded after
# resolver.awk.
#
# Input: the resolver, and ahead of it, with --with, the lock: a map of
#        channel to a map of tool to entry.
# Argument "origin_dir": the directory the lock is in.

function main(line) {
  tree_line(line)
}

# Notes every tool the lock names, with the channel that lists it. A tool
# two channels list has the entry of the later one, in the place of the
# first.
function note_lock(__channel, __tool, __name) {
  LOCKED = 0

  for (__channel = NODE_FIRST[LOCK]; __channel != 0; __channel = NODE_NEXT[__channel]) {
    for (__tool = NODE_FIRST[__channel]; __tool != 0; __tool = NODE_NEXT[__tool]) {
      __name = name_of(__tool)
      if (!(__name in LOCK_ENTRY)) {
        LOCKED++
        LOCK_NAME[LOCKED] = __name
      }
      LOCK_ENTRY[__name] = __tool
      LOCK_CHANNEL[__name] = name_of(__channel)
    }
  }
}

# Prints the registry: its tools, each replaced by the lock's entry when
# the lock names it, and then the tools only the lock names.
function print_registry(depth, __tool, __i) {
  print_open(depth, wrap("registry"), "map")

  for (__tool = NODE_FIRST[member(ROOT, "registry")]; __tool != 0; __tool = NODE_NEXT[__tool]) {
    if (name_of(__tool) in LOCK_ENTRY) {
      print_lock_entry(name_of(__tool), depth + 1)
      PRINTED[name_of(__tool)] = 1
    } else {
      print_node(__tool, depth + 1, NODE_KEY[__tool])
    }
  }

  for (__i = 1; __i <= LOCKED; __i++) {
    if (!(LOCK_NAME[__i] in PRINTED)) {
      print_lock_entry(LOCK_NAME[__i], depth + 1)
    }
  }
}

# Prints the lock's entry for a tool with its channel and the lock's
# directory: each where the entry has the field, and after its other fields
# when it has none.
function print_lock_entry(name, depth, __field, __has_channel, __has_origin) {
  print_open(depth, wrap(name), "map")
  __has_channel = 0
  __has_origin = 0

  for (__field = NODE_FIRST[LOCK_ENTRY[name]]; __field != 0; __field = NODE_NEXT[__field]) {
    if (NODE_KEY[__field] == wrap("channel")) {
      print_str(depth + 1, "channel", LOCK_CHANNEL[name])
      __has_channel = 1
    } else if (NODE_KEY[__field] == wrap("origin_dir")) {
      print_str(depth + 1, "origin_dir", arg("origin_dir"))
      __has_origin = 1
    } else {
      print_node(__field, depth + 1, NODE_KEY[__field])
    }
  }

  if (!__has_channel) {
    print_str(depth + 1, "channel", LOCK_CHANNEL[name])
  }
  if (!__has_origin) {
    print_str(depth + 1, "origin_dir", arg("origin_dir"))
  }
}

BEGIN {
  LOCK = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_lock()
  print_resolver(ROOT, 0)
}

{ main($0) }
