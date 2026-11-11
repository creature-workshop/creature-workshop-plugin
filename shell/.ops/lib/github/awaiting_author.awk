# Prints one pull request as a record of who is waiting on its author:
# {iid, url, branch, draft, reviewers: [login...]}. It prints nothing when
# no reviewer is waiting, because an empty list of reviewers would answer
# the question "who is waiting" wrongly.
#
# Input: the pull request, and ahead of it, with --with, its reviews.
#
# GitHub keeps every review a user left, so a user's word is their latest
# review. It counts only while it says CHANGES_REQUESTED and the user is
# not among the pull request's requested_reviewers, which is where a new
# request for their review puts them. The reviewers are in the order of
# their logins.

function main(line) {
  tree_line(line)
}

# Notes the login of every reviewer the pull request asks again.
function note_asked_again(__reviewer) {
  for (__reviewer = NODE_FIRST[member(PULL, "requested_reviewers")]; __reviewer != 0; __reviewer = NODE_NEXT[__reviewer]) {
    ASKED_AGAIN[text_of(member(__reviewer, "login"))] = 1
  }
}

# Notes each user's latest review: the one submitted last, and of several
# submitted at the same time, the one GitHub lists last.
function note_latest_reviews(__review, __login) {
  for (__review = NODE_FIRST[REVIEWS]; __review != 0; __review = NODE_NEXT[__review]) {
    __login = text_of(member(member(__review, "user"), "login"))
    if (!(__login in LATEST)) {
      LOGINS++
      LOGIN[LOGINS] = __login
      LATEST[__login] = __review
    } else if ((submitted_at(__review) "") >= (submitted_at(LATEST[__login]) "")) {
      LATEST[__login] = __review
    }
  }
}

# The time a review was submitted, and the empty string when it has none,
# which orders before every time.
function submitted_at(review) {
  return text_or(member(review, "submitted_at"), "")
}

# Puts the logins in byte order, by insertion.
function sort_logins(__i, __place, __login) {
  for (__i = 2; __i <= LOGINS; __i++) {
    __login = LOGIN[__i]
    __place = __i
    while (__place > 1 && (LOGIN[__place - 1] "") > (__login "")) {
      LOGIN[__place] = LOGIN[__place - 1]
      __place--
    }
    LOGIN[__place] = __login
  }
}

# Notes the logins that are still waiting, in order.
function note_waiting(__i, __login) {
  WAITING = 0

  for (__i = 1; __i <= LOGINS; __i++) {
    __login = LOGIN[__i]
    if (text_of(member(LATEST[__login], "state")) == "CHANGES_REQUESTED" && !(__login in ASKED_AGAIN)) {
      WAITING++
      WAITER[WAITING] = __login
    }
  }
}

# Prints the record of the pull request with the reviewers waiting.
function print_record(__i) {
  print_node(member(PULL, "number"), 0, wrap("iid"))
  print_node(member(PULL, "html_url"), 0, wrap("url"))
  print_node(member(member(PULL, "head"), "ref"), 0, wrap("branch"))
  print_node(member(PULL, "draft"), 0, wrap("draft"))
  print_open(0, wrap("reviewers"), "list")

  for (__i = 1; __i <= WAITING; __i++) {
    print "1." (__i - 1) ":str=" wrap(WAITER[__i])
  }
}

BEGIN {
  REVIEWS = tree_ahead()
  PULL = tree_open()
  LOGINS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  note_asked_again()
  note_latest_reviews()
  sort_logins()
  note_waiting()
  if (WAITING > 0) {
    print_record()
  }
}

{ main($0) }
