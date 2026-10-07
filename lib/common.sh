# Paths, config and helpers shared by every omasyncro command.

OMASYNCRO_HOME="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

export OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}
export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH"

# User settings. Defaults here; overrides in ~/.config/omasyncro/config.
PORT=47123
AUTO_UPDATE=no
LIBRARY_INTERVAL_MIN=120
CONFIG_FILE="$HOME/.config/omasyncro/config"
# shellcheck source=/dev/null
[[ -f $CONFIG_FILE ]] && source "$CONFIG_FILE"
PORT=${OMASYNCRO_PORT:-$PORT}

DATA="${OMASYNCRO_DATA:-$HOME/.local/share/omasyncro/data}"
STATE_DIR="$HOME/.local/state/omasyncro"
LOG="$STATE_DIR/log"
RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}"
NAME=${OMASYNCRO_NAME:-$HOSTNAME}

THEMES_DIR="$HOME/.config/omarchy/themes"
BG_DIR="$HOME/.config/omarchy/backgrounds"
CURRENT="$HOME/.local/state/omarchy/current"

mkdir -p "$STATE_DIR"

log() {
  echo "[$(date '+%F %T')] $*" >>"$LOG"
  [[ -t 2 ]] && echo "$*" >&2
  return 0
}

die() {
  echo "omasyncro: $*" >&2
  exit 1
}

configured() { [[ -d $DATA/.git ]]; }

# Locks live on fixed fds so they can be closed for long-lived children
# (theme hooks detach with setsid and would otherwise hold them):
#   7 = library (data repo, themes, wallpapers)
#   8 = active theme state
# Always take 8 before 7, never the other way round.
lock_library() { exec 7>"$RUN_DIR/omasyncro-library.lock" && flock -w 300 7; }
unlock_library() { exec 7>&-; }
lock_active() { exec 8>"$RUN_DIR/omasyncro-active.lock" && flock -w 300 8; }
unlock_active() { exec 8>&-; }
