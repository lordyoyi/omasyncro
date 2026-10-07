#!/bin/bash
# Removes omasync from this machine. Themes and wallpapers stay installed.
#   ./uninstall.sh           keep the local copy of the library
#   ./uninstall.sh --purge   also delete it (the GitHub repo is never touched)
units_dir="$HOME/.config/systemd/user"
systemctl --user disable --now omasync.socket omasync-active.path omasync.timer 2>/dev/null
for unit in omasync.socket omasync@.service omasync-active.path omasync-active.service omasync.timer omasync.service; do
  rm -f "$units_dir/$unit"
done
rm -rf "$units_dir/omasync.socket.d"
systemctl --user daemon-reload
rm -f "$HOME/.local/bin/omasync"
if [[ ${1:-} == --purge ]]; then
  rm -rf "$HOME/.local/share/omasync" "$HOME/.local/state/omasync"
fi
echo "omasync removed."
