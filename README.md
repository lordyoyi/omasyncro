# omasyncro

```
 ██████╗ ███╗   ███╗ █████╗ ███████╗██╗   ██╗███╗   ██╗ ██████╗██████╗  ██████╗
██╔═══██╗████╗ ████║██╔══██╗██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝██╔══██╗██╔═══██╗
██║   ██║██╔████╔██║███████║███████╗ ╚████╔╝ ██╔██╗ ██║██║     ██████╔╝██║   ██║
██║   ██║██║╚██╔╝██║██╔══██║╚════██║  ╚██╔╝  ██║╚██╗██║██║     ██╔══██╗██║   ██║
╚██████╔╝██║ ╚═╝ ██║██║  ██║███████║   ██║   ██║ ╚████║╚██████╗██║  ██║╚██████╔╝
 ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝

        ╭──────────────────╮                       ╭──────────────────╮
        │      ▄▄██▄▄      │                       │      ▄▄██▄▄      │
        │    ▄████████▄    │                       │    ▄████████▄    │
        │   ▀▀▀▀▀▀▀▀▀▀▀▀   │  <━━━━ tailnet ━━━━>  │   ▀▀▀▀▀▀▀▀▀▀▀▀   │
        │ ──────────────── │                       │ ──────────────── │
        │  ╱  ╱  ╱╲  ╲  ╲  │                       │  ╱  ╱  ╱╲  ╲  ╲  │
        ╰────────┬─────────╯                       ╰────────┬─────────╯
             ════╧════                                  ════╧════

                o n e   t h e m e ,   e v e r y   m a c h i n e
```

Keep every [Omarchy](https://omarchy.org) machine you own on the same page.
Switch the theme on your laptop and your desktop switches with it, a couple of
seconds later. Install a theme or drop a wallpaper on one machine and the others
get it too.

Machines talk to each other directly over [Tailscale](https://tailscale.com), so
it works at home, at the office or on the other side of the world. Your list of
themes and your wallpapers live in a private git repo of your own, so a machine
that was off or asleep catches up as soon as it is back.

**Status: working, lightly travelled.** It runs every day on the author's two
machines, a laptop and an always-on mini PC. A theme switch lands on the other
machine in about 3 seconds (most of it is Omarchy applying the theme), and a
background change in under 300 ms. It has not been tried by anyone else yet.

## What it does

- **Same active theme, live.** Change the theme or background on any machine,
  from Omarchy's menu or the command line, and every other machine follows. Any
  machine can lead; there is no "main" one.
- **Same themes everywhere.** Every theme installed from git on one machine gets
  installed on the others.
- **Same wallpapers everywhere.** Everything under
  `~/.config/omarchy/backgrounds/` is copied to every machine.
- **Deletes on request, never by accident.** Syncing only adds. To delete a
  theme or wallpaper on every machine, use `omasyncro remove` or `remove-bg`.
- **Catches up.** A machine that was off, asleep or offline gets the latest
  theme and anything new within 5 minutes of coming back.

## What it is not

- **Not a dotfiles syncer.** It does not touch your bar, Hyprland, keybindings,
  monitors or app configs. Only themes, wallpapers and the active theme.
- **Not for sharing with other people.** Every machine on your tailnet that
  runs omasyncro is treated as yours. See [Security](#security).
- **Not for themes without git.** A theme you made by hand inside
  `~/.config/omarchy/themes/` stays on that machine. Push it to a git repo and
  install it from there to share it.

## Requirements

- [Omarchy](https://omarchy.org) on every machine.
- [Tailscale](https://tailscale.com/download/linux), logged in to the same
  tailnet on every machine (`tailscale up`).
- A private git repo for your library. With the GitHub CLI logged in
  (`gh auth login`), omasyncro creates it for you.

`git`, `jq` and `rsync` come with Omarchy. Nothing needs root.

## Install

On your **first** machine:

1. Clone omasyncro:

   ```sh
   git clone https://github.com/lordyoyi/omasyncro ~/.local/share/omasyncro/app
   ```

2. Run the installer:

   ```sh
   ~/.local/share/omasyncro/app/install.sh
   ```

   It creates a private `<your-user>/omasyncro-data` repo on GitHub and fills it
   with this machine's themes and wallpapers. It ends by printing the status.

On **each other** machine, run the same two commands. The installer finds your
library, installs the themes and wallpapers the machine is missing, adds the
ones only it has, and switches to the theme your other machines are on. Nothing
is deleted by installing.

To check that everything is connected, run this on any machine:

```sh
omasyncro status
```

Every machine should be listed as `in sync`:

```
Library     https://github.com/you/omasyncro-data
Themes      12 from git, all installed
Wallpapers  8 extra
Active      synthwave84, starship_synthwave.png

Machines
  laptop      synthwave84         starship_synthwave.png            this one
  desktop     synthwave84         starship_synthwave.png            in sync
```

**Not using GitHub?** Create an empty private repo anywhere git can reach and
pass its URL to the installer on every machine:
`install.sh git@git.example.com:me/omarchy-library.git`.

## Everyday use

Nothing changes: switch themes and add wallpapers the usual Omarchy way.

| Command | What it does |
|---|---|
| `omasyncro status` | Your library, the active theme, and every machine that answers |
| `omasyncro sync` | Sync the library now instead of waiting (`--update` also pulls every theme's repo) |
| `omasyncro remove <theme>` | Uninstall a theme on every machine |
| `omasyncro remove-bg <theme>/<file>` | Delete a wallpaper on every machine |

Deleting a theme or wallpaper the normal way only deletes it on that machine,
and the next sync brings it back. Use `remove` / `remove-bg` to delete it
everywhere. A machine never deletes the theme it is currently using; it waits
until you switch.

Reinstalling a theme you removed brings it back on every machine.

## Configuration

Optional, in `~/.config/omasyncro/config`:

```sh
PORT=47123                # TCP port, on the Tailscale interface only
LIBRARY_INTERVAL_MIN=120  # minutes between full library syncs
AUTO_UPDATE=no            # yes: update omasyncro itself on every full sync
```

New local themes and wallpapers go out within 5 minutes regardless of
`LIBRARY_INTERVAL_MIN`; the full sync is the safety net.

## How it works

```
   laptop                     over Tailscale            desktop
  ┌────────────────────────┐   1. SET theme, wallpaper  ┌────────────────────────┐
  │ omarchy theme set ...  │ ━━━━━━━━━━━━━━━━━━━━━━━━━> │ omarchy-theme-set ...  │
  │ (path unit sees it)    │   2. PULL (new files)      │ (newest change wins)   │
  └───────────┬────────────┘ ━━━━━━━━━━━━━━━━━━━━━━━━━> └───────────┬────────────┘
              │ push                    git                         │ pull
              └─────────────────>  your private  <──────────────────┘
                                   library repo
```

- **The active theme** travels machine to machine. A systemd path unit watches
  `~/.local/state/omarchy/current/`; when the theme or background changes, the
  machine sends `<time> <machine> <theme> <background>` to every peer and the
  newest change wins everywhere. A newly installed machine adopts what the
  others have instead of overriding them.
- **The library** travels through git. The library repo holds `themes.txt`
  (theme git URLs), `backgrounds/` (a mirror of
  `~/.config/omarchy/backgrounds/`) and `removed.txt` (what `remove` deleted).
  When a machine pushes something new, it tells the others to pull right away.
  If you switch to a theme or wallpaper the others don't have yet, it is pushed
  before the switch is announced.
- **Peers** are found in `tailscale status`: every online Linux machine that
  answers on the port. There is no list to keep up to date.
- **Catch-up:** a timer every 5 minutes (and right after waking from sleep)
  compares the active theme with the other machines and sends out new local
  themes or wallpapers. A full library sync runs every 2 hours.

omasyncro uses Omarchy's own commands (`omarchy-theme-set`,
`omarchy-theme-bg-set`) and two of its internals: the `current/` state folder
and the theme-set lock. A big Omarchy change can need an omasyncro update.

## Security

omasyncro trusts your tailnet. **Every machine on your tailnet that runs
omasyncro shares themes, wallpapers and the active theme with the others.**
There is no pairing step and no password on top of Tailscale.

- It listens only on the machine's Tailscale address, never on your LAN or the
  internet. Nothing runs as root.
- A peer can do three things: ask for the active theme, propose a new one, or
  ask for a library sync. Theme names are validated, a requested background must
  be an image inside Omarchy's background or theme folders, and nothing a peer
  sends is run as a command.
- Themes are third-party git repos. Anyone who can push to your library repo,
  and any machine on your tailnet running omasyncro, can get a theme cloned and
  applied on all your machines. Keep the library repo private and your tailnet
  to machines you trust.
- If you share your tailnet with other people, restrict TCP port 47123 to your
  own devices with [Tailscale ACLs](https://tailscale.com/kb/1018/acls).

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Troubleshooting

**A machine is missing from `omasyncro status`.** Check that it is online in
`tailscale status` and that omasyncro is listening there:
`systemctl --user status omasyncro.socket`. If you run Tailscale with
`--netfilter-mode=off` and a firewall such as ufw, allow the port on the
Tailscale interface: `sudo ufw allow in on tailscale0 to any port 47123 proto tcp`.

**A theme switch did not reach a machine.** Look at its log:
`~/.local/state/omasyncro/log`. Each received change is a `from <machine>` line,
followed by anything Omarchy printed while applying it.

**A machine shows `out of sync`.** It catches up on its own within 5 minutes.
Waking from sleep or a network change can delay it once.

## Uninstall

```sh
~/.local/share/omasyncro/app/uninstall.sh
```

Your themes and wallpapers stay installed. `--purge` also deletes the local copy
of the library and omasyncro's state. Your library repo on GitHub is never
touched.

## Similar projects

[dupontbertrand/omasync](https://github.com/dupontbertrand/omasync) is an
Omarchy plugin that pushes a whole setup (theme, bar, Hyprland, plugins) from
one main machine to paired machines over the LAN, with SSH. Pick it if you want
one machine to drive the others and more than themes to follow. omasyncro covers
only themes and wallpapers, lets any machine lead, and works anywhere your
tailnet reaches.

## Development

```sh
test/run.sh
```

runs two simulated machines against a fake Omarchy, local theme repos and an
empty library repo, end to end. It never touches your real `~/.config` or
`~/.local`. Run it after every change. `CLAUDE.md` has the design decisions and
the reasons behind them.

## License

[MIT](LICENSE)
