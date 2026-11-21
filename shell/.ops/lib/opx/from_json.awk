# The JSON document on stdin as an OPX document. Loaded after the structs
# JSON runtime, emit.awk, mapping.awk and write_tree.awk.
#
#   -v root=<role>   the root node's role ("value" when not given)
#
#   {"a":[1,"x"]}  ->  xK_mQ 0.value
#                      Lp3qR 1.a
#                      d1E02 2.item:int.1
#                      nS01_ 2.item:string."x"

{ J_BUF = J_BUF $0 "\n" }

END {
  opx_write_tree(json_doc(), root)
}
