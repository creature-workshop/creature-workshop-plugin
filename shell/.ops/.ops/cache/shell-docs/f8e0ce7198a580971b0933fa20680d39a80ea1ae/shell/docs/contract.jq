# The contract pass: shell-tree's tree of a source in, the reference's tree
# out, the module node whose members carry a doc and a contract. Run with
# -c, so the document is one line as the lowering writes it:
#
#   awk ... -f scan.awk -f tree.awk <module> | jq -c -f contract.jq
#
# This is where the house conventions are read. A `PUB_` label makes a
# member public and FUN, CONST or VAR private; a member with no label is
# public unless its name starts with `__`. MODULE or FRAGMENT on the
# source's doc is the module's reach. An assignment gets a node only when
# it carries a doc, as a constant when the last `__` segment of its name is
# upper case and as a variable otherwise. A doc's `args:` section, one
# parameter per line and a deeper-indented line continuing the meaning
# above it, up to a blank line or the next section heading, fills the
# contract's args.
#
# Input: the source node shell-tree writes.

# The payload entries of a node with the role $role.
def entries($role):
  [.payload[] | select(.role == $role)];

# The one payload entry with the role $role, or null.
def entry($role):
  entries($role) | first;

# True when a name is a constant's: its last `__` segment is upper case.
def constant_name:
  split("__") | last | test("^[A-Z][A-Z0-9_]*$");

# The visibility a label states, or null when it states none.
def label_visibility:
  if startswith("PUB_") then "public"
  elif . == "FUN" or . == "CONST" or . == "VAR" then "private"
  else null end;

# The visibility a name states on its own: private under a leading `__`.
def name_visibility:
  if startswith("__") then "private" else "public" end;

# The visibility of the member $name with the doc $doc: the label's when it
# states one, else the name's.
def visibility_of($name; $doc):
  (if $doc == null then null else ($doc.name | label_visibility) end)
  // ($name | name_visibility);

# True when a doc line heads a labelled reference section.
def section_heading:
  test("^[ \t]*(Usage|Flags|Parameters|Params|Returns|Options|Vars|Example|Examples|Args|Arguments|Environment|Subcommands)([^A-Za-z]|$)");

# True when a doc line heads the args section.
def args_heading:
  test("^[ \t]*([Aa]rgs|[Aa]rguments):[ \t]*$");

# True when a doc line has no non-whitespace content.
def blank:
  test("[^ \t]") | not;

# True when a doc line names a parameter: a positional or special parameter,
# an angle-bracketed name, or a flag, followed by its meaning.
def arg_line:
  test("^[ \t]*(\\$[0-9@#*]+(\\.\\.)?|<[^>]+>|--?[A-Za-z][A-Za-z0-9_-]*)[ \t]+[^ \t]");

# The width of a line's leading whitespace.
def indent_width:
  match("^[ \t]*") | .length;

# The parameter an arg line names.
def arg_name:
  sub("^[ \t]*"; "") | sub("[ \t].*$"; "");

# The meaning an arg line gives, after the parameter and the gap.
def arg_meaning:
  sub("^[ \t]*[^ \t]+[ \t]+"; "");

# A line without its leading whitespace.
def trimmed:
  sub("^[ \t]*"; "");

# The arg node for the parameter $name with $meaning.
def arg($name; $meaning):
  {role: "arg", name: $name, payload: [{role: "meaning", payload: $meaning}]};

# The state after one line of the args section: the arg it names opens a
# new entry, a deeper-indented line continues the last, and a blank line or
# a heading ends the section.
def read_args_line($line):
  if .done then .
  elif (.in | not) then (if ($line | args_heading) then .in = true else . end)
  elif ($line | blank) or ($line | section_heading) then .done = true
  elif ($line | arg_line) then
    (if .name != null then .items += [arg(.name; .meaning)] else . end)
    | .name = ($line | arg_name)
    | .meaning = ($line | arg_meaning)
    | .width = ($line | indent_width)
  elif .name != null and ($line | indent_width) > .width then
    .meaning = .meaning + " " + ($line | trimmed)
  else . end;

# The args of a doc's text, as [arg], empty without an args section.
def args_of($text):
  reduce ($text | split("\n"))[] as $line
    ({in: false, done: false, items: [], name: null, meaning: null, width: 0}; read_args_line($line))
  | (if .name != null then .items += [arg(.name; .meaning)] else . end)
  | .items;

# The contract of the member $name with the doc $doc: its visibility, then
# its args when the doc has any.
def contract($name; $doc):
  {role: "contract", payload:
    ([{role: "visibility", payload: visibility_of($name; $doc)}]
     + (if $doc == null then [] else (args_of($doc.payload) as $args | if $args == [] then [] else [{role: "args", payload: $args}] end) end))};

# The doc leaf of a member, or nothing when it has none.
def doc_leaf($doc):
  if $doc == null then [] else [{role: "doc", payload: $doc.payload}] end;

# A member of the reference's tree from a definition of the source's: a
# function always, an assignment when documented.
def member:
  entry("doc") as $doc
  | (entry("line") | .payload) as $line
  | if .role == "function" then
      {role: "function", name: .name, payload: ([{role: "line", payload: $line}] + doc_leaf($doc) + [contract(.name; $doc)])}
    elif .role == "assignment" and $doc != null then
      {role: (if (.name | constant_name) then "constant" else "variable" end), name: .name,
       payload: ([{role: "line", payload: $line}] + doc_leaf($doc) + [contract(.name; $doc)])}
    else empty end;

# The module's reach and doc from the source's doc, when its label is one
# of the two a file doc opens on.
def header:
  entry("doc") as $doc
  | if $doc != null and ($doc.name == "MODULE" or $doc.name == "FRAGMENT")
    then [{role: "reach", payload: ($doc.name | ascii_downcase)}, {role: "doc", payload: $doc.payload}]
    else [] end;

{role: "module", name: .name,
 payload: ([{role: "path", payload: .name}] + header + [.payload[] | select(.role == "function" or .role == "assignment") | member])}
