"""The plan store: a project's plan, kept in a YAML file under its .ops/data/, as
one record per ticket.

The file is the one shellops' file tracker reads and writes, so `ops plan`
and the pane show the same plan:

    prefix: PLAN
    tickets:
      - key: PLAN-1
        title: Record the demo
        state: in_progress
      - key: PLAN-2
        title: Post the video
        blocked_by:
          - PLAN-1

location.py turns a source into the file, document.py reads and writes it
and knows its states and keys, schema.py describes a ticket, checks.py
decides whether a ticket takes a change, and store.py fills the Store
contract with them.
"""
