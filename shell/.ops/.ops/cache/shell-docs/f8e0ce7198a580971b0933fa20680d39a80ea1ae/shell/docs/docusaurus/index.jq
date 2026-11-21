# The reference's index page: every module's tree, given as one array, as a
# raw markdown table (run with -r) linking each module's page, with its
# reach and the first line of its doc.
#
# Input: an array of module nodes, in the order the pages are listed.

# The one payload entry with the role $role, or null.
def entry($role):
  [.payload[] | select(.role == $role)] | first;

# The first line of a module's doc, or a note when it has none.
def summary:
  entry("doc") | if . == null then "*Undocumented.*" else .payload | split("\n") | first end;

# A module's reach, or a dash when its doc states none.
def reach:
  entry("reach") | if . == null then "-" else .payload end;

# The page a module's tree renders to, relative to the index.
def page:
  "\(.name | sub("\\.sh$"; "")).md";

# One module's row.
def row:
  "| [`\(.name)`](\(page)) | \(reach) | \(summary) |";

"# Reference",
"",
"One page per library module, rendered from its tree.",
"",
"| Module | Reach | Summary |",
"| --- | --- | --- |",
(.[] | row)
