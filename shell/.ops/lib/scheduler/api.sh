#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/queue/api.sh" \
  "$SHELLOPS_DIR/lib/scheduler/_landing.sh" \
  "$SHELLOPS_DIR/lib/scheduler/_read.sh" \
  "$SHELLOPS_DIR/lib/scheduler/_act.sh"

: <<'MODULE'
The scheduler's tick: a pure function from one reading of the forge to the
actions one tick takes (ADR.19@global, ADR.2 and ADR.5@scheduler). The
reading is a snapshot the forge adaptor takes and the actions are what it
performs, and nothing here touches the forge, so every case is a fixture
(lib/scheduler/fixtures.sh) and a tick on an unchanged forge yields nothing.
What a tick does about each merge request is a queue's transitions, a table
of data beside the queue, so a queue's topology is declared and never a
hand edit; lib/scheduler/_landing.sh says how the landing queue's is walked.

A tick is the four public functions in order, over one options struct
(scheduler__landing__options): scheduler__landing__read takes the snapshot
from the forge and the clone the tick keeps, scheduler__landing__decide
turns it into actions, and scheduler__landing__act performs them, every
write checking the fact it rests on (ADR.4@scheduler). The forge is reached
through its adaptor alone (ADR.16@global), so a tick on another forge is
another adaptor.

A snapshot carries:

  now              seconds since the epoch, the tick's clock
  trunk            .branch; .head, its tip; .base, the commit a head is
                   rebased onto, the tip, since nothing sits on the trunk
                   but landings (ADR 000044)
  merge_requests   one per open merge request: .iid; .head; .target; .base,
                   the trunk commit the head is rebased on; .approved,
                   whether the approval rules hold on this head;
                   .approved_at; .priority, a person's, 0 when none;
                   .label, the scheduler's label it carries (reviewing,
                   awaiting-merge, next-merge, or empty); .run, its landing
                   run or null, with .sha, .base and .status (running,
                   success, failed or canceled); .rebases_cleanly

An action carries .action, the .iid it concerns where one does, .rule, the
event whose row fired, and .facts, the fields the rule read, so the event
log is written from the action and never reconstructed:

  label         set the scheduler's label on the merge request, the other
                two coming off; next-merge is the landing mark and precedes
                the head's run
  leave         the merge request left the queue, with .reason the event:
                stacked, unapproved, conflicts or red
  cancel_run    cancel the landing run .run, no longer on the head and the
                trunk's base
  rebase        rebase the head onto .onto, the trunk's base; the push a
                marked head gets starts its landing run
  start_run     create the landing run on the marked head
  merge         merge the head at .sha, the approval rules read again first
MODULE

: <<'PUB_FUN'
Prints the options a tick reads and acts on a repository with: the token it
speaks to the forge with, the remote its clone reads and writes, the trunk
(empty for the branch the forge calls its default), whether it writes at all,
and the lease it holds, empty until it takes one. A caller changes a field
with @set.

  scheduler__landing__options "$FORGE_PR_TOKEN"
  -> {"token":"glpat-...","remote":"origin","branch":"","dry_run":false,"lease":{}}

args:
  $1  The forge token
PUB_FUN
scheduler__landing__options() {
  @false __scheduler__landing__options__false_1
  @obj __scheduler__landing__options__obj_2
  @obj __scheduler__landing__options__out \
    '.token' "$1" \
    '.remote' origin \
    '.branch' '' \
    '.dry_run' "$__scheduler__landing__options__false_1" \
    '.lease' "$__scheduler__landing__options__obj_2"
  println "$__scheduler__landing__options__out"
}
