<div align="center">

# Island

<img src="assets/island-preview.svg" alt="Illustration of Island's resting, music, and control center states" width="100%">

### A dynamic island for Omarchy

All Omarchy's menus rewritten as one fluid island.

[Install](#install) · [Features](#features) · [Setup](#setup) · [Controls](#controls)

</div>

<p align="center"><sub>The preview is an illustration. Island uses your Omarchy theme colors.</sub></p>

<table>
  <tr>
    <td width="50%" align="center">
      <strong>Now playing</strong><br>
      Album art, an animated sound wave, playback controls, and seeking.
    </td>
    <td width="50%" align="center">
      <strong>Control center</strong><br>
      Audio, network, Bluetooth, Focus, Night Light, and recent notifications.
    </td>
  </tr>
  <tr>
    <td align="center">
      <strong>Find things</strong><br>
      Apps, emoji, keybindings, clipboard history, and Omarchy menus.
    </td>
    <td align="center">
      <strong>Make it yours</strong><br>
      Browse themes and wallpapers from the island.
    </td>
  </tr>
</table>

## Install

Requires Omarchy 4 and its Quickshell shell.

```sh
omarchy plugin add https://github.com/Guilhermerisu/island.git
omarchy bar use guilhermerisu.island
```

On first launch, click the amber **Set up notifications** pill. It installs
Island's notification companion, connects supported Omarchy menu entries, and
restarts the shell.

## Features

- **At rest:** a clock, or album art and an animated sound wave while music plays.
- **Live feedback:** notification previews and animated volume and mute feedback.
- **Expanded views:** a control center, player, app launcher, clipboard history,
  emoji and keybinding search, theme and wallpaper switchers, Omarchy menu, and
  power menu.
- **Theme aware:** text and accent colors follow your current Omarchy theme.

Island runs inside Omarchy's Quickshell process and reserves no screen space.

## Controls

| Action | Result |
| --- | --- |
| Click the clock | Open the control center. |
| Click album art or sound wave | Open the player. |

