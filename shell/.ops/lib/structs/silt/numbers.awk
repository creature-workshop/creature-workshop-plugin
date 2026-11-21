# Numbers the way a SILT line writes them, for a program that prints a
# number it computed. It holds functions alone.

# A number the way a line writes it after its key: an int when it is
# whole, and a float otherwise.
#
#   number_written(3)    ->  int=3
#   number_written(2.5)  ->  float=2.5
function number_written(number) {
  if (number == int(number)) {
    return "int=" sprintf("%d", number)
  }

  return "float=" sprintf("%.17g", number)
}
