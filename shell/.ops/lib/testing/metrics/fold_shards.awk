# Prints the records with the shards of each sharded run folded into one
# record.
#
# A run that ran as several parallel jobs left one record for each job.
# Each of those names its shard and the pipeline that the jobs share. A
# reader wants the run, not its parts: one record whose suite rows cover
# the tests of every shard, whose counts are the sums of the shards'
# counts, and whose duration is that of the longest shard, because the
# shards ran side by side. The folded record takes the place of the run's
# first shard, and a record that is not a shard is printed as it is.
# Loaded after tree_edit.awk, numbers.awk and testing.awk.
#
# Input: the records, a list, oldest first.

function main(line) {
  tree_line(line)
}

# Notes the pipeline of every record that is one shard of a run, in
# PIPELINE_OF, as a line writes it. A record is a shard when it names its
# shard and its pipeline. Folding changes records, so this is read first.
function note_shards(__record, __run) {
  for (__record = NODE_FIRST[ROOT]; __record != 0; __record = NODE_NEXT[__record]) {
    __run = member(__record, "run")
    if (is_present(member(__run, "shard")) && is_present(member(__run, "pipeline"))) {
      PIPELINE_OF[__record] = written(member(__run, "pipeline"))
    }
  }
}

# Reads the shards of one pipeline into SHARD[1..SHARDS], in the order of
# their index, and their run and selection into RUN and SELECTION.
function read_shards(pipeline, __record, __i) {
  SHARDS = 0

  for (__record = NODE_FIRST[ROOT]; __record != 0; __record = NODE_NEXT[__record]) {
    if ((__record in PIPELINE_OF) && PIPELINE_OF[__record] == pipeline) {
      insert_shard(__record)
    }
  }

  for (__i = 1; __i <= SHARDS; __i++) {
    RUN[__i] = member(SHARD[__i], "run")
    SELECTION[__i] = member(SHARD[__i], "selection")
  }
}

# Puts a shard among the shards read so far, after every one whose index
# is not greater than its own.
function insert_shard(record, __index, __i) {
  __index = text_or(member(member(member(record, "run"), "shard"), "index"), 0) + 0

  for (__i = SHARDS; __i >= 1 && SHARD_INDEX[__i] > __index; __i--) {
    SHARD[__i + 1] = SHARD[__i]
    SHARD_INDEX[__i + 1] = SHARD_INDEX[__i]
  }
  SHARD[__i + 1] = record
  SHARD_INDEX[__i + 1] = __index
  SHARDS++
}

# Whether any of the parts has a value under a name.
function any_has(parts, count, name, __i) {
  for (__i = 1; __i <= count; __i++) {
    if (is_present(member(parts[__i], name))) {
      return 1
    }
  }

  return 0
}

# The sum of a number over the parts that have it, as a line writes it,
# and null when no part has it.
function sum_over(parts, count, name, __i, __node, __sum, __measured) {
  __sum = 0
  __measured = 0

  for (__i = 1; __i <= count; __i++) {
    __node = member(parts[__i], name)
    if (is_present(__node)) {
      __sum += text_of(__node)
      __measured++
    }
  }

  return __measured ? number_written(__sum) : "null"
}

# The greatest of a number over the parts that have it, as a line writes
# it, and null when no part has it.
function greatest_over(parts, count, name, __i, __node, __greatest) {
  __greatest = 0

  for (__i = 1; __i <= count; __i++) {
    __node = member(parts[__i], name)
    if (is_present(__node) && (__greatest == 0 || text_of(__node) + 0 > text_of(__greatest) + 0)) {
      __greatest = __node
    }
  }

  return written(__greatest)
}

# The first in byte order of a text over the parts, as a line writes it,
# and null when a part does not have it.
function earliest_over(parts, count, name, __i, __node, __earliest) {
  __earliest = member(parts[1], name)

  for (__i = 1; __i <= count; __i++) {
    __node = member(parts[__i], name)
    if (!is_present(__node)) {
      return "null"
    }
    if ((text_of(__node) "") < (text_of(__earliest) "")) {
      __earliest = __node
    }
  }

  return written(__earliest)
}

# The status over the parts, as a line writes it: failed when any part
# failed, and passed otherwise.
function status_over(parts, count, __i) {
  for (__i = 1; __i <= count; __i++) {
    if (text_of(member(parts[__i], "status")) == "failed") {
      return "str=" wrap("failed")
    }
  }

  return "str=" wrap("passed")
}

# A new list of the texts that the parts list under a name, in byte order
# with each text once.
function union_over(parts, count, name, __i, __text, __texts, __found) {
  __found = 0

  for (__i = 1; __i <= count; __i++) {
    for (__text = NODE_FIRST[member(parts[__i], name)]; __text != 0; __text = NODE_NEXT[__text]) {
      __texts[++__found] = text_of(__text)
    }
  }

  return list_of_texts(__texts, unique_texts(__texts, __found))
}

# Folds the rows that the shards have for one suite into the first of
# them, and returns it.
function folded_row(rows, count) {
  put(rows[1], "selected", sum_over(rows, count, "selected"))
  put(rows[1], "total", greatest_over(rows, count, "total"))
  put(rows[1], "duration_seconds", greatest_over(rows, count, "duration_seconds"))
  put(rows[1], "status", status_over(rows, count))

  if (any_has(rows, count, "tests")) {
    put_node(rows[1], "tests", union_over(rows, count, "tests"))
  }
  if (any_has(rows, count, "flaky")) {
    put(rows[1], "flaky", sum_over(rows, count, "flaky"))
  }

  return rows[1]
}

# A new list of the suite rows of the shards read, one row for each suite,
# in the byte order of the suites' names.
function folded_suites(__rows, __count, __i, __suites, __group, __grouped) {
  __count = read_rows(__rows)
  __suites = new_node("", "list")
  __grouped = 0

  for (__i = 1; __i <= __count; __i++) {
    __group[++__grouped] = __rows[__i]
    if (__i == __count || suite_of(__rows[__i + 1]) != suite_of(__rows[__i])) {
      append_node(__suites, folded_row(__group, __grouped))
      __grouped = 0
    }
  }

  return __suites
}

# The name of the suite of a row.
function suite_of(row) {
  return text_of(member(row, "suite"))
}

# Fills rows with the suite rows of every shard read, in the byte order of
# their suites' names, the rows of one suite in the order of the shards.
# Returns how many there are.
function read_rows(rows, __i, __row, __count) {
  __count = 0

  for (__i = 1; __i <= SHARDS; __i++) {
    for (__row = NODE_FIRST[member(SHARD[__i], "suites")]; __row != 0; __row = NODE_NEXT[__row]) {
      insert_row(rows, __count++, __row)
    }
  }

  return __count
}

# Puts a row among the rows read so far, after every one whose suite's
# name is not after its own.
function insert_row(rows, count, row, __at) {
  for (__at = count; __at >= 1 && (suite_of(rows[__at]) "") > (suite_of(row) ""); __at--) {
    rows[__at + 1] = rows[__at]
  }
  rows[__at + 1] = row
}

# A new map of each selector that a shard names escapes for to those
# escapes over every shard, in byte order with each once. The selectors
# are in the order the shards first name them.
function folded_selector_escapes(__escapes, __folded, __i, __selector, __name) {
  __folded = new_node("", "map")

  for (__i = 1; __i <= SHARDS; __i++) {
    __escapes[__i] = member(SHARD[__i], "selector_escapes")
  }
  for (__i = 1; __i <= SHARDS; __i++) {
    for (__selector = NODE_FIRST[__escapes[__i]]; __selector != 0; __selector = NODE_NEXT[__selector]) {
      __name = name_of(__selector)
      if (member(__folded, __name) == 0) {
        put_node(__folded, __name, union_over(__escapes, SHARDS, __name))
      }
    }
  }

  return __folded
}

# Folds the shards of one pipeline into the first of them by index, and
# returns that record.
function folded_run(pipeline, __record, __suites, __selection) {
  read_shards(pipeline)
  __record = SHARD[1]
  __suites = folded_suites()
  __selection = map_under(__record, "selection")

  put(RUN[1], "started_at", earliest_over(RUN, SHARDS, "started_at"))
  put(RUN[1], "duration_seconds", greatest_over(RUN, SHARDS, "duration_seconds"))
  put(RUN[1], "status", status_over(RUN, SHARDS))
  put(__selection, "selected", sum_over(SELECTION, SHARDS, "selected"))
  put(__selection, "total", greatest_over(SELECTION, SHARDS, "total"))

  if (any_has(SHARD, SHARDS, "escapes")) {
    put_node(__record, "escapes", union_over(SHARD, SHARDS, "escapes"))
  }
  if (any_has(SHARD, SHARDS, "selector_escapes")) {
    put_node(__record, "selector_escapes", folded_selector_escapes())
  }
  put(RUN[1], "shard", "null")
  put_node(__record, "suites", __suites)

  return __record
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_shards()
  printed = 0
  for (record = NODE_FIRST[ROOT]; record != 0; record = NODE_NEXT[record]) {
    if (!(record in PIPELINE_OF)) {
      print_node(record, 0, printed++)
    } else if (!(PIPELINE_OF[record] in IS_FOLDED)) {
      IS_FOLDED[PIPELINE_OF[record]] = 1
      print_node(folded_run(PIPELINE_OF[record]), 0, printed++)
    }
  }

  if (printed == 0) {
    print "0.:list"
  }
}

{ main($0) }
