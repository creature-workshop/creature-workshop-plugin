# The OPX document on stdin as one compact line of JSON. Loaded after the
# structs JSON runtime, lines.awk, mapping.awk and read_tree.awk.
#
#   xK_mQ 0.value
#   Lp3qR 1.a
#   d1E02 2.item:int.1
#   nS01_ 2.item:string."x"   ->  {"a":[1,"x"]}

{
  opx_read_line($0)
}

END {
  print json_serialize(opx_read_root())
}
