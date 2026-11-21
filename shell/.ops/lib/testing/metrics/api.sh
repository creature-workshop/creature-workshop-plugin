#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/testing/metrics/schema.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/location.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/observation.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/record.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/verdict.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/aggregate.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/collect.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/display.sh"

:<<'DOC'
Per-run evidence for impact-based test selection.

Selection is a bet: that running fewer tests keeps finding the same failures.
Nothing in a job log settles that bet, so every run writes one record --
what it was allowed to select, what it ran, and how long that took -- the
escape check adds its verdict once the full suite has finished, and the
scorecard aggregates the records into the rollout numbers the promotion gates
read (planning/docs/test-selection.md).

Records are written whether or not label-driven dispatch is enabled, because the
evidence has to exist before the decision to switch selection on, not after it.

  testing__metrics__begin                     the run context a record is stamped with
  testing__metrics__suite_row                 one suite's share of the run
  testing__metrics__emit                      write the record, echoing its path
  testing__metrics__record_verdict            put the escape check's verdict on a record
  testing__metrics__records                   read a directory's records, sharded runs folded
  testing__metrics__fold_files                one run's record from its shards' files
  testing__metrics__run_files                 the files of the run a record belongs to
  testing__metrics__latest_record_file        the newest record's file
  testing__metrics__latest_record_files       the newest run's files, every shard
  testing__metrics__record_file_for_review    the newest record's file of one review
  testing__metrics__record_files_for_review   the newest run's files of one review, every shard
  testing__metrics__collect                   copy in the merged reviews' records
  testing__metrics__collect_review            copy in one review's record
  testing__metrics__rollup                    aggregate records into rollout numbers

Nothing here holds state between calls: a run's observations are values its
caller collects and hands to testing__metrics__emit, so two runs in one shell
cannot see each other's.
DOC
