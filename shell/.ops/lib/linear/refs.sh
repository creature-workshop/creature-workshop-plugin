#!/bin/sh

:<<'MODULE'
Reading Linear issue references out of author-written prose: which issues a
text names, and which it declares closed.

Its own module because nothing here talks to Linear -- the IDs are text until
lib/linear/api.sh is asked to do something with them.

Every reader of prose takes the team keys as the pattern linear__keys_pattern
prints, "$keys" in the usages below, and reads an identifier of any team in
it. One bare key, such as OPS, is the pattern for that team alone.
MODULE

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/markdown/api.sh"

: <<'CONST'
Ported from GitLab's default issue_closing_pattern:
https://docs.gitlab.com/administration/issue_closing_pattern/

Lower case only, since matching is case-insensitive. The word boundary that
stops "prefixes" matching as "fixes" is in the pattern below instead, because
an awk program reads this string too and POSIX awk has no \b.
CONST
__linear__refs__CLOSING_VERBS='(clos(e|es|ed|ing)|fix(es|ed|ing)?|resolv(e|es|ed|ing)|implement(s|ed|ing)?)'

# CONST: A newline, the line break between the ids a sorter reads one per line.
__linear__refs__NL='
'

:<<'PUB_FUN'
Prints the extended regex matching any one of the team keys in KEYS, a struct
array of strings, and nothing for an empty array: with no team, no text can
name an issue.

  linear__keys_pattern "$(@arr OPS BIZ)"  ->  (OPS|BIZ)

Usage: linear__keys_pattern "$keys"
PUB_FUN
linear__keys_pattern() {
  if @len __linear__keys_pattern__len_1 "$1"; [ "$__linear__keys_pattern__len_1" -eq 0 ]; then
    return 0
  fi

  @join __linear__keys_pattern__joined "$1" "|"

  println "($__linear__keys_pattern__joined)"
}

:<<'PUB_FUN'
Prints the key of the team an issue identifier belongs to: the text before
its dash.

  linear__issue_team_key OPS-12  ->  OPS

Usage: linear__issue_team_key "$id"
PUB_FUN
linear__issue_team_key() {
  println "${1%%-*}"
}

:<<'FUN'
Prints the extended regex matching a whole closing clause for the teams in
KEYS: a verb, an optional colon, an optional "issue"/"issues", then references
chained
with commas or "and", each optionally wrapped as a markdown link.

Assembled from named pieces because the finished expression is unreadable.

Usage: __linear__refs__closing_clause_pattern "$keys"
FUN
__linear__refs__closing_clause_pattern() {
  __linear__refs__closing_clause_pattern__ref="$1-[0-9]+"

  # The chain has to step over a link's tail, not just its opening bracket:
  # without that a clause ends at the first "](url)" and later references are
  # lost.
  __linear__refs__closing_clause_pattern__link='\[?'
  __linear__refs__closing_clause_pattern__tail='(\]\([^)]*\))?'

  # Comma, "and", ", and", or bare whitespace, matching upstream's separator.
  __linear__refs__closing_clause_pattern__sep='( *,? +and +| *,? *)'

  __linear__refs__closing_clause_pattern__one="\
${__linear__refs__closing_clause_pattern__link}\
${__linear__refs__closing_clause_pattern__ref}\
${__linear__refs__closing_clause_pattern__tail}"

  __linear__refs__closing_clause_pattern__chain="\
${__linear__refs__closing_clause_pattern__one}\
(${__linear__refs__closing_clause_pattern__sep}\
${__linear__refs__closing_clause_pattern__one})*"

  # \b keeps the verb from matching inside a longer word, so "prefixes OPS-1" is
  # prose. One covers every branch, as the group sits at the match start.
  printf '%s' "\\b${__linear__refs__CLOSING_VERBS}:? +(issues? +)?${__linear__refs__closing_clause_pattern__chain}"
}

:<<'FUN'
Rewrites bulleted closing lists on stdin into the inline form.

Usage: ... | __linear__refs__normalize_closing_lists
FUN
__linear__refs__normalize_closing_lists() {
  awk -v verb="$__linear__refs__CLOSING_VERBS" \
    -f "$SHELLOPS_DIR/lib/linear/normalize_closing_lists.awk"
}

:<<'FUN'
Uppercases and de-duplicates the references on stdin, so "ops-1" and "OPS-1"
are one issue rather than two.

Shared by both extractors because callers subtract one result from the other,
and two spellings of "canonical" would leave a closed issue looking mentioned.

Usage: ... | __linear__refs__canonicalize_ids
FUN
__linear__refs__canonicalize_ids() {
  tr '[:lower:]' '[:upper:]' | sort -u
}

:<<'PUB_FUN'
Prints the issue IDs a text declares closed, as a struct array.

A declaration is a closing keyword followed by the ID: "Closes OPS-1",
"fixes OPS-1, OPS-2 and OPS-3", or a bulleted list beneath a bare "Closes:".
An ID merely mentioned is not returned -- see linear__extract_mentioned_ids.

Expects code to be gone already, via markdown__strip_code: a keyword shown as
an example declares nothing.

Usage: linear__extract_closing_ids "$text" "$keys"
PUB_FUN
linear__extract_closing_ids() {
  # Bullets first, rewritten inline, so everything downstream has one shape.
  __linear__extract_closing_ids__inlined="$(
    println "$1" | __linear__refs__normalize_closing_lists
  )"

  __linear__refs__clause_ids "$__linear__extract_closing_ids__inlined" "$2"
}

:<<'FUN'
Prints the issue IDs the closing clauses of a text name, as a struct array:
"Closes OPS-1" and "fixes OPS-1, OPS-2 and OPS-3", but not a bulleted list,
which linear__extract_closing_ids rewrites into a clause first. Reading the
text as it is, this is how a clause is told from a list.

The whole clause is matched first, verb and all: matching the clause before
the reference is the entire distinction between "Closes ABC-1" and a bare
mention of it. The references inside the clauses come in a second pass
rather than a capture group, since a chain holds no fixed number of them,
and link tails go first so that a URL spelling an ID is not read as a
declaration of its own. Each grep ends in `|| true` because grep exits 1 on
no match, which under pipefail reads as a failure rather than as "this text
declares nothing".

Usage: __linear__refs__clause_ids "$text" "$keys"
FUN
__linear__refs__clause_ids() {
  __linear__refs__clause_ids__clause="$(__linear__refs__closing_clause_pattern "$2")"
  __linear__refs__clause_ids__clauses="$(
    println "$1" \
      | grep -oiE "$__linear__refs__clause_ids__clause" || true
  )"
  __linear__refs__clause_ids__declared="$(
    println "$__linear__refs__clause_ids__clauses" \
      | sed -E 's/\]\([^)]*\)//g' \
      | grep -oiE "$2-[0-9]+" \
      | __linear__refs__canonicalize_ids || true
  )"

  @split __linear__refs__clause_ids__out "$__linear__refs__clause_ids__declared"
  println "$__linear__refs__clause_ids__out"
}

:<<'PUB_FUN'
Prints every issue ID a text names, declared closed or not, as a struct array.

Reads un-normalized text on purpose: normalization discards a bullet's tail,
and an ID mentioned there is still worth knowing about.

Usage: linear__extract_mentioned_ids "$text" "$keys"
PUB_FUN
linear__extract_mentioned_ids() {
  __linear__extract_mentioned_ids__found="$(
    println "$1" \
      | grep -oiE "$2-[0-9]+" \
      | __linear__refs__canonicalize_ids || true
  )"

  @split __linear__extract_mentioned_ids__out "$__linear__extract_mentioned_ids__found"
  println "$__linear__extract_mentioned_ids__out"
}

:<<'PUB_FUN'
Prints every issue ID the given texts name, as one canonical struct array.

TEXTS is a struct array of whatever a reader wrote: a title, a description, a
comment, a branch name. Each is read as prose -- fenced blocks and backtick
spans are dropped first, so an identifier shown as an example is an example --
and an ID named in several of them is one ID.

Usage: linear__mentions_in_texts "$texts" "$keys"
PUB_FUN
linear__mentions_in_texts() {
  @arr __linear__mentions_in_texts__arr_2
  @reduce __linear__mentions_in_texts__found __linear__refs__add_text_ids \
      "$1" \
      "$__linear__mentions_in_texts__arr_2" \
      "$2" \
      linear__extract_mentioned_ids

  @unique __linear__mentions_in_texts__out "$__linear__mentions_in_texts__found"
  println "$__linear__mentions_in_texts__out"
}

:<<'PUB_FUN'
Prints every issue ID the given texts declare closed, as one canonical struct
array.

Each text is read on its own, which is the point of taking an array rather than
one string: a clause and the references it chains are a single sentence or a
single bulleted list, so a "Closes:" ending one author's text must not collect
the bullets that open the next one's.

Usage: linear__closings_in_texts "$texts" "$keys"
PUB_FUN
linear__closings_in_texts() {
  @arr __linear__closings_in_texts__arr_3
  @reduce __linear__closings_in_texts__found __linear__refs__add_text_ids \
      "$1" \
      "$__linear__closings_in_texts__arr_3" \
      "$2" \
      linear__extract_closing_ids

  @unique __linear__closings_in_texts__out "$__linear__closings_in_texts__found"
  println "$__linear__closings_in_texts__out"
}

:<<'FUN'
Adds the IDs EXTRACTOR reads out of one more text to the set so far, the text
stripped of code first: both extractors want prose, and an identifier shown as
an example is an example either way.

Usage: __linear__refs__add_text_ids "$ids" "$text" "$keys" linear__extract_closing_ids
FUN
__linear__refs__add_text_ids() {
  @unwrap __linear__refs__add_text_ids__text "$2"
  __linear__refs__add_text_ids__prose="$(
    println "$__linear__refs__add_text_ids__text" | markdown__strip_code
  )"
  __linear__refs__add_text_ids__ids="$(
    "$4" "$__linear__refs__add_text_ids__prose" "$3"
  )"

  @concat __linear__refs__add_text_ids__out "$1" "$__linear__refs__add_text_ids__ids"
  println "$__linear__refs__add_text_ids__out"
}

:<<'FUN'
Prints true when TEXT holds nothing but references to the teams in KEYS and
the
punctuation joining them, false when it says anything else.

Decided by removal -- take the references and their separators out, then see
whether anything is left -- so the separator grammar is spelled once. The guard
either side of AND keeps it a whole word, leaving "understand" as residue.

Usage: __linear__refs__is_refs_only "$text" "$keys"
FUN
__linear__refs__is_refs_only() {
  __linear__refs__is_refs_only__residue="$(
    printf '%s' "$1" \
      | tr '[:lower:]' '[:upper:]' \
      | sed -E "s/$2-[0-9]+//g" \
      | sed -E 's/(^|[^A-Z])AND([^A-Z]|$)/\1\2/g' \
      | tr -d '[:space:],'
  )"

  @succeeds __linear__refs__is_refs_only__out [ -z "$__linear__refs__is_refs_only__residue" ]  # structs-lint: allow -- the word null left in the text is still residue
  println "$__linear__refs__is_refs_only__out"
}

:<<'PUB_FUN'
Prints the issue IDs of a text that is nothing but issue IDs, as a struct array.
Any other text yields an empty array. Separators are allowed, so
"OPS-1, OPS-2 and OPS-3" counts.

The one place a bare ID declares a closure, and narrow enough to be safe: a
comment reading only "OPS-1" answers which issues a change closes, while "we
should revisit OPS-1 later" is prose that happens to name one.

Usage: linear__extract_refs_only_ids "$text" "$keys"
PUB_FUN
linear__extract_refs_only_ids() {
  __linear__extract_refs_only_ids__ids="$(linear__extract_mentioned_ids "$1" "$2")"
  if @len __linear__extract_refs_only_ids__len_4 "$__linear__extract_refs_only_ids__ids"; [ "$__linear__extract_refs_only_ids__len_4" -eq 0 ]; then
    @split __linear__extract_refs_only_ids__out ""
    println "$__linear__extract_refs_only_ids__out"
    return 0
  fi

  if [ "$(__linear__refs__is_refs_only "$1" "$2")" != true ]; then
    @split __linear__extract_refs_only_ids__out ""
    println "$__linear__extract_refs_only_ids__out"
    return 0
  fi

  printf '%s' "$__linear__extract_refs_only_ids__ids"
}

:<<'PUB_FUN'
Prints TEXT with each bare reference to a team in KEYS rewritten as a markdown
link under PREFIX.

A reference that is already a link, or that lives in a fenced block or a
backtick span, is left alone -- so a second pass is a no-op, and an
identifier shown as an example stays an example. Another team's
identifier is not ours.

Usage: linear__linkify_refs "$text" "$keys" "https://linear.app/example/issue"
PUB_FUN
linear__linkify_refs() {
  __linear__linkify_refs__prefix="${3%/}"

  # Feed the text as-is so a trailing newline in the source is not doubled;
  # awk still sees a last line that has none.
  printf '%s' "$1" \
    | awk \
      -v team="$2" \
      -v prefix="$__linear__linkify_refs__prefix" \
      -f "$SHELLOPS_DIR/lib/markdown/lines.awk" \
      -f "$SHELLOPS_DIR/lib/linear/linkify_refs.awk"
}

:<<'PUB_FUN'
Prints the directory an issue URL sits in. PREFIX/OPS-51 is then that
issue; a title slug after the identifier is discarded.

Usage: linear__issue_url_prefix "$url"
PUB_FUN
linear__issue_url_prefix() {
  printf '%s' "$1" | sed -E 's|/[^/]+-[0-9]+(/.*)?$||'
}

: <<'PUB_CONST'
Where a text that names an issue comes from, the places a code review's
author and its reviewers write: the title, the description, the head branch's
name, a commit message, a comment on the conversation, and a comment in a
thread on the diff.
PUB_CONST
@enum linear__refs__WHERE TITLE DESCRIPTION BRANCH COMMIT COMMENT THREAD

: <<'PUB_CONST'
How a text names an issue. A clause is a closing keyword before the id,
"Closes OPS-1". A list is the id under a bare "Closes:" bullet list. A reply
is a comment that is nothing but an answer to what the change closes, the one
linear/sync-refs asks for: identifiers alone, or a closing clause or list and
nothing else. A mention is the id in prose with no keyword.
PUB_CONST
@enum linear__refs__HOW CLAUSE LIST REPLY MENTION

:<<'PUB_FUN'
Prints one record per issue a text names, {id, where, how}, as a struct
array. WHERE is the linear__refs__WHERE word for the text. An id named more
than once in the text gets one record, with the strongest how: a clause,
then a list, then a reply, then a mention. A comment that is nothing but an
answer, identifiers alone or a closing clause or list and nothing else, is a
reply as a whole, and only a comment can be one, so a text from anywhere
else never answers. Code is dropped first: an identifier or a keyword shown
as an example is an example.

  linear__mention_records "Closes OPS-1. See OPS-2." description OPS
    -> [{"id": "OPS-1", "where": "description", "how": "clause"},
        {"id": "OPS-2", "where": "description", "how": "mention"}]

Usage: linear__mention_records "$text" "$where" "$keys"
PUB_FUN
linear__mention_records() {
  __linear__mention_records__prose="$(println "$1" | markdown__strip_code)"
  __linear__mention_records__reply="$(__linear__refs__reply_ids "$__linear__mention_records__prose" "$2" "$3")"
  __linear__mention_records__clause="$(__linear__refs__clause_ids "$__linear__mention_records__prose" "$3")"
  @difference __linear__mention_records__clause "$__linear__mention_records__clause" "$__linear__mention_records__reply"
  __linear__mention_records__closing="$(linear__extract_closing_ids "$__linear__mention_records__prose" "$3")"
  @difference __linear__mention_records__closing "$__linear__mention_records__closing" "$__linear__mention_records__reply"
  @difference __linear__mention_records__list "$__linear__mention_records__closing" "$__linear__mention_records__clause"
  __linear__mention_records__named="$(linear__extract_mentioned_ids "$__linear__mention_records__prose" "$3")"
  @difference __linear__mention_records__named "$__linear__mention_records__named" "$__linear__mention_records__closing"
  @difference __linear__mention_records__named "$__linear__mention_records__named" "$__linear__mention_records__reply"

  __linear__mention_records__clauses="$(__linear__refs__records_of "$__linear__mention_records__clause" "$2" "$linear__refs__HOW_CLAUSE")"
  __linear__mention_records__lists="$(__linear__refs__records_of "$__linear__mention_records__list" "$2" "$linear__refs__HOW_LIST")"
  __linear__mention_records__replies="$(__linear__refs__records_of "$__linear__mention_records__reply" "$2" "$linear__refs__HOW_REPLY")"
  __linear__mention_records__mentions="$(__linear__refs__records_of "$__linear__mention_records__named" "$2" "$linear__refs__HOW_MENTION")"
  @concat __linear__mention_records__records "$__linear__mention_records__clauses" "$__linear__mention_records__lists"
  @concat __linear__mention_records__records "$__linear__mention_records__records" "$__linear__mention_records__replies"

  @concat __linear__mention_records__out "$__linear__mention_records__records" "$__linear__mention_records__mentions"
  println "$__linear__mention_records__out"
}

:<<'FUN'
Prints the ids a text declares by being nothing but an answer, when the text
is a comment on the conversation: identifiers alone, or a closing clause or
list and nothing else. An empty array for a text from anywhere else: a title
or a branch name that is only an id is not an answer.

Usage: __linear__refs__reply_ids "$prose" "$where" "$keys"
FUN
__linear__refs__reply_ids() {
  if [ "$2" != "$linear__refs__WHERE_COMMENT" ]; then
    @arr __linear__refs__reply_ids__out
    println "$__linear__refs__reply_ids__out"
    return 0
  fi
  if @is_true "$(__linear__refs__is_declaration_only "$1" "$3")"; then
    linear__extract_closing_ids "$1" "$3"
    return 0
  fi

  linear__extract_refs_only_ids "$1" "$3"
}

:<<'FUN'
Prints true when TEXT is nothing but closing clauses or lists for the teams
in KEYS, with only whitespace and full stops between them, and false when it
says anything else or declares nothing. Decided the way
__linear__refs__is_refs_only decides: the lists rewritten inline, the clauses
taken out, and whatever is left is residue, so a quoted "> Closes OPS-1" is
prose by its quote mark.

Usage: __linear__refs__is_declaration_only "$text" "$keys"
FUN
__linear__refs__is_declaration_only() {
  __linear__refs__is_declaration_only__inlined="$(
    println "$1" | __linear__refs__normalize_closing_lists
  )"
  __linear__refs__is_declaration_only__pattern="$(__linear__refs__closing_clause_pattern "$2")"
  __linear__refs__is_declaration_only__clauses="$(
    println "$__linear__refs__is_declaration_only__inlined" \
      | grep -oiE "$__linear__refs__is_declaration_only__pattern" || true
  )"
  if ! @defined "$__linear__refs__is_declaration_only__clauses"; then
    @false __linear__refs__is_declaration_only__out
    println "$__linear__refs__is_declaration_only__out"
    return 0
  fi
  __linear__refs__is_declaration_only__said="$(
    printf '%s' "$__linear__refs__is_declaration_only__inlined" | tr -d '[:space:].'
  )"
  __linear__refs__is_declaration_only__declared="$(
    printf '%s' "$__linear__refs__is_declaration_only__clauses" | tr -d '[:space:].'
  )"

  @succeeds __linear__refs__is_declaration_only__out [ "$__linear__refs__is_declaration_only__said" = "$__linear__refs__is_declaration_only__declared" ]
  # structs-lint: allow -- two texts compared, neither a boolean
  println "$__linear__refs__is_declaration_only__out"
}

:<<'FUN'
Prints one record per id in IDS, each with the same WHERE and HOW.

Usage: __linear__refs__records_of "$ids" description clause
FUN
__linear__refs__records_of() {
  @map __linear__refs__records_of__out __linear__refs__record_of "$1" "$2" "$3"
  println "$__linear__refs__records_of__out"
}

:<<'FUN'
@map callback: the record for the wrapped id $1, from $2, named as $3.
FUN
__linear__refs__record_of() {
  @unwrap __linear__refs__record_of__id "$1"

  @obj __linear__refs__record_of__out \
    '.id' "$__linear__refs__record_of__id" \
    '.where' "$2" \
    '.how' "$3"
  println "$__linear__refs__record_of__out"
}

:<<'PUB_FUN'
Prints one source, {where, text}: a text paired with the place it was
written, which is what linear__mention_records_in reads. WHERE is a
linear__refs__WHERE word.

  linear__source commit "Closes OPS-1"  ->  {"where": "commit", "text": "Closes OPS-1"}

Usage: linear__source "$where" "$text"
PUB_FUN
linear__source() {
  @obj __linear__source__out \
    '.where' "$1" \
    '.text' "$2"
  println "$__linear__source__out"
}

:<<'PUB_FUN'
Prints one source per text in TEXTS, a struct array of strings, all of them
written at WHERE.

  linear__sources_at commit "$(@arr "Closes OPS-1" "see OPS-2")"
    -> [{"where": "commit", "text": "Closes OPS-1"}, {"where": "commit", "text": "see OPS-2"}]

Usage: linear__sources_at "$where" "$texts"
PUB_FUN
linear__sources_at() {
  @map __linear__sources_at__out __linear__refs__source_at "$2" "$1"
  println "$__linear__sources_at__out"
}

:<<'FUN'
@map callback: the source for the wrapped text $1, written at $2.
FUN
__linear__refs__source_at() {
  @unwrap __linear__refs__source_at__unwrap_5 "$1"
  linear__source "$2" "$__linear__refs__source_at__unwrap_5"
}

:<<'PUB_FUN'
Prints the records of every source in SOURCES, {where, text} each, in
order: linear__mention_records over each text at its own where. A caller
pairs each text with its place when it collects the text, and reads them
all here in one call.

  linear__mention_records_in "$(@arr "$(linear__source commit "Closes OPS-1")" "$(linear__source comment "see OPS-2")")" OPS
    -> [{"id": "OPS-1", "where": "commit", "how": "clause"},
        {"id": "OPS-2", "where": "comment", "how": "mention"}]

Usage: linear__mention_records_in "$sources" "OPS"
PUB_FUN
linear__mention_records_in() {
  @arr __linear__mention_records_in__arr_6
  @reduce __linear__mention_records_in__out __linear__refs__add_source_records "$1" "$__linear__mention_records_in__arr_6" "$2"
  println "$__linear__mention_records_in__out"
}

:<<'FUN'
@reduce callback: the records so far plus the source $2's, its text read at
its where for the team keys $3, as linear__keys_pattern prints them.
FUN
__linear__refs__add_source_records() {
  @let "$2" __linear__refs__add_source_records__ where text
  __linear__refs__add_source_records__records="$(
    linear__mention_records "$__linear__refs__add_source_records__text" "$__linear__refs__add_source_records__where" "$3"
  )"
  @unlet __linear__refs__add_source_records__ where text

  @concat __linear__refs__add_source_records__out "$1" "$__linear__refs__add_source_records__records"
  println "$__linear__refs__add_source_records__out"
}

:<<'PUB_FUN'
Prints true when the record says the merge closes its issue, false otherwise.
A clause or a list closes in the description or in a commit message, where
the author speaks as the author. A reply closes on the conversation, where a
comment of nothing but identifiers, or of nothing but a closing clause or
list, answers what the change closes. A mention closes nothing, wherever it
is, and neither does a keyword in a sentence of a comment or in a thread,
which describes work rather than claims it.

  linear__mention_closes '{"id": "OPS-1", "where": "commit", "how": "clause"}'  ->  true
  linear__mention_closes '{"id": "OPS-1", "where": "thread", "how": "clause"}'  ->  false

Usage: linear__mention_closes "$record"
PUB_FUN
linear__mention_closes() {
  @let "$1" __linear__mention_closes__ where how
  __linear__mention_closes__place="$__linear__mention_closes__where"
  __linear__mention_closes__form="$__linear__mention_closes__how"
  @unlet __linear__mention_closes__ where how

  case "$__linear__mention_closes__form" in
    "$linear__refs__HOW_CLAUSE"|"$linear__refs__HOW_LIST") __linear__refs__declares_at "$__linear__mention_closes__place" ;;
    "$linear__refs__HOW_REPLY") __linear__refs__answers_at "$__linear__mention_closes__place" ;;
    *) @false __linear__mention_closes__out; println "$__linear__mention_closes__out" ;;
  esac
}

:<<'FUN'
Prints true when a closing keyword at WHERE is the author's declaration: in
the description or a commit message.
FUN
__linear__refs__declares_at() {
  case "$1" in
    "$linear__refs__WHERE_DESCRIPTION"|"$linear__refs__WHERE_COMMIT") @true __linear__refs__declares_at__out; println "$__linear__refs__declares_at__out" ;;
    *) @false __linear__refs__declares_at__out; println "$__linear__refs__declares_at__out" ;;
  esac
}

:<<'FUN'
Prints true when a text of nothing but identifiers at WHERE answers what the
change closes: on the conversation.
FUN
__linear__refs__answers_at() {
  case "$1" in
    "$linear__refs__WHERE_COMMENT") @true __linear__refs__answers_at__out; println "$__linear__refs__answers_at__out" ;;
    *) @false __linear__refs__answers_at__out; println "$__linear__refs__answers_at__out" ;;
  esac
}

:<<'PUB_FUN'
Prints the ids of the records that close on merge, canonical and each once,
as a struct array.

Usage: linear__closing_ids "$records"
PUB_FUN
linear__closing_ids() {
  @arr __linear__closing_ids__arr_7
  @reduce __linear__closing_ids__closing __linear__refs__add_closing_id "$1" "$__linear__closing_ids__arr_7"

  __linear__refs__unique_ids "$__linear__closing_ids__closing"
}

:<<'FUN'
@reduce callback: the ids so far plus the record's, when it closes on merge.
FUN
__linear__refs__add_closing_id() {
  if @is_true "$(linear__mention_closes "$2")"; then
    @get __linear__refs__add_closing_id__id "$2" '.id'
    @push __linear__refs__add_closing_id__out "$1" "$__linear__refs__add_closing_id__id"
    println "$__linear__refs__add_closing_id__out"
    return 0
  fi

  println "$1"
}

:<<'PUB_FUN'
Prints the ids of every record, canonical and each once, as a struct array.

Usage: linear__mentioned_ids "$records"
PUB_FUN
linear__mentioned_ids() {
  @pluck __linear__mentioned_ids__pluck_8 "$1" '.id'
  __linear__refs__unique_ids "$__linear__mentioned_ids__pluck_8"
}

:<<'FUN'
Prints the ids in IDS each once, upper-cased and sorted, the order every
reader of a set of ids expects.
FUN
__linear__refs__unique_ids() {
  @join __linear__refs__unique_ids__joined "$1" "$__linear__refs__NL"
  __linear__refs__unique_ids__sorted="$(println "$__linear__refs__unique_ids__joined" | __linear__refs__canonicalize_ids)"

  @split __linear__refs__unique_ids__out "$__linear__refs__unique_ids__sorted"
  println "$__linear__refs__unique_ids__out"
}
