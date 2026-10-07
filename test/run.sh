#!/bin/bash
#
# End-to-end test: two fake machines (A and B) on localhost, a fake Omarchy,
# local git repos for themes and an empty data repo. Never touches the real
# ~/.config or ~/.local.
#
#   test/run.sh [workdir]    (default: a new temp dir, kept on failure)

set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T=${1:-$(mktemp -d)}
rm -rf "$T" && mkdir -p "$T"
FAILS=0
PIDS=()

cleanup() { ((${#PIDS[@]})) && kill "${PIDS[@]}" 2>/dev/null; }
trap cleanup EXIT

pass() { echo "  ok    $1"; }
fail() { echo "  FAIL  $1"; FAILS=$((FAILS + 1)); }

# check <description> <command...>: retries for up to 10 s.
check() {
  local desc=$1 i
  shift
  for i in $(seq 100); do
    "$@" &>/dev/null && { pass "$desc"; return; }
    sleep 0.1
  done
  fail "$desc"
}

# --- fake Omarchy -----------------------------------------------------------

OM="$T/omarchy"
mkdir -p "$OM/bin" "$OM/themes/tokyo-night/backgrounds"
touch "$OM/themes/tokyo-night/backgrounds/"{1,2}.png

cat >"$OM/bin/omarchy-theme-set" <<'EOF'
#!/bin/bash
c=$HOME/.local/state/omarchy/current
for d in "$HOME/.config/omarchy/themes/$1" "$OMARCHY_PATH/themes/$1"; do
  [[ -d $d ]] && break
done
[[ -d $d ]] || { echo "no theme $1"; exit 1; }
rm -rf "$c/theme" && cp -r "$d" "$c/theme" && rm -rf "$c/theme/.git"
echo "$1" >"$c/theme.name"
ln -nsf "$(ls "$c"/theme/backgrounds/* | head -n1)" "$c/background"
EOF
cat >"$OM/bin/omarchy-theme-bg-set" <<'EOF'
#!/bin/bash
ln -nsf "$(realpath "$1")" "$HOME/.local/state/omarchy/current/background"
EOF
printf '#!/bin/bash\necho 127.0.0.1\n' >"$OM/bin/tailscale"
printf '#!/bin/bash\nexit 0\n' >"$OM/bin/systemctl"
printf '#!/bin/bash\nexit 1\n' >"$OM/bin/gh"
chmod +x "$OM/bin/"*

# --- theme repos and an empty data repo -------------------------------------

make_theme() {
  local src="$T/src/omarchy-$1-theme"
  mkdir -p "$src/backgrounds"
  touch "$src/backgrounds/a.png" "$src/colors.toml"
  git -C "$src" init -q && git -C "$src" add -A &&
    git -C "$src" -c user.name=t -c user.email=t@t commit -q -m init
  echo "$src"
}
ALPHA=$(make_theme alpha)
BETA=$(make_theme beta)
git init -q --bare -b main "$T/data.git"

# --- machines -----------------------------------------------------------------

declare -A PORTS=([A]=47201 [B]=47202)

m() {
  local who=$1 other
  shift
  [[ $who == A ]] && other=B || other=A
  env HOME="$T/$who" XDG_RUNTIME_DIR="$T/$who/run" OMARCHY_PATH="$OM" \
    OMASYNCRO_NAME="$who" OMASYNCRO_PEERS="127.0.0.1:${PORTS[$other]}=$other" \
    GIT_CONFIG_GLOBAL=/dev/null "$@"
}
omasyncro() { local who=$1; shift; m "$who" "$ROOT/bin/omasyncro" "$@"; }

listen() {
  m "$1" socat "TCP-LISTEN:${PORTS[$1]},bind=127.0.0.1,fork,reuseaddr" \
    SYSTEM:"trap '' TERM HUP; exec $ROOT/bin/omasyncro serve" &>/dev/null &
  eval "PID_$1=$!"
  PIDS+=($!)
}

for who in A B; do
  H="$T/$who"
  mkdir -p "$H/.local/state/omarchy/current" "$H/.config/omarchy/themes" "$H/run"
  m "$who" "$OM/bin/omarchy-theme-set" tokyo-night
done
git clone -q "$ALPHA" "$T/A/.config/omarchy/themes/alpha"
git clone -q "$BETA" "$T/B/.config/omarchy/themes/beta"
mkdir -p "$T/A/.config/omarchy/backgrounds/alpha"
touch "$T/A/.config/omarchy/backgrounds/alpha/mine one.png"

theme_of() { [[ $(cat "$T/$1/.local/state/omarchy/current/theme.name") == "$2" ]]; }
bg_of() { [[ $(readlink "$T/$1/.local/state/omarchy/current/background") == *"$2" ]]; }
origin_of() { [[ $(cut -f2 "$T/$1/.local/state/omasyncro/active") == "$2" ]]; }

# --- scenarios ----------------------------------------------------------------

listen A
listen B
sleep 0.3

echo "Setup"
omasyncro A setup "file://$T/data.git" >/dev/null
check "A's theme is in the library" grep -q alpha "$T/A/.local/share/omasyncro/data/themes.txt"
check "A's wallpaper is in the library" test -f "$T/A/.local/share/omasyncro/data/backgrounds/alpha/mine one.png"
omasyncro B setup "file://$T/data.git" >/dev/null
check "B installed A's theme" test -d "$T/B/.config/omarchy/themes/alpha/.git"
check "B got A's wallpaper" test -f "$T/B/.config/omarchy/backgrounds/alpha/mine one.png"
check "A installed B's theme after B's PULL" test -d "$T/A/.config/omarchy/themes/beta/.git"

echo "Active theme"
m A "$OM/bin/omarchy-theme-set" alpha
omasyncro A changed
check "B follows A to alpha" theme_of B alpha
omasyncro B changed # B's own watcher firing after the apply
check "no echo back from B" origin_of A A

m B "$OM/bin/omarchy-theme-bg-set" "$T/B/.config/omarchy/backgrounds/alpha/mine one.png"
omasyncro B changed
check "A follows B's background change" bg_of A "alpha/mine one.png"

echo "New wallpaper set active right away"
touch "$T/A/.config/omarchy/backgrounds/alpha/fresh.png"
m A "$OM/bin/omarchy-theme-bg-set" "$T/A/.config/omarchy/backgrounds/alpha/fresh.png"
omasyncro A changed
check "B got the new file" test -f "$T/B/.config/omarchy/backgrounds/alpha/fresh.png"
check "B shows it" bg_of B "alpha/fresh.png"

echo "Wallpaper only on one machine"
touch "$T/B/only-b.png"
m B "$OM/bin/omarchy-theme-bg-set" "$T/B/only-b.png"
omasyncro B changed
sleep 1
check "A keeps its background" bg_of A "alpha/fresh.png"
omasyncro A changed
check "A keeps B's state instead of pushing its fallback" origin_of A B
check "B's state still comes from B" origin_of B B

echo "A peer cannot point the background outside Omarchy's folders"
touch "$T/A/secret.png"
printf 'SET\t%s\tB\talpha\t~/secret.png\n' "$(($(date +%s%3N) + 1000))" | m A "$ROOT/bin/omasyncro" serve >/dev/null
bg_of A "secret.png" && fail "A refused ~/secret.png" || pass "A refused ~/secret.png"
check "A logged the refusal" grep -q "outside Omarchy's folders" "$T/A/.local/state/omasyncro/log"

echo "Remove everywhere"
omasyncro A remove beta >/dev/null
check "beta gone on A" test ! -e "$T/A/.config/omarchy/themes/beta"
check "beta gone on B" test ! -e "$T/B/.config/omarchy/themes/beta"

echo "Peer offline, then catches up"
kill "$PID_B"
sleep 0.2
m A "$OM/bin/omarchy-theme-set" tokyo-night
omasyncro A changed
theme_of B alpha && pass "B still on alpha while offline" || fail "B still on alpha while offline"
listen B
sleep 0.3
omasyncro B tick
check "B caught up on tick" theme_of B tokyo-night

echo "New wallpaper dropped in a folder, picked up by tick"
touch "$T/B/.config/omarchy/backgrounds/alpha/dropped.png"
omasyncro B tick
check "A got the dropped wallpaper" test -f "$T/A/.config/omarchy/backgrounds/alpha/dropped.png"

echo "Status"
omasyncro A status | sed 's/^/  | /'

echo
if ((FAILS)); then
  echo "$FAILS failed. Work dir kept: $T"
  exit 1
fi
echo "All passed."
rm -rf "$T"
