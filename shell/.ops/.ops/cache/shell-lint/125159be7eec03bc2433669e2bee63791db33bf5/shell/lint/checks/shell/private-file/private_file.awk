# A private file's name begins with _. Loaded with the scanner runtime and
# the prefix library:
#
#   awk -v root=<repository root> -f scan.awk -f name_prefix.awk -f private_file.awk
#
# A library file that is imported, and only by a file in its own directory,
# is private to its module (ADR 000039's fragment). Its name begins with _.
# A file nothing imports is not judged: it has not been shown to be private.
# A plugin, a template and an entrypoint are not library files. An import
# inside a comment or a heredoc is prose. A file carrying
# `# private-file-check: allow` is left alone.
#
# The verdict waits until every file has been read, because an importer may
# be a later file. Only the files given are read, so an importer outside
# them is seen in the full sweep alone.
#
# Output: "<name>:<lineno>: <message>", the line being 1. Vars: -v root=<dir>
# keys a file under the repository root; -v fname=<display name> (default
# FILENAME).

# The directory KEY sits in: `lib/testing/trace` for
# `lib/testing/trace/_tracer.sh`.
function dir_of(key, __dir) {
  __dir = key
  sub(/\/[^\/]*$/, "", __dir)
  return __dir
}

# The filename KEY ends in.
function base_of(key, __base) {
  __base = key
  sub(/^.*\//, "", __base)
  return __base
}

# True when KEY is a library file this check judges: under lib/ or
# interpreter/, and neither a plugin nor a template.
function is_judged(key) {
  if (module_prefix(key) == "") {
    return 0
  }
  if (key ~ /\.op\.sh$/) {
    return 0
  }
  return 1
}

# Records every library path LINE imports. One from another directory means
# the target is not private. RSTART and RLENGTH are copied out before the
# line advances: a match in a function called from here would reset them.
function record_imports(line, __start, __length, __target, __matched) {
  while (match(line, /\$(SHELLOPS_DIR|PROJ)\/[A-Za-z0-9_.\/-]+\.sh/)) {
    __start = RSTART
    __length = RLENGTH
    __matched = substr(line, __start, __length)
    __target = substr(__matched, index(__matched, "/") + 1)
    if (!under_library_root(__target)) {
      line = substr(line, __start + __length)
      continue
    }
    imported[__target] = 1
    if (dir_of(key) != dir_of(__target)) {
      outside[__target] = 1
    }
    line = substr(line, __start + __length)
  }
}

# Reports each private file whose name does not begin with _.
function report_private_files(__key, __base) {
  for (__key in seen) {
    if (!imported[__key] || allowed[__key] || outside[__key]) {
      continue
    }
    __base = base_of(__key)
    if (__base ~ /^_/) {
      continue
    }
    printf "%s:%d: %s\n", seen_name[__key], 1, \
      "private file " __base " belongs to " dir_of(__key) "; its name begins with _"
  }
}

# Resets to the state a fresh file starts in.
function begin_file() {
  key = library_key(FILENAME)
  in_heredoc = 0
  if (!is_judged(key)) {
    return
  }
  seen[key] = 1
  seen_name[key] = display_name()
}

# Reads one line inside a heredoc: the closer ends it.
function read_heredoc(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
  }
}

# Reads one line of code: an allow mark exempts the file, and an import is
# recorded once the line is not a comment.
function read_line(line) {
  if (line ~ /private-file-check:[ \t]*allow/) {
    allowed[key] = 1
  }
  if (is_comment(line)) {
    return
  }
  record_imports(line)
  if (opens_heredoc(line)) {
    in_heredoc = 1
  }
}

FNR == 1 {
  begin_file()
}

{
  if (in_heredoc) {
    read_heredoc($0)
  } else {
    read_line($0)
  }
}

END {
  report_private_files()
}
