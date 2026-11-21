"""A reading of a shell file that is just enough to find `$(@verb ...)` and
the statement around it.

The lexer walks the text once and records, for every character, how deep in
`$( )` it sits and whether it is code: outside a comment, a single-quoted
string, an ANSI-C quoted string and the body of a heredoc. It also lists
every `$(@verb` with the index of its matching `)`. A double-quoted string is
code, since a substitution expands inside it.
"""

from collections import namedtuple
from patterns import HEREDOC_OPENER, VERB_SUBSTITUTION

Lexed = namedtuple("Lexed", "depth code openers")

Opener = namedtuple("Opener", "start end verb")

OpenParen = namedtuple("OpenParen", "start is_substitution verb")

COMMENT_MAY_FOLLOW = " \t\n;("


def lex(text):
  """The depth and code of every character of text, and every `$(@verb ... )` in it as (start, end, verb), end exclusive."""

  return Lexer(text).run()


class Lexer:
  def __init__(self, text):
    self.text = text
    self.length = len(text)
    self.depth = [0] * self.length
    self.code = [True] * self.length
    self.openers = []
    self.open_parens = []
    self.quoted_before_paren = []
    self.in_double_quotes = False
    self.pending_heredocs = []
    self.position = 0

  def run(self):
    """Reads the whole text and returns what it found."""

    while self.position < self.length:
      self.depth[self.position] = self.substitution_depth()
      self.read_one()

    self.openers.sort()
    return Lexed(self.depth, self.code, self.openers)

  def substitution_depth(self):
    """How many `$(` are open at the current position."""

    return len([paren for paren in self.open_parens if paren.is_substitution])

  def read_one(self):
    """Reads the construct that starts at the current position, or one character: a switch on the character, each case its own reader."""

    match self.text[self.position]:
      case "\n":
        self.read_newline()
      case "#" if self.opens_comment():
        self.skip_comment()
      case "'" if self.opens_ansi_c_quote():
        self.skip_ansi_c_quoted()
      case "'" if not self.in_double_quotes:
        self.skip_single_quoted()
      case "\\":
        self.skip_escaped()
      case '"':
        self.toggle_double_quotes()
      case "`" if not self.in_double_quotes:
        self.skip_backticks()
      case "$" if self.text.startswith("$(", self.position):
        self.enter_substitution()
      case "(" if not self.in_double_quotes:
        self.enter_bare_paren()
      case ")" if not self.in_double_quotes and self.open_parens:
        self.leave_paren()
      case "<" if self.opens_heredoc():
        self.note_heredoc()
      case _:
        self.position += 1

  def read_newline(self):
    """At a newline, the bodies of the heredocs this line opened are not code; the reading continues after them."""

    if not self.pending_heredocs:
      self.position += 1
      return

    body_start = self.position + 1
    body_end = self.skip_heredoc_bodies(body_start)
    self.mark_not_code(body_start, body_end, self.depth[self.position])
    self.pending_heredocs = []
    self.position = body_end

  def skip_heredoc_bodies(self, start):
    """The index after the last pending heredoc's terminator line, each body read in the order the tags were opened."""

    position = start
    for tag in self.pending_heredocs:
      position = self.skip_heredoc_body(position, tag)

    return position

  def skip_heredoc_body(self, start, tag):
    """The index after the line that is exactly the tag, or the end of the text when no line is."""

    position = start
    while position < self.length:
      line_end = self.text.find("\n", position)
      if line_end == -1:
        line_end = self.length

      line = self.text[position:line_end]
      position = line_end + 1
      if line.strip() == tag or line.lstrip("\t") == tag:
        break

    return min(position, self.length)

  def opens_comment(self):
    """Whether the # here starts a comment: outside double quotes and after a separator."""

    if self.in_double_quotes:
      return False

    return self.position == 0 or self.text[self.position - 1] in COMMENT_MAY_FOLLOW

  def skip_comment(self):
    """A comment is not code, up to the end of its line."""

    end = self.text.find("\n", self.position)
    if end == -1:
      end = self.length

    self.mark_not_code(self.position, end, self.depth[self.position])
    self.position = end

  def opens_ansi_c_quote(self):
    """Whether the quote here opens a $'...' string, whose backslash escapes a quote inside it."""

    return not self.in_double_quotes and self.position > 0 and self.text[self.position - 1] == "$"

  def skip_ansi_c_quoted(self):
    """A $'...' string is not code; an escaped quote inside it does not end it."""

    position = self.position + 1
    while position < self.length and self.text[position] != "'":
      position += 2 if self.text[position] == "\\" else 1

    self.mark_not_code(self.position, min(position + 1, self.length), self.depth[self.position])
    self.position = position + 1

  def skip_single_quoted(self):
    """A single-quoted string is not code, up to the next quote."""

    end = self.text.find("'", self.position + 1)
    if end == -1:
      end = self.length - 1

    self.mark_not_code(self.position, end + 1, self.depth[self.position])
    self.position = end + 1

  def toggle_double_quotes(self):
    """A double quote opens or closes a double-quoted string, which is code either way."""

    self.in_double_quotes = not self.in_double_quotes
    self.position += 1

  def skip_escaped(self):
    """A backslash and the character after it are read as one."""

    if self.position + 1 < self.length:
      self.depth[self.position + 1] = self.depth[self.position]

    self.position += 2

  def skip_backticks(self):
    """A backtick substitution is read as one piece, up to the closing backtick."""

    end = self.text.find("`", self.position + 1)
    if end == -1:
      end = self.length - 1

    self.position = end + 1

  def enter_substitution(self):
    """At `$(`, a substitution opens; whether it is `$(@verb` is noted for the matching `)`."""

    match = VERB_SUBSTITUTION.match(self.text, self.position)
    verb = match.group(1) if match else None
    self.open_parens.append(OpenParen(self.position, True, verb))
    self.quoted_before_paren.append(self.in_double_quotes)
    self.in_double_quotes = False
    self.position += 2

  def enter_bare_paren(self):
    """A bare `(` is tracked so that the `)` that closes it is not taken for a substitution's."""

    self.open_parens.append(OpenParen(self.position, False, None))
    self.quoted_before_paren.append(self.in_double_quotes)
    self.position += 1

  def leave_paren(self):
    """At `)`, the innermost open paren closes; a `$(@verb` that closes is an opener."""

    paren = self.open_parens.pop()
    self.in_double_quotes = self.quoted_before_paren.pop() if self.quoted_before_paren else False
    if paren.is_substitution and paren.verb:
      self.openers.append(Opener(paren.start, self.position + 1, paren.verb))

    self.position += 1

  def opens_heredoc(self):
    """Whether `<<` here opens a heredoc; `<<<` is a here-string and does not."""

    if self.in_double_quotes or not self.text.startswith("<<", self.position):
      return False

    return not self.text.startswith("<<<", self.position) and HEREDOC_OPENER.match(self.text, self.position) is not None

  def note_heredoc(self):
    """Remembers a heredoc's tag, so the newline that ends this line skips its body."""

    match = HEREDOC_OPENER.match(self.text, self.position)
    self.pending_heredocs.append(match.group(2))
    self.position = match.end()

  def mark_not_code(self, start, end, depth):
    """Marks a range as not code, at the depth of the construct that opened it."""

    for index in range(start, min(end, self.length)):
      self.code[index] = False
      self.depth[index] = depth
