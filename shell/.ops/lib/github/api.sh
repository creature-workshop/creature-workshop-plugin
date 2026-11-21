#!/bin/sh

:<<'MODULE'
The github adaptor, importable on its own: a caller that means github reaches
github_<op> without the forge facade. The contract is the @forge.github plugin
beside this file, loaded here the way the facade loads it.
MODULE

import \
  "$SHELLOPS_DIR/lib/forge/base.sh" \
  "$SHELLOPS_DIR/lib/github/github.forge.op.sh"
forge__load_contract github
