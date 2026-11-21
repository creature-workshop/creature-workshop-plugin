#!/bin/sh

:<<'MODULE'
The forgejo adaptor, importable on its own: a caller that means forgejo reaches
forgejo_<op> without the forge facade. The contract is the @forge.forgejo plugin
beside this file, loaded here the way the facade loads it.
MODULE

import \
  "$SHELLOPS_DIR/lib/forge/base.sh" \
  "$SHELLOPS_DIR/lib/forgejo/forgejo.forge.op.sh"
forge__load_contract forgejo
