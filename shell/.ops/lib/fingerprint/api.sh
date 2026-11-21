#!/bin/sh
# shellcheck disable=SC2119  # bare @arr/@obj are the structs empty constructors

import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/fingerprint/probe.sh"
import "$SHELLOPS_DIR/lib/fingerprint/report.sh"
import "$SHELLOPS_DIR/lib/fingerprint/declare.sh"

:<<'DOC'
Job-input fingerprinting: the module that reads an input declares it, and
declaring it is what gets it reported.

A report names the variable and whether it is unset, empty, or set. A set one
carries its length, and then what its kind allows: a secret its sha256's first
twelve hex digits and its scheme prefix, which tell a missing value from a stale
one -- compare the digest against the copy in the password manager -- without a
job log ever holding it; an input its value, there being nothing to protect and
the value saying more than any digest of it would.

The kinds part because the report does, not because the declaration does. A
wrong non-secret breaks a pipeline as quietly as a wrong token, so both are
declared the same way, which is what the DSL's env block says by typing an entry
@secret or @string (planning/docs/features/env-block.md).

One input is one declaration, named as the chain of variables its reader falls
back through in order, and for a non-secret the default it uses when none of
them supplies a value. A chain's report marks the name the value came from, so
an input arriving from a name nobody meant is visible rather than inferred.

A name is reported once per process, so a module sourced twice, and a name two
modules both read, still get one line -- carrying the marker of whichever chain
resolved to it, however late the module declaring that chain was sourced.

A declaration is a struct object and a report a struct array of lines, folded up
and returned through stdout, so nothing here accumulates in a string. A secret's
value is the one exception: it reaches sha256sum and cut down a pipe and never
becomes an argument of a command, because argv is readable from outside the
process and the value is the one thing that must not be.

Environment:
  FINGERPRINT_OUT    A file every report is appended to. Setting it puts the
                     process in reporting mode: a declaration reports itself as
                     its module is sourced, so an input appears because the job
                     used the module that reads it.
  FINGERPRINT_DEFER  true holds declarations for a caller that reports them
                     itself. With neither variable set, a declaration is a
                     no-op that spends nothing.

Usage:
  import "$SHELLOPS_DIR/lib/fingerprint/api.sh"

  fingerprint__secret GITLAB_TOKEN FORGE_PR_TOKEN CI_JOB_TOKEN
  fingerprint__input SHELLOPS_FORGE=gitlab
  fingerprint__report
DOC
