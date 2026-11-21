# The OPX document on stdin as a YAML document in block style. Loaded after
# the structs JSON runtime, lines.awk, mapping.awk, read_tree.awk and
# yaml/scalars.awk and yaml/serialize.awk.
#
#   xK_mQ 0.value
#   Lp3qR 1.a
#   d1E02 2.item:int.1        ->  a:
#   nS01_ 2.item:string."x"         - 1
#                                   - x

{
  opx_read_line($0)
}

END {
  yaml_write_doc(opx_read_root())
}
