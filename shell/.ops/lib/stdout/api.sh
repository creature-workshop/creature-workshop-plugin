#!/bin/sh

: <<'MODULE'
Printing to stdout, which is every function's return channel. A process
loads this file as its vocabulary, so the name is bare: println. The
reporting verbs, which write to stderr, come from shell-logs at shell/.logs.
MODULE

: <<'PUB_FUN'
Prints each argument as its own line. With no argument it prints an empty
line.

    println ready    ->  ready
    println one two  ->  one
                         two
PUB_FUN
println() {  # public-name-check: allow -- .envrc loads println into every process as its vocabulary
  printf '%s\n' "$@"  # println-check: allow -- the verb is the spelling this line defines
}
