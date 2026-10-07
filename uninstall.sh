#!/bin/bash
# Removes omasyncro from this machine. Themes and wallpapers stay installed.
#   ./uninstall.sh           keep the local copy of the library
#   ./uninstall.sh --purge   also delete it (the GitHub repo is never touched)
units_dir="$HOME/.config/systemd/user"
systemctl --user disable --now omasyncro.socket omasyncro-active.path omasyncro.timer 2>/dev/null
for unit in omasyncro.socket omasyncro@.service omasyncro-active.path omasyncro-active.service omasyncro.timer omasyncro.service; do
  rm -f "$units_dir/$unit"
done
rm -rf "$units_dir/omasyncro.socket.d"
systemctl --user daemon-reload
rm -f "$HOME/.local/bin/omasyncro"
if [[ ${1:-} == --purge ]]; then
  rm -rf "$HOME/.local/share/omasyncro/data" "$HOME/.local/state/omasyncro"
fi
echo "omasyncro removed."
