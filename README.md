# omasync

Keep every [Omarchy](https://omarchy.org) machine you own on the same page:

- **Same themes and wallpapers everywhere.** Install a theme or drop a wallpaper in
  `~/.config/omarchy/backgrounds/<theme>/` on one machine and the others get it.
- **Same active theme, live.** Switch theme or background on one machine and the others
  follow within a second or two.

Machines talk to each other directly over [Tailscale](https://tailscale.com). Your themes
list and wallpapers live in a private git repo of your own (the *library*), so a machine that
was off catches up when it comes back.

## Install

Needs Omarchy, Tailscale (logged in, same tailnet on every machine) and, for the zero-config
path, the GitHub CLI logged in (`gh auth login`).

```sh
git clone https://github.com/lordyoyi/omasync ~/.local/share/omasync/app
~/.local/share/omasync/app/install.sh
```

Run the same two lines on every machine. The first one creates a private
`<you>/omasync-data` repo on GitHub and fills it with what that machine has; the next ones
find it, install what they're missing and add what only they have. Nothing gets deleted by
installing.

Prefer another git host? Create an empty private repo there and pass its URL:
`install.sh git@example.com:me/omarchy-library.git`, using the same URL on every machine.

## Use

Nothing to do day to day. Change themes and wallpapers the usual Omarchy way.

| Command | What it does |
|---|---|
| `omasync status` | Library, active theme and every machine that answers |
| `omasync sync` | Sync the library now (`--update` also pulls every theme's repo) |
| `omasync remove <theme>` | Uninstall a theme on every machine |
| `omasync remove-bg <theme>/<file>` | Delete a wallpaper on every machine |

Deleting a theme or wallpaper the normal way only deletes it on that machine, and the next
sync brings it back. Use `remove` / `remove-bg` to delete it everywhere. The active theme
is never removed from under a machine.

Settings go in `~/.config/omasync/config`:

```sh
PORT=47123               # TCP port on the Tailscale interface
LIBRARY_INTERVAL_MIN=120 # full library sync interval (new local items go out within 5 min anyway)
AUTO_UPDATE=no           # yes: git pull omasync itself on every full sync
```

Log: `~/.local/state/omasync/log`. To uninstall, run `uninstall.sh` from the same folder
(`--purge` also deletes the local copy of the library; the GitHub repo is never touched).

## Security

omasync trusts the tailnet. **Every machine on your tailnet that runs omasync shares themes,
wallpapers and the active theme with the others.** There is no pairing or password on top of
Tailscale.

- It listens only on the machine's Tailscale address, never on your LAN or the internet.
- A peer can only ask for the active theme, propose a new one, or ask for a library sync.
  Theme names and paths are validated; nothing a peer sends is run as a command.
- Themes are third-party git repos. Anyone who can push to your library repo, and any machine
  on your tailnet running omasync, can get a theme cloned and applied on all your machines.
  Keep the library repo private and your tailnet to machines you trust.
- If you share your tailnet with other people, restrict TCP port 47123 to your own devices
  with [Tailscale ACLs](https://tailscale.com/kb/1018/acls).

## How it works

- **Library:** the data repo holds `themes.txt` (theme git URLs), `backgrounds/` (a mirror of
  `~/.config/omarchy/backgrounds/`) and `removed.txt` (what `remove` deleted). Syncing only
  adds; deletions travel as those tombstones.
- **Active theme:** a systemd path unit watches `~/.local/state/omarchy/current/`. On a
  change, omasync sends `<time> <machine> <theme> <background>` to every peer, and the newest
  wins everywhere. A new machine adopts what the others have instead of overriding them.
- **Peers:** every online Linux machine in `tailscale status` that answers on the port.
- **Catch-up:** a timer every 5 minutes, also right after resume, reconciles the active theme
  and pushes new local themes or wallpapers. A full library sync runs every 2 hours.

omasync uses Omarchy's own commands (`omarchy-theme-set`, `omarchy-theme-bg-set`) plus a few
of its internals (the `current/` state folder, the theme-set lock), so a big Omarchy change
can need an omasync update.

## License

MIT
