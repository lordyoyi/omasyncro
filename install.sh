#!/bin/bash
# Installs omasyncro for this user and sets this machine up. Safe to run again.
#   ./install.sh                 use (or create) <your GitHub user>/omasyncro-data
#   ./install.sh <git-url>       use this repo for the library instead
set -e
cd "$(dirname "$(readlink -f "$0")")"
for cmd in git jq rsync tailscale omarchy-theme-set; do
  command -v "$cmd" >/dev/null || { echo "omasyncro needs $cmd" >&2; exit 1; }
done
chmod +x bin/omasyncro
mkdir -p "$HOME/.local/bin"
ln -sf "$PWD/bin/omasyncro" "$HOME/.local/bin/omasyncro"
exec "$HOME/.local/bin/omasyncro" setup "$@"
