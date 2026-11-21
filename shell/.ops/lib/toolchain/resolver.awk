# Printing a resolver with its registry changed, for the programs of this
# module that rewrite one. It holds functions alone. A program defines
# print_registry(depth), which prints the line that opens the registry at
# that depth and the tools under it. Loaded after tree.awk.

# Prints a resolver as members at a depth, with its registry as the
# program prints it: every other member as it is, the registry where the
# resolver has it, and at the end when it has none. The program defines
# print_registry(depth), which prints the line that opens the registry at
# that depth and the tools under it.
function print_resolver(resolver, depth, __member, __printed) {
  __printed = 0

  for (__member = NODE_FIRST[resolver]; __member != 0; __member = NODE_NEXT[__member]) {
    if (NODE_KEY[__member] == wrap("registry")) {
      print_registry(depth)
      __printed = 1
    } else {
      print_node(__member, depth, NODE_KEY[__member])
    }
  }

  if (!__printed) {
    print_registry(depth)
  }
}
