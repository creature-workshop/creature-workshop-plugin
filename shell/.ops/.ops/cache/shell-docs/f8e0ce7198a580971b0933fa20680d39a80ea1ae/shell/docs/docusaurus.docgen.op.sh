#!/usr/bin/env bash

: <<'DOC'
Docusaurus, the first docs system of the docgen kind (docgen.sh says what
the roles mean): one markdown page per module at the module's path with
.sh as .md, and the index at README.md, which Docusaurus takes as the
landing page of the folder its sidebar is generated from. A page and the
index are rendered by the two jq programs under docusaurus/, which read
the tree and nothing else.
DOC

# CONST: The page renderer, a jq program over one module's tree.
__docs__docusaurus__PAGE="$SHELL_DOCS_DIR/shell/docs/docusaurus/page.jq"

# CONST: The index renderer, a jq program over the trees of every module.
__docs__docusaurus__INDEX="$SHELL_DOCS_DIR/shell/docs/docusaurus/index.jq"

@docgen.docusaurus() {
  @summary() {
    println "Markdown pages for a Docusaurus docs instance, one per module, with a README index as the landing page."
  }

  @needs() {
    @arr jq
  }

  @page() {
    # structs-lint: allow -- the renderer is a jq program over a tree file; no struct value is read
    jq -r -f "$__docs__docusaurus__PAGE" "$1"
  }

  @index() {
    # structs-lint: allow -- the renderer is a jq program over tree files; no struct value is read
    jq -r -s -f "$__docs__docusaurus__INDEX" "$@"
  }

  @page_path() {
    println "${1%.sh}.md"
  }

  @index_path() {
    println "README.md"
  }
}
