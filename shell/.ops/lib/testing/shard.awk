# Print the lines that one shard takes when the input is dealt round-robin
# to `shards` shards: the shard numbered `shard` (counted from 1) takes the
# shard-th line, the (shard+shards)-th, and so on. Empty lines are skipped
# and not counted, so an empty input deals nothing.

function main(line) {
  if (line == "") {
    return
  }
  dealt = dealt + 1
  if ((dealt - 1) % shards == shard - 1) {
    print line
  }
}

{ main($0) }
