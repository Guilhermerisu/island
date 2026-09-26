# Island for Omarchy

An Omarchy 4 bar plugin that replaces the stock bar with a floating,
morphing island at the top center of one monitor. It runs inside the
existing `omarchy-shell` Quickshell process and reserves no screen space.

## Features

- **Rest:** a small clock pill.
- **Notifications:** arrivals take over the pill in a Dynamic Island style:
  the notification image or app icon in a rounded tile, with the title and one
  line of body. Click the pill to dismiss the notification. Critical
  notifications stay until dismissed.
- **Volume:** volume and mute changes briefly show an Apple-style HUD: a
  speaker glyph that pops on each change and a thick level bar that springs
  to the new level.
- **Control center:** click the resting pill to open it. Two rows of toggle
  pills, each ending in a round button: Wi-Fi (or Ethernet), Focus (Do Not
  Disturb), and Lock; Bluetooth, Game Mode (Hyprland animations off until the
  next config reload), and Night Light. Below them, a Sound card with the
  volume slider and a › button that lists outputs to switch to, a Display
  card with brightness (only when the output supports it), and the recent
  notifications with per-item dismiss and "Clear all". Click outside the
  island to close it.
- **Theme switcher:** the island opens into a search field and a carousel of
  theme cards, each showing the theme's background and palette, with the
  active theme marked. Type to filter, ←/→ (or Tab, or the scroll wheel) to
  move, Enter or a click on the selected card to apply, Esc to close.
- **Wallpaper switcher:** the same picker, searchable by file name, showing the
  current theme's wallpapers (its `backgrounds/` folder plus
  `~/.config/omarchy/backgrounds/<theme>/`) as image cards, with the active
  one marked in the theme accent. The first and last cards sit flush with the
  edges.
- **Power menu:** Control Center–style tiles (icon over label) for Power Off,
  Reboot, Lock, Hibernate, and Suspend, with Lock selected when it opens; the
  selected tile fills with the theme accent. Suspend and Hibernate follow
  Omarchy's availability rules. ←/→ to move, Enter to run, Esc to close;
  clicking a tile runs it.
- **App launcher:** a search field over the list of apps (icon, name, and
  generic name or description), with the selected row marked by an accent
  bar. Uses the same apps, hidden entries, and ranking as Omarchy's own
  launcher. Type to filter, ↑/↓ (or Tab, PageUp/PageDown) to move, Enter or a
  click to launch, Esc to close.

## Install

1. Put this repository at `~/.config/omarchy/plugins/guilhermerisu.island`,
   with `omarchy plugin add <git-url>` or by copying it there.
2. In `~/.config/omarchy/shell.json`, set `bar.id` to `guilhermerisu.island`.
   Optionally set `bar.output` to a monitor name; it defaults to `DP-1` and
   falls back to the focused monitor, then the first output.
3. The pill turns amber and says "Set up notifications". Click it (or run
   `companion/install.sh`) to install the notification companion.

The installer:

1. Copies `companion/guilhermerisu.notifications` to
   `~/.config/omarchy/plugins/guilhermerisu.notifications`.
2. Backs up `shell.json` to `shell.json.bak.<timestamp>`.
3. Adds `guilhermerisu.notifications` to `plugins`, and `omarchy.notifications`
   (plus `oled.guard`, if installed) to `disabledPlugins`.
4. Points the Omarchy menu's Theme, Background, System, and Apps entries at
   the island, in `~/.config/omarchy/extensions/omarchy-menu.jsonc` (backed
   up first). Those entries are also what `SUPER + SHIFT + CTRL + SPACE`,
   `SUPER + CTRL + SPACE`, `SUPER + ESCAPE` (and the power key), and any key
   bound to `omarchy-menu toggle apps` open. An existing override of any of
   them is left alone.
5. Restarts the shell so the companion takes over as the notification server.

On every load the island runs `companion/check.sh`. If the companion is
missing, differs from this repository's copy, or isn't enabled, the pill turns
amber again ("Set up / Update / Enable notifications") and a click fixes it.
It does the same ("Set up switchers") when any of those menu entries isn't
set up yet.

### Restore the stock bar

Set `bar.id` to `omarchy.bar`, remove `omarchy.notifications` and `oled.guard`
from `disabledPlugins`, remove `guilhermerisu.notifications` from `plugins`,
and run `omarchy restart shell`. The installed companion folder can then be
deleted, and the `style.theme`, `style.background`, `system`, and `apps`
lines removed from
`~/.config/omarchy/extensions/omarchy-menu.jsonc`.

## IPC

```sh
omarchy-shell guilhermerisu.island toggle            # open/close the control center
omarchy-shell guilhermerisu.island themes            # open/close the theme switcher
omarchy-shell guilhermerisu.island wallpapers        # open/close the wallpaper switcher
omarchy-shell guilhermerisu.island power             # open/close the power menu
omarchy-shell guilhermerisu.island apps              # open/close the app launcher
omarchy-shell guilhermerisu.island close
omarchy-shell guilhermerisu.island showHistory       # opens the control center
omarchy-shell guilhermerisu.island companionStatus   # ok | missing | outdated | not-enabled
omarchy-shell guilhermerisu.island installCompanion
```

The companion keeps Omarchy's `notifications` IPC target (`toggleDnd`,
`dismissAll`, `clear`, …) and adds `dismissKey` and `invokeKey`.

## Customizing

- **Speed:** `motionScale` in `Island.qml` multiplies every animation
  duration. Raise it to slow the island down.
- **Colors:** the island is always black; its text, accent, and urgent
  colors follow the current Omarchy theme (from its `colors.toml`) and update
  live when you switch themes. On light themes the theme's background color is
  used for text so it stays readable on black. The palette is defined once at the top of
  `Island.qml`; the album-art card keeps light text over a dark scrim so it
  stays readable on any cover.

After editing, run `omarchy restart shell`. Hot reload does not reliably pick
up changes to `ControlCenter.qml`, and a plugin that fails to load leaves the
stock bar in place until the next restart.

### Smooth animations on NVIDIA

On NVIDIA, Qt falls back to its basic render loop, which advances animations
on a 16 ms timer, so the island animates at 60 Hz on any refresh rate. Use the
threaded render loop instead by adding this to `~/.config/hypr/hyprland.lua`,
then run `omarchy restart shell`:

```lua
hl.env("QSG_RENDER_LOOP", "threaded")
```

## Architecture

- `manifest.json` declares `guilhermerisu.island` as a `bar` plugin.
- `Island.qml` draws the island in an overlay `PanelWindow` whose input mask
  matches the visible island. It owns the pill, hover, notification, and
  feedback states, and the morph between them.
- `Picker.qml` is the shared switcher surface: search field, centered card
  carousel, keyboard handling, and selection. The island takes exclusive
  keyboard focus only while a switcher is open.
- `ThemeSwitcher.qml` lists the installed themes (user themes shadow stock
  ones), reads each one's background and six palette colors from its
  `colors.toml`, marks the active theme from `theme.name`, and applies with
  `omarchy-theme-set`.
- `WallpaperSwitcher.qml` lists the current theme's wallpapers, marks the one
  the `current/background` link points at, and applies with
  `omarchy-theme-bg-set`.
- `PowerMenu.qml` runs the same commands as Omarchy's System menu
  (`omarchy-system-lock`, `systemctl suspend`/`hibernate`,
  `omarchy-system-reboot`/`-shutdown`), detached, after closing the island.
- `AppLauncher.qml` lists desktop entries, filters out Omarchy's hidden
  entries (`launcher.hides` and `hidden-entries.sh`), ranks them with
  Omarchy's `AppSearch.js`, and launches with `uwsm-app -- gtk-launch`, like
  Omarchy's own launcher.
- `ControlCenter.qml` is the expanded panel. Night light and Do Not Disturb
  come from the shell's first-party services, audio from PipeWire, network
  and Bluetooth from Quickshell's `Networking` and `Bluetooth` modules, and
  Game Mode from `hyprctl eval`.
- `companion/guilhermerisu.notifications` is a clone of Omarchy 4.0.4's
  notification service. It keeps notification ownership, Do Not Disturb,
  persistence, history, and IPC, but draws no toasts. Instead it writes the
  active notifications to `~/.local/state/omarchy/island-feed.json`, which the
  island watches.

The companion is a separate, always-loaded plugin on purpose: notifications
keep working when the island fails to load or another bar is selected. Edit
it in `companion/` and rerun the installer rather than changing the installed
copy. When Omarchy updates its notification service, compare the stock
service with this clone and carry the changes over.

## Design references

- [Tide Island](https://github.com/enhaoswen/Tide-island): compact status
  feedback, eased surface morphs, and staged content reveal.
- [Impasto](https://github.com/andreumassanet/impasto): one central island
  that changes shape to host different surfaces.
- [Ukishima](https://github.com/amanhex/ukishima): a morphing pill with a
  shorter glide between resting and hover states.

The island is a native Omarchy bar option. It does not launch a second
Quickshell process or copy those projects' interface code.
