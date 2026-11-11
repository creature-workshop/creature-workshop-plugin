# Prints the rollout numbers that the scorecard reads, counted from the
# run records: how many runs narrowed and how many ran the full suite, how
# much the narrowed runs left out, what that saved against the cost of a
# full-suite run, the reason most runs gave, how many edits of the config
# still selected because they only added, how many tests flaked, and the
# clean streak that the phase gate reads. Loaded after numbers.awk and
# testing.awk.
#
# Input: the records, a list, oldest first.
#
# A narrowed run is one whose selection mode is "selected", and a
# full-suite run one whose mode is "full_suite". They are counted apart
# because they say different things: the narrowed runs say how much a
# selection leaves out, and the full-suite runs say what leaving nothing
# out costs. A number that no record measures is null, never 0.
#
# The escape check gives a run a verdict by putting its escapes on the
# record, none or some. A run with no verdict is neither clean nor an
# escape. The clean streak counts the runs that selection left something
# out of and that were judged clean since the last run with an escape. A
# full-suite run leaves nothing out, so it does not count and does not end
# the streak.

function main(line) {
  tree_line(line)
}

# Counts one record into every number of the rollout.
function count_record(record, __run, __selection, __mode, __duration, __escapes) {
  __run = member(record, "run")
  __selection = member(record, "selection")
  __mode = text_of(member(__selection, "mode"))
  __duration = member(__run, "duration_seconds")
  __escapes = member(record, "escapes")

  RUNS++
  REASON_RUNS[reason_of(__selection)]++
  FAILED_RUNS += (text_of(member(__run, "status")) == "failed")
  ADDITIVE_CONFIG_RUNS += (text_of(member(__selection, "config_edit")) == "additive")
  FLAKY_TESTS += flaky_tests(record)
  ESCAPES += NODE_COUNT[__escapes]
  if (is_present(__duration)) {
    SECONDS += text_of(__duration)
  }

  if (__mode == "selected") {
    count_narrowed(__selection, __duration)
  }
  if (__mode == "full_suite") {
    count_full(__duration)
  } else {
    count_verdict(__escapes)
  }
  if (NODE_COUNT[__escapes] > 0) {
    ESCAPE_RUNS++
    LAST_ESCAPE_AT = member(__run, "started_at")
    CLEAN_STREAK = 0
  }
}

# The reason a selection gives, and the word null when it gives none.
function reason_of(selection) {
  return text_or(member(selection, "reason"), "null")
}

# How many tests flaked over the suite rows of a record.
function flaky_tests(record, __row, __flaky) {
  __flaky = 0

  for (__row = NODE_FIRST[member(record, "suites")]; __row != 0; __row = NODE_NEXT[__row]) {
    __flaky += text_or(member(__row, "flaky"), 0)
  }

  return __flaky
}

# Counts a narrowed run: the tests it selected, the tests it could have
# selected, and its duration, for what it saved.
function count_narrowed(selection, duration) {
  SELECTED_RUNS++

  if (is_present(member(selection, "selected"))) {
    SELECTED_TESTS += text_of(member(selection, "selected"))
    SELECTED_MEASURED = 1
  }
  if (is_present(member(selection, "total"))) {
    SELECTABLE_TESTS += text_of(member(selection, "total"))
    SELECTABLE_MEASURED = 1
  }
  if (is_present(duration)) {
    NARROWED_SECONDS[++NARROWED_TIMED] = text_of(duration) + 0
  }
}

# Counts a full-suite run, and its duration toward the baseline.
function count_full(duration) {
  FULL_SUITE_RUNS++

  if (is_present(duration)) {
    FULL_SECONDS += text_of(duration)
    FULL_TIMED++
  }
}

# Counts the verdict of a run that selection left something out of: none,
# or clean. A run with an escape is counted by count_record.
function count_verdict(escapes) {
  if (escapes == 0) {
    UNVERDICTED_RUNS++
  } else if (NODE_COUNT[escapes] == 0) {
    CLEAN_STREAK++
  }
}

# Prints the reasons that the runs gave, each with how many runs gave it,
# in the byte order of the reasons, and then the reason most runs gave. Of
# two reasons that as many runs gave, the later in byte order is the top
# one, so the answer is the same on every run.
function print_reasons(__reason, __names, __count, __i, __top) {
  __count = 0
  for (__reason in REASON_RUNS) {
    __names[++__count] = __reason
  }
  sort_texts(__names, __count)

  print_open(0, wrap("reasons"), "map")
  __top = 0
  for (__i = 1; __i <= __count; __i++) {
    print "1." wrap(__names[__i]) ":int=" REASON_RUNS[__names[__i]]
    if (__top == 0 || REASON_RUNS[__names[__i]] >= REASON_RUNS[__names[__top]]) {
      __top = __i
    }
  }

  if (__top == 0) {
    print "0." wrap("top_reason") ":null"
    return
  }
  print_open(0, wrap("top_reason"), "map")
  print_str(1, "reason", __names[__top])
  print "1." wrap("runs") ":int=" REASON_RUNS[__names[__top]]
}

# Prints a number under a name, and a null when nothing measured it.
function print_measured(name, number, measured) {
  print "0." wrap(name) ":" (measured ? number_written(number) : "null")
}

# The share of the selectable tests that the narrowed runs selected, to
# four decimal places, as a line writes it, and null when it has no
# meaning.
function selection_ratio(__ratio) {
  if (!SELECTED_MEASURED || !SELECTABLE_MEASURED || SELECTABLE_TESTS == 0) {
    return "null"
  }

  __ratio = sprintf("%.4f", int(SELECTED_TESTS / SELECTABLE_TESTS * 10000 + 0.5) / 10000)
  sub(/\.?0+$/, "", __ratio)
  return ((__ratio ~ /\./) ? "float=" : "int=") __ratio
}

# The mean duration of a full-suite run, to the nearest second.
function baseline_seconds() {
  return int(FULL_SECONDS / FULL_TIMED + 0.5)
}

# The seconds that the narrowed runs did not spend, against the baseline.
# A narrowed run that took longer than the baseline saved nothing.
function seconds_saved(__i, __saved) {
  __saved = 0

  for (__i = 1; __i <= NARROWED_TIMED; __i++) {
    if (baseline_seconds() > NARROWED_SECONDS[__i]) {
      __saved += baseline_seconds() - NARROWED_SECONDS[__i]
    }
  }

  return __saved
}

BEGIN {
  ROOT = tree_open()
  LAST_ESCAPE_AT = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  for (record = NODE_FIRST[ROOT]; record != 0; record = NODE_NEXT[record]) {
    count_record(record)
  }

  print_measured("runs", RUNS, 1)
  print_measured("selected_runs", SELECTED_RUNS, 1)
  print_measured("full_suite_runs", FULL_SUITE_RUNS, 1)
  print_measured("failed_runs", FAILED_RUNS, 1)
  print_reasons()
  print_measured("additive_config_runs", ADDITIVE_CONFIG_RUNS, 1)
  print_measured("selected_tests", SELECTED_TESTS, SELECTED_MEASURED)
  print_measured("selectable_tests", SELECTABLE_TESTS, SELECTABLE_MEASURED)
  print "0." wrap("selection_ratio") ":" selection_ratio()
  print_measured("flaky_tests", FLAKY_TESTS, 1)
  print_measured("escapes", ESCAPES, 1)
  print_measured("escape_runs", ESCAPE_RUNS, 1)
  print_node(LAST_ESCAPE_AT, 0, wrap("last_escape_at"))
  print_measured("clean_streak", CLEAN_STREAK, 1)
  print_measured("unverdicted_runs", UNVERDICTED_RUNS, 1)
  print_measured("seconds", SECONDS, 1)
  print_measured("full_suite_baseline_seconds", FULL_TIMED ? baseline_seconds() : 0, FULL_TIMED)
  print_measured("seconds_saved", FULL_TIMED ? seconds_saved() : 0, FULL_TIMED)
}

{ main($0) }
