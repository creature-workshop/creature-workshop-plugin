# The module path a library file's names begin with. Loaded ahead of a check
# that judges names:
#
#   awk -v root=<repository root> -f scan.awk -f name_prefix.awk -f <check>.awk
#
# The path is the directories under a library root joined by __; a file
# sitting in the root itself takes its path from its own name, and
# interpreter/ is one module. library_root.awk names the roots and keys a
# path, and is loaded ahead of this file.
# A private name begins with __ and then that path; a public name begins
# with the path alone. The import barrel's stem is one constant here, and a
# function's variables take the path and then the function's own name.

# The stem of a module's import barrel, the file that is the module and so
# never a segment of a name.
function barrel_stem() {
  return "api"
}

# The private-name prefix KEY's module binds under, or nothing when KEY is
# not a library file. A template for an entrypoint, a fixture beside its
# module and a single-function .func.sh file, which is its one function, are
# not library files.
function module_prefix(key, __rest, __dir, __base) {
  if (!under_library_root(key) || key !~ /\.sh$/) {
    return ""
  }
  if (key ~ /\.(template|fixture|func)\.sh$/) {
    return ""
  }
  if (key ~ /^interpreter\//) {
    return "__interpreter__"
  }
  __rest = without_library_root(key)
  if (__rest !~ /\//) {
    __base = __rest
    sub("\\." barrel_stem() "\\.sh$", "", __base)
    sub(/\.op\.sh$/, "", __base)
    sub(/\.sh$/, "", __base)
    gsub(/-/, "_", __base)
    return "__" __base "__"
  }
  __dir = __rest
  sub(/\/[^\/]+$/, "", __dir)
  gsub(/-/, "_", __dir)
  gsub(/\//, "__", __dir)
  return "__" __dir "__"
}

# The public-name prefix KEY's module binds under: the private prefix with
# its leading __ dropped, or nothing when the file has no module path.
function public_prefix(key, __private) {
  __private = module_prefix(key)
  if (__private == "") {
    return ""
  }
  return substr(__private, 3)
}

# The prefix the variables of the function FN begin with under the module
# prefix MODULE: the module path, then the function's own name. The own name
# drops a leading __, then the module's spelling, formal (bump__) or
# informal (bump_, testing_scorecard_), then the barrel's stem.
#
#     variable_prefix("bump__plan_bump", "__bump__")               ->  __bump__plan_bump__
#     variable_prefix("bump_plan", "__bump__")               ->  __bump__plan__
#     variable_prefix("__bump_api__tag_exists", "__bump__")  ->  __bump__tag_exists__
#     variable_prefix("@map", "__structs__")                 ->  __structs__map__
function variable_prefix(fn, module, __own, __public, __informal, __last, __count, __parts) {
  __own = fn
  gsub(/[^A-Za-z0-9_]/, "_", __own)
  sub(/^_+/, "", __own)
  __public = substr(module, 3)
  __informal = __public
  gsub(/__/, "_", __informal)
  __count = split(__public, __parts, "__")
  __last = __parts[__count - 1] "_"
  if (index(__own, __public) == 1) {
    __own = substr(__own, length(__public) + 1)
  } else if (index(__own, __informal "_") == 1) {
    __own = substr(__own, length(__informal) + 2)
  } else if (index(__own, __informal) == 1) {
    __own = substr(__own, length(__informal) + 1)
  } else if (index(__own, __last "_") == 1) {
    __own = substr(__own, length(__last) + 2)
  } else if (index(__own, __last) == 1) {
    __own = substr(__own, length(__last) + 1)
  }
  if (index(__own, barrel_stem() "__") == 1) {
    __own = substr(__own, length(barrel_stem()) + 3)
  }
  return module __own "__"
}
