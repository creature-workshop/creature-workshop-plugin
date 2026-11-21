# shell-tree

The lowering of a shell source to a tree of its definitions: every function
and root assignment, with its line and the doc that sits above it, the
doc's label and its text as written. It reads the source through
[shell-scan](../shell-scan), the heredoc scanner, and knows no label name
and no naming convention. What a label means, and what a name says, is for
a reader of the tree to decide; [shell-docs](../shell-docs) is one, and
derives the reference's tree from this one.

`shell/tree/tree.awk` is the whole library, and its header states the
rules it reads by and the shape it writes:

    awk -v path=<the source's path> \
      -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
      -f "$SHELL_TREE_DIR/shell/tree/tree.awk" <source>

## The tree

| Node | Role | Name | Payload |
| --- | --- | --- | --- |
| The source | `source` | its path | the entries below, then one node per root definition, in file order |
| Its path | `path` | | the path, as given |
| Its doc | `doc` | the label | the text; the first doc block a blank line follows, met before any definition; absent without one |
| A function | `function` | the function's name | `line`, then `doc` when one sits above it |
| An assignment | `assignment` | the name bound | `line`, then `doc` when one sits above it |
| A definition's line | `line` | | the line number of the definition |
| A definition's doc | `doc` | the label | the text as written |

A doc is a doc block, the heredoc the no-op `:` consumes, whose label is
its terminator, or the one-line form, a run of `#` lines whose first leads
with `# WORD:`, whose label is that word. It attaches to the definition on
the line right after it; a `#` line between them does not part them, a
blank line does.

The tests lower one fixture per construct under `test/fixtures` and
compare the tree with the one recorded beside it.

A repository takes this library at a pin and exports `SHELL_TREE_DIR`, the
root of its copy. `shell/.scan` vendors
shell-scan and `shell/.ops` vendors shellops, for this repository's own
tests and lint, and for nothing else.

The work is tracked in Linear on the SILT project, from STRATA-233.
