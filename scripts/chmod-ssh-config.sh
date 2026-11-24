#!/usr/bin/env bash
set -euo pipefail

# Private keys: owner read/write only (600)
find ~/.ssh -maxdepth 1 -type f -name 'id_*' ! -name '*.pub' \
  -exec chmod 600 {} +

# Public keys: readable by everyone (644)
find ~/.ssh -maxdepth 1 -type f -name '*.pub' \
  -exec chmod 644 {} +

#chmod 600 ~/.ssh/config
#chmod 644 ~/.ssh/known_hosts