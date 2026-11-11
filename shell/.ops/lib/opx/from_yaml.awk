# The YAML document on stdin as an OPX document. Loaded after the structs
# JSON runtime, the files under yaml/ that read a document, emit.awk,
# mapping.awk and write_tree.awk.
#
#   -v root=<role>   the root node's role ("value" when not given)
#
#   a:            ->  xK_mQ 0.value
#     - 1             Lp3qR 1.a
#     - x             d1E02 2.item:int.1
#                     nS01_ 2.item:string."x"

{
  yaml_keep_line($0)
}

END {
  if (FAILED) {
    exit 3
  }
  opx_write_tree(yaml_doc(), root)
}
