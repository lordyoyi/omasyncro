# The library: which themes and extra wallpapers every machine has.
#
# The data repo holds themes.txt (git URLs), backgrounds/<theme>/<file> (a mirror
# of ~/.config/omarchy/backgrounds) and removed.txt (tombstones). Sync only
# adds: whatever any machine has ends up on all of them. Only `remove` and
# `remove-bg` delete, and their tombstones make the other machines delete too.

LIST="$DATA/themes.txt"
REMOVED="$DATA/removed.txt"
LIBRARY_STAMP="$STATE_DIR/library-synced"

# Same derivation as omarchy-theme-install, so a clone lands where
# `omarchy theme install` would have put it.
theme_name() {
  local path="${1%/}"
  [[ $path != *"://"* && $path == *:* && ${path%%:*} != */* ]] && path="${path#*:}"
  basename -- "$path" .git | sed -E 's/^omarchy-//; s/-theme$//' | tr '[:upper:]' '[:lower:]'
}

# github.com/x/y, github.com/x/y/ and github.com/x/y.git are the same repo.
norm_url() {
  local u="${1%/}"
  echo "${u%.git}"
}

valid_name() { (LC_ALL=C && [[ $1 =~ ^[a-z0-9_][a-z0-9._+-]*$ ]]); }

valid_bg() { [[ $1 == */* && $1 != *..* && $1 != /* ]]; }

git_data() { git -C "$DATA" "$@"; }

listed_name() {
  local url
  while read -r url; do
    [[ $(theme_name "$url") == "$1" ]] && return 0
  done <"$LIST"
  return 1
}

current_theme() { cat "$CURRENT/theme.name" 2>/dev/null; }

normalize_lists() {
  local url name seen=" "
  grep -v '^[[:space:]]*$' "$REMOVED" | sort -u >"$REMOVED.tmp"
  mv "$REMOVED.tmp" "$REMOVED"
  # One URL per theme name; the first one in sort order wins.
  while read -r url; do
    [[ -n $url ]] || continue
    url=$(norm_url "$url")
    name=$(theme_name "$url")
    [[ $seen == *" $name "* ]] && continue
    seen+="$name "
    echo "$url"
  done < <(sort -u "$LIST") >"$LIST.tmp"
  sort -f "$LIST.tmp" >"$LIST"
  rm -f "$LIST.tmp"
}

is_removed_theme() { grep -qxF "theme $1" "$REMOVED"; }

clear_tombstone() {
  grep -vxF "$1" "$REMOVED" >"$REMOVED.tmp"
  mv "$REMOVED.tmp" "$REMOVED"
}

# A theme cloned after its tombstone was committed is a deliberate reinstall.
reinstalled_since_removal() {
  local dir=$1 url=$2 t
  t=$(git_data log -1 --format=%ct -S"theme $url" -- removed.txt 2>/dev/null)
  (( ${t:-0} > 0 )) && (( $(stat -c %W "$dir" 2>/dev/null || echo 0) > t ))
}

pull() {
  git_data pull --rebase --autostash -q 2>>"$LOG" && return 0
  log "pull failed, continuing with the local copy"
  return 1
}

# Sets PUSHED=1 when something new reached the data repo.
push() {
  git_data add -A themes.txt removed.txt backgrounds
  git_data diff --cached --quiet && return 0
  git_data commit -q -m "${1:-Sync from $NAME}" || return 1
  if git_data push -q 2>>"$LOG" || { git_data pull --rebase -q 2>>"$LOG" && git_data push -q 2>>"$LOG"; }; then
    PUSHED=1
  else
    log "push failed, will retry on the next sync"
  fi
}

apply_tombstones() {
  local kind item name current
  current=$(current_theme)
  while read -r kind item; do
    case $kind in
      theme)
        name=$(theme_name "$item")
        valid_name "$name" && [[ -d $THEMES_DIR/$name ]] || continue
        if [[ $name == "$current" ]]; then
          log "not removing $name: it's the active theme here"
          continue
        fi
        reinstalled_since_removal "$THEMES_DIR/$name" "$item" && continue
        if [[ $(norm_url "$(git -C "$THEMES_DIR/$name" remote get-url origin 2>/dev/null)") == "$(norm_url "$item")" ]]; then
          rm -rf -- "${THEMES_DIR:?}/$name" && log "removed theme $name"
        fi
        ;;
      bg)
        valid_bg "$item" && [[ -f $BG_DIR/$item ]] || continue
        rm -f -- "$BG_DIR/$item" && log "removed wallpaper $item"
        ;;
    esac
  done <"$REMOVED"
}

install_missing_themes() {
  local url name
  while read -r url; do
    [[ -n $url ]] || continue
    name=$(theme_name "$url")
    valid_name "$name" || { log "skipping $url: unusable theme name"; continue; }
    [[ -d $THEMES_DIR/$name ]] && continue
    if git clone -q -- "$url" "$THEMES_DIR/$name" 2>>"$LOG"; then
      log "installed theme $name"
    else
      log "failed to clone $url"
    fi
  done <"$LIST"
}

record_local_themes() {
  local dir url name
  for dir in "$THEMES_DIR"/*/; do
    url=$(git -C "$dir" remote get-url origin 2>/dev/null) || continue
    name=$(basename "$dir")
    if is_removed_theme "$url"; then
      reinstalled_since_removal "$dir" "$url" || continue
      clear_tombstone "theme $url"
      log "$name was reinstalled, un-removing it"
    fi
    listed_name "$name" || { norm_url "$url" >>"$LIST"; log "added theme $name"; }
  done
}

bg_excludes() {
  local kind item
  while read -r kind item; do
    [[ $kind == bg ]] && printf -- '--exclude=/%s\n' "$item"
  done <"$REMOVED"
}

sync_backgrounds() {
  local excludes
  mapfile -t excludes < <(bg_excludes)
  mkdir -p "$DATA/backgrounds" "$BG_DIR"
  rsync -a --ignore-existing "${excludes[@]}" "$DATA/backgrounds/" "$BG_DIR/"
  rsync -a --ignore-existing "${excludes[@]}" "$BG_DIR/" "$DATA/backgrounds/"
}

# True when this machine has a git theme or a wallpaper the data repo lacks.
# Local only, no network: cheap enough for every tick.
library_dirty() {
  local dir excludes
  configured || return 1
  for dir in "$THEMES_DIR"/*/; do
    [[ -d $dir/.git ]] || continue
    listed_name "$(basename "$dir")" || return 0
  done
  mapfile -t excludes < <(bg_excludes)
  [[ -d $BG_DIR ]] || return 1
  [[ -n $(rsync -a --dry-run --ignore-existing --out-format='%n' "${excludes[@]}" "$BG_DIR/" "$DATA/backgrounds/" | grep -v '/$') ]]
}

library_due() {
  [[ ! -f $LIBRARY_STAMP ]] || [[ -n $(find "$LIBRARY_STAMP" -mmin "+$LIBRARY_INTERVAL_MIN") ]]
}

# Full sync. Returns with PUSHED=1 if peers should pull.
library_sync() {
  PUSHED=0
  configured || return 1
  lock_library || { log "library is busy"; return 1; }
  mkdir -p "$THEMES_DIR"
  touch "$LIST" "$REMOVED"
  pull && touch "$LIBRARY_STAMP"
  normalize_lists
  apply_tombstones
  install_missing_themes
  record_local_themes
  sync_backgrounds
  normalize_lists
  push
  unlock_library
}

update_themes() {
  local dir
  for dir in "$THEMES_DIR"/*/; do
    [[ -d $dir/.git ]] || continue
    git -C "$dir" pull -q --ff-only 2>/dev/null || log "could not update $(basename "$dir")"
  done
}

library_remove() {
  local name=$1 url u
  valid_name "$name" || die "invalid theme name: $name"
  [[ $name == "$(current_theme)" ]] && die "$name is the active theme, switch to another one first"
  lock_library || die "library is busy"
  pull
  url=$(git -C "$THEMES_DIR/$name" remote get-url origin 2>/dev/null)
  [[ -n $url ]] || url=$(while read -r u; do [[ $(theme_name "$u") == "$name" ]] && echo "$u"; done <"$LIST")
  [[ -n $url ]] || die "theme $name is not in the library"
  while read -r u; do
    [[ $(theme_name "$u") == "$name" ]] || echo "$u"
  done <"$LIST" >"$LIST.tmp"
  mv "$LIST.tmp" "$LIST"
  echo "theme $(norm_url "$url")" >>"$REMOVED"
  rm -rf -- "${THEMES_DIR:?}/$name"
  normalize_lists
  PUSHED=0
  push "Remove theme $name"
  unlock_library
  log "removed theme $name everywhere"
}

library_remove_bg() {
  local item=$1
  valid_bg "$item" || die "expected <theme>/<file>"
  lock_library || die "library is busy"
  pull
  rm -f -- "$BG_DIR/$item" "$DATA/backgrounds/$item"
  echo "bg $item" >>"$REMOVED"
  normalize_lists
  PUSHED=0
  push "Remove wallpaper $item"
  unlock_library
  log "removed wallpaper $item everywhere"
}
