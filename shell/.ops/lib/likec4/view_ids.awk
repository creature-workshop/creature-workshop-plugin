# Prints the id of every view a LikeC4 source declares, one per line.
#
#     view f1a {   ->  f1a

$1 == "view" { print $2 }
