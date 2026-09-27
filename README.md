<div align="center">

# Island

<img src="assets/main.png" alt="Island running on the desktop" width="100%">

### A dynamic island for Omarchy

All Omarchy's menus rewritten as one fluid island.

[Install](#install) · [Features](#features) · [Uninstall](#uninstall) · [Controls](#controls)

</div>

<p align="center"><sub>Island uses your Omarchy theme colors.</sub></p>

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

## Screenshots

### Launcher and tools

<table>
  <tr>
    <td width="50%" align="center"><strong>App launcher</strong><br><img src="assets/launcher.png" alt="App launcher" width="100%"></td>
    <td width="50%" align="center"><strong>Ask AI</strong><br><img src="assets/launcher-ask.png" alt="Launcher with Ask AI" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>AI answer</strong><br><img src="assets/ai-answer.png" alt="AI answer in the island" width="100%"></td>
    <td align="center"><strong>Emoji picker</strong><br><img src="assets/emoji.png" alt="Emoji picker" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>Keybindings</strong><br><img src="assets/keybinds.png" alt="Keybinding search" width="100%"></td>
    <td align="center"><strong>Clipboard history</strong><br><img src="assets/clipboard.png" alt="Clipboard history" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>Clipboard copied</strong><br><img src="assets/clipboard-copied.png" alt="Clipboard copied notification" width="100%"></td>
    <td></td>
  </tr>
</table>

### Player and menus

<table>
  <tr>
    <td width="50%" align="center"><strong>Now playing</strong><br><img src="assets/media.png" alt="Now playing controls" width="100%"></td>
    <td width="50%" align="center"><strong>Omarchy menu</strong><br><img src="assets/menu.png" alt="Omarchy menu" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>Power menu</strong><br><img src="assets/power.png" alt="Power menu" width="100%"></td>
    <td align="center"><strong>Themes</strong><br><img src="assets/themes.png" alt="Theme browser" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>Wallpapers</strong><br><img src="assets/wallpapers.png" alt="Wallpaper browser" width="100%"></td>
    <td></td>
  </tr>
</table>

### Notifications and live activities

<table>
  <tr>
    <td width="50%" align="center"><strong>Notification</strong><br><img src="assets/notification.png" alt="Notification preview" width="100%"></td>
    <td width="50%" align="center"><strong>Claude notification</strong><br><img src="assets/notification-claude.png" alt="Claude notification" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>Codex notification</strong><br><img src="assets/notification-codex.png" alt="Codex notification" width="100%"></td>
    <td align="center"><strong>Update progress</strong><br><img src="assets/update.png" alt="System update progress" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>Update complete</strong><br><img src="assets/update-done.png" alt="System update complete" width="100%"></td>
    <td align="center"><strong>Download progress</strong><br><img src="assets/download.png" alt="Download progress" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>Download complete</strong><br><img src="assets/download-done.png" alt="Download complete" width="100%"></td>
    <td></td>
  </tr>
</table>

## Features

- **At rest:** a clock, or album art and an animated sound wave while music plays.
- **Live activities:** browser downloads and system updates (pacman, yay, paru,
  and Omarchy updates) show their progress on the pill.
- **Live feedback:** notification previews and animated volume and mute feedback.
- **Ask AI:** type a question in the launcher and Claude or Codex answers right in
  the island, Siri-style, using the command-line tool you're already signed in to.
- **Expanded views:** a control center, player, app launcher, clipboard history,
  emoji and keybinding search, theme and wallpaper switchers, Omarchy menu, and
  power menu.
- **Theme aware:** text and accent colors follow your current Omarchy theme.
- **Settings:** a pane in the control center for animation speed, a MacBook
  notch style, the clock, live activities, and the AI; saved to
  `~/.config/omarchy/island.json`.

Island runs inside Omarchy's Quickshell process and reserves no screen space.

## Install

Requires Omarchy 4 and its Quickshell shell.

```sh
omarchy plugin add https://github.com/Guilhermerisu/island.git
omarchy bar use guilhermerisu.island
```

On first launch, click the amber **Set up notifications** pill. It installs
Island's notification companion, connects supported Omarchy menu entries, and
restarts the shell.

## Uninstall

1. Switch back to the stock bar:

   ```sh
   omarchy bar use omarchy.bar
   ```

2. In `~/.config/omarchy/shell.json`, remove `guilhermerisu.notifications`
   from `plugins` and remove `omarchy.notifications` from `disabledPlugins`.
   Remove `oled.guard` from `disabledPlugins` too if it was enabled before
   Island was installed.
   Compare with the `shell.json.bak.<timestamp>` backup the setup script made.
3. In `~/.config/omarchy/extensions/omarchy-menu.jsonc`, remove the Island
   overrides for `style.theme`, `style.background`, `apps`, `system`,
   `trigger.emoji`, and `learn.keybindings` **only if their actions still point
   to Island**. The setup script also made a timestamped backup of this file.
   Restore any keybindings you changed manually.
4. Restart the shell and remove both plugins:

   ```sh
   omarchy restart shell
   omarchy plugin remove guilhermerisu.notifications
   omarchy plugin remove guilhermerisu.island
   ```


## Controls

| Action | Result |
| --- | --- |
| Click the clock | Open the control center. |
| Click album art or sound wave | Open the player. |
| Click a download or update | Open the file (or your Downloads folder). |
| Press Esc | Close the open view. |
