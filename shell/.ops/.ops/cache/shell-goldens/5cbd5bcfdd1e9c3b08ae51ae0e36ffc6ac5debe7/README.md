# shell-goldens

A golden test suite for a shell library, in strict POSIX sh: one
directory per case, a transcript of its calls, and a bats file that runs
every case under every shell and variant the consumer names.

`shell/golden/` is the whole library. A repository takes it as a
submodule and uses three files from it:

- `api.sh` is the transcript driver. A consumer's script sources it,
  defines a hook that runs one call line, and passes the hook to
  `golden__transcribe`. The driver reads the calls file and writes one
  block per call: `## <call>`, the answer, and `!! <status> <message>`
  when the call fails.
- `bats.sh` registers every fileset under `GOLDEN_FIXTURES` as a bats
  test of its own, once per variant, through `golden__register`, and
  checks a case against its `expected.txt`. `UPDATE_GOLDENS=1` rewrites
  the expected transcripts.
- `answer.awk` prints one call's answer out of a transcript, for a
  script that compares an answer with another program's.

A fileset is a directory `<name>/` that holds `name.txt`, `about.txt`,
`calls.txt` and `expected.txt`, and a directory for each document a call
reads by name, with a `name.txt` and an `about.txt` of its own.
`test/fixtures/verbs/` shows one, and `test/verbs-transcript.sh` is the
smallest consumer.

`shell/.ops` vendors shellops for this repository's own lint and tests,
and for nothing at run time.
