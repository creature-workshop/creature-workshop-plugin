# Prints the tools a resolver's registry names, by channel: the map
# .ops/lock keeps under dependencies.tools. Each entry loses the channel it
# was filed under, which becomes its key. It also loses what is a fact
# about one checkout and not about the tool: the directory the declaration
# was read from, and the installer and uninstaller scripts the resolver
# found for it, which it finds again from the plugins on every run. The git
# channel is kept like every other.
#
# Input: the registry, a map of tool to entry.

function main(line) {
  tree_line(line)
}

# Notes the channels in the order the registry first names them.
function note_channels(__tool, __channel) {
  CHANNELS = 0

  for (__tool = NODE_FIRST[ROOT]; __tool != 0; __tool = NODE_NEXT[__tool]) {
    __channel = text_of(member(__tool, "channel"))
    if (!(__channel in CHANNEL_SEEN)) {
      CHANNEL_SEEN[__channel] = 1
      CHANNELS++
      CHANNEL[CHANNELS] = __channel
    }
  }
}

# Prints the tools of one channel, each without the fields the lock does
# not keep.
function print_channel(channel, __tool, __field) {
  print_open(0, wrap(channel), "map")

  for (__tool = NODE_FIRST[ROOT]; __tool != 0; __tool = NODE_NEXT[__tool]) {
    if (text_of(member(__tool, "channel")) != channel) {
      continue
    }

    print_open(1, NODE_KEY[__tool], "map")
    for (__field = NODE_FIRST[__tool]; __field != 0; __field = NODE_NEXT[__field]) {
      if (NODE_KEY[__field] !~ /^"(channel|origin_dir|installer_path|uninstaller_path)"$/) {
        print_node(__field, 2, NODE_KEY[__field])
      }
    }
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_channels()
  for (i = 1; i <= CHANNELS; i++) {
    print_channel(CHANNEL[i])
  }

  if (CHANNELS == 0) {
    print "0.:map"
  }
}

{ main($0) }
