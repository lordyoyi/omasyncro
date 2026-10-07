# Security

## Reporting a vulnerability

Use GitHub's private vulnerability reporting:
**[Report a vulnerability](https://github.com/lordyoyi/omasyncro/security/advisories/new)**
(the Security tab of this repository). It reaches the maintainer without the
report being public first. Please do not open a public issue for a
vulnerability.

## The trust model

omasyncro trusts your tailnet: every machine on it that runs omasyncro is
treated as one of yours. Keep that in mind when reading the scope below.

## In scope

- A machine **outside** your tailnet reaching the omasyncro port.
- A peer making a machine do anything beyond the three things the protocol
  allows (report the active theme, apply a newer theme or background, sync the
  library). For example: running a command, reading or writing a file outside
  Omarchy's theme and background folders, or deleting something without a
  `remove` / `remove-bg` tombstone.
- A background path that escapes Omarchy's background and theme folders.
- The library repo being written somewhere other than the configured remote.

## Not a vulnerability here

- A machine on your own tailnet running omasyncro changing your theme, adding a
  theme to your library or asking for a sync. That is the feature. Restrict it
  with [Tailscale ACLs](https://tailscale.com/kb/1018/acls) if your tailnet
  includes devices that aren't yours.
- A theme from your library doing something unwanted when applied. Themes are
  third-party git repos applied by Omarchy itself; review a theme before you
  install it.
- Someone with push access to your library repo adding themes. Keep it private.
