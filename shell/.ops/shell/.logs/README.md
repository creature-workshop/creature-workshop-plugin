# shell-logs

The shell base for reporting to stderr: `log`, `info`, `warn`, `error`,
`fatal`, `hint`, `prompt` and `banner`, in strict POSIX sh, with no
dependencies. Nothing here writes to stdout, which stays the return channel.

`shell/log/api.sh` is the whole library. A repository takes it as a
submodule and sources that one file into each process; shellops and strata
both do. `shell/.ops` vendors shellops for this repository's own lint and
tests, and for nothing at run time.
