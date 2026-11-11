"""The checkout each chat session is on: the one answer that the pane, the
agent's tools, the terminal hook and the agent's own context all read.

A checkout is a worktree of a git repository, its main one or a linked one.
A session is on one checkout or on none. state.py decides which, from the
session's folder and the picks made for the session; picking.py makes a
pick, for the user in the pane or for the agent; and picks.py keeps the
picks, in files, because the pane's backend and the agent's tools do not
share memory.
"""
