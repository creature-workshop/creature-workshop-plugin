# shell-scan

The heredoc scanner for shell sources: the awk runtime a lint detector or a
doc extractor loads before its own program, so that every reader of a shell
file draws the same boundaries. Where a heredoc body starts and ends, what
is a comment, and where a function begins are each answered once, here.

`shell/scan/scan.awk` is the whole library, and its header states the hook
contract. `shell/scan/trace.awk` is the smallest detector: it prints what
the hooks answer for each line. The tests read every fixture under
`test/fixtures` through it and compare the result with the trace recorded
beside the fixture.

A repository takes this library at a pin and composes its own `-f` list
from its copy:

    awk -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" -f detector.awk <files...>

shellops and shell-docs both do. `shell/.ops` vendors shellops for this
repository's own lint and tests, and for nothing else.

The work is tracked in Linear on the SILT project, from STRATA-221.
