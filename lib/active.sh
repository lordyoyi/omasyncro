# The active theme and background, mirrored live between machines.
#
# State is one line: <epoch ms> <origin> <theme> <background>, tab separated,
# with $HOME written as ~ so the same value names the same file everywhere.
# The newest timestamp wins on every machine.

ACTIVE_STATE="$STATE_DIR/active"
THEME_SET_LOCK="$RUN_DIR/omarchy-theme-set.lock"

tilde() { [[ $1 == "$HOME"/* ]] && echo "~${1#"$HOME"}" || echo "$1"; }

local_bg() {
  local p
  # Resolved, the way omarchy-theme-bg-set stores it, so both ends compare equal.
  p=$(readlink -f "$CURRENT/background" 2>/dev/null) || return 0
  tilde "$p"
}

read_active() {
  A_TS=0 A_ORIGIN="" A_THEME="" A_BG=""
  [[ -s $ACTIVE_STATE ]] && IFS=$'\t' read -r A_TS A_ORIGIN A_THEME A_BG <"$ACTIVE_STATE"
  [[ $A_TS =~ ^[0-9]+$ ]] || A_TS=0
}

active_line() { printf '%s\t%s\t%s\t%s' "$A_TS" "$A_ORIGIN" "$A_THEME" "$A_BG"; }

write_active() {
  A_TS=$1 A_ORIGIN=$2 A_THEME=$3 A_BG=$4
  active_line >"$ACTIVE_STATE.tmp" && echo >>"$ACTIVE_STATE.tmp" && mv "$ACTIVE_STATE.tmp" "$ACTIVE_STATE"
}

theme_available() { [[ -d $THEMES_DIR/$1 || -d $OMARCHY_PATH/themes/$1 ]]; }

# True when a peer could not resolve the theme or wallpaper without a sync.
needs_library_for() {
  local theme=$1 bg=$2
  [[ -d $THEMES_DIR/$theme/.git ]] && ! listed_name "$theme" && return 0
  [[ $bg == "~/.config/omarchy/backgrounds/"* && ! -f $DATA/backgrounds/${bg#"~/.config/omarchy/backgrounds/"} ]]
}

# Applies a remote state; called with the active lock held. Every Omarchy
# command gets fds 7 and 8 closed so whatever it leaves behind can't hold them.
apply_active() {
  local theme=$1 bg=$2 path=${2/#\~/$HOME}

  if ! theme_available "$theme" || [[ -n $bg && ! -f $path ]]; then
    library_sync
  fi

  if [[ $theme != "$(current_theme)" ]]; then
    if ! theme_available "$theme"; then
      log "theme $theme is not available here, skipped"
      return
    fi
    omarchy-theme-set "$theme" 7>&- 8>&- >>"$LOG" 2>&1 || log "omarchy-theme-set $theme failed"
  fi

  if [[ -n $bg && $bg != "$(local_bg)" ]]; then
    if [[ -f $path ]]; then
      omarchy-theme-bg-set "$path" 7>&- 8>&- >>"$LOG" 2>&1 || log "omarchy-theme-bg-set failed"
    else
      log "background $bg is not on this machine, kept the theme's"
    fi
  fi
}

# offer <ms> <origin> <theme> <bg>: take a peer's state if it is newer.
active_offer() {
  local ts=$1 origin=$2 theme=$3 bg=$4
  [[ $ts =~ ^[0-9]+$ ]] && valid_name "$theme" && [[ $bg != *$'\n'* ]] || {
    log "ignored malformed state from $origin"
    return
  }
  lock_active || return
  read_active
  if (( ts > A_TS )); then
    log "from $origin: $theme $bg"
    apply_active "$theme" "$bg"
    # Record what actually got applied under the peer's timestamp. If something
    # was missing here, the watcher sees no local change and does not push this
    # machine's fallback back over the peer's choice.
    write_active "$ts" "$origin" "$(current_theme)" "$(local_bg)"
  fi
  unlock_active
}

# The watcher fired: if the theme or background changed here, tell the peers.
active_changed() {
  local theme bg
  # omarchy-theme-set rewrites current/ in several steps; wait for it.
  exec 6>"$THEME_SET_LOCK" && flock -w 30 6
  exec 6>&-

  lock_active || return
  read_active
  theme=$(current_theme)
  bg=$(local_bg)
  if [[ -z $theme || ($theme == "$A_THEME" && $bg == "$A_BG") ]]; then
    unlock_active
    return
  fi
  # First run on this machine: record what's here as older than anything a
  # peer has, so a new machine follows the others instead of overriding them.
  if (( A_TS == 0 )); then
    write_active 1 "$NAME" "$theme" "$bg"
    unlock_active
    return
  fi
  # Make sure peers can fetch a theme or wallpaper they don't have yet.
  if needs_library_for "$theme" "$bg"; then
    library_sync
    (( PUSHED )) && broadcast PULL
  fi
  write_active "$(date +%s%3N)" "$NAME" "$theme" "$bg"
  log "local: $theme $bg"
  unlock_active
  broadcast "SET"$'\t'"$(active_line)"
}

# Reconcile with every reachable peer; the newest state wins both ways.
active_hello() {
  local ip host reply ts origin theme bg
  active_changed
  while read -r ip host; do
    reply=$(send "$ip" GET) || continue
    IFS=$'\t' read -r ts origin theme bg <<<"$reply"
    [[ $ts =~ ^[0-9]+$ ]] || continue
    read_active
    if (( ts > A_TS )); then
      active_offer "$ts" "$origin" "$theme" "$bg"
    elif (( ts < A_TS )); then
      send "$ip" "SET"$'\t'"$(active_line)" >/dev/null
    fi
  done < <(peers)
}
