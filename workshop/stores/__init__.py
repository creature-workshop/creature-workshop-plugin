"""The stores the pane's inspector reads and writes data through.

A store holds records, each `{id, revision, values}`, described by a JSON
Schema, and answers the operations of the Store contract in contract.py. A
store registers under a kind in registry.py, and the /store routes serve
every registered store the same way. What a store answers other than a plain
success is an outcome from outcomes.py, each with its HTTP status.
"""
