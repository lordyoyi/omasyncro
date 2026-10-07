#!/bin/bash
# Installs omasync for this user and sets this machine up. Safe to run again.
#   ./install.sh                 use (or create) <your GitHub user>/omasync-data
#   ./install.sh <git-url>       use this repo for the library instead
set -e
cd "$(dirname "$(readlink -f "$0")")"
for cmd in git jq rsync tailscale omarchy-theme-set; do
  command -v "$cmd" >/dev/null || { echo "omasync needs $cmd" >&2; exit 1; }
done
chmod +x bin/omasync
mkdir -p "$HOME/.local/bin"
ln -sf "$PWD/bin/omasync" "$HOME/.local/bin/omasync"
exec "$HOME/.local/bin/omasync" setup "$@"
