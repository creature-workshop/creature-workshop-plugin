# Escape every character that means something in a POSIX extended regular
# expression, so the text matches itself and nothing else.
s/[][\\.|*+?(){}^$]/\\&/g
