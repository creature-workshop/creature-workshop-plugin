#!/bin/sh

:<<'MODULE'
The gitlab adaptor, importable on its own: a caller that means gitlab reaches
gitlab_<op> without the forge facade. The contract is the @forge.gitlab plugin
beside this file, loaded here the way the facade loads it.
MODULE

import \
  "$SHELLOPS_DIR/lib/forge/base.sh" \
  "$SHELLOPS_DIR/lib/gitlab/gitlab.forge.op.sh"
forge__load_contract gitlab
