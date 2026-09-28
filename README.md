<div align="center">

# Island

<img src="assets/showcase-full.gif" alt="Island morphing between its views, live activities, and an AI answer" width="100%">

### A dynamic island for Omarchy

All Omarchy's menus rewritten as one fluid island.

[Features](#features) · [Screenshots](#screenshots) · [Install](#install) · [Usage](#usage) · [Uninstall](#uninstall)

</div>

## Features

- **At rest:** a clock, or album art and an animated sound wave while music plays.
- **Live activities:** browser downloads, system updates (pacman, yay, paru, and
  Omarchy updates), and anything you copy show up on the pill.
- **Live feedback:** notification previews and animated volume and mute feedback,
  with Claude Code and Codex notifications getting their own icons.
- **Ask AI:** type a question in the launcher and Claude or Codex answers right in
  the island, Siri-style, using the command-line tool you're already signed in to.
- **Expanded views:** a control center, player, app launcher, clipboard history,
  emoji and keybinding search, theme and wallpaper switchers, Omarchy menu, and
  power menu.
- **Theme aware:** text and accent colors follow your current Omarchy theme.
- **Settings:** a pane in the control center for animation speed, a MacBook
  notch style, the clock, live activities, and the AI.

Island runs inside Omarchy's Quickshell process and reserves no screen space.

## Screenshots

### The island

<table>
  <tr>
    <td width="50%" align="center"><strong>Island</strong><br><img src="assets/island.png" alt="The resting island with album art and a sound wave" width="100%"></td>
    <td width="50%" align="center"><strong>Now playing</strong><br><img src="assets/media.png" alt="Now playing player with controls" width="100%"></td>
  </tr>
</table>

### Notifications

<table>
  <tr>
    <td width="33%" align="center"><strong>Notification</strong><br><img src="assets/notification.png" alt="Notification preview" width="100%"></td>
    <td width="33%" align="center"><strong>Claude Code</strong><br><img src="assets/notification-claude.png" alt="Claude Code notification" width="100%"></td>
    <td width="33%" align="center"><strong>Codex</strong><br><img src="assets/notification-codex.png" alt="Codex notification" width="100%"></td>
  </tr>
</table>

### Personalization

<table>
  <tr>
    <td width="50%" align="center"><strong>Themes</strong><br><img src="assets/themes.png" alt="Theme switcher" width="100%"></td>
    <td width="50%" align="center"><strong>Wallpapers</strong><br><img src="assets/wallpapers.png" alt="Wallpaper switcher" width="100%"></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><strong>Power menu</strong><br><img src="assets/power.png" alt="Power menu" width="50%"></td>
  </tr>
</table>

### Launcher

<table>
  <tr>
    <td width="50%" align="center"><strong>App launcher</strong><br><img src="assets/launcher.png" alt="App launcher" width="100%"></td>
    <td width="50%" align="center"><strong>Omarchy menu</strong><br><img src="assets/menu.png" alt="Omarchy menu" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><strong>Ask AI</strong><br><img src="assets/launcher-ask.png" alt="Launcher with a question for the AI" width="100%"></td>
    <td align="center"><strong>Answer</strong><br><img src="assets/ai-answer.png" alt="The AI's answer in the island" width="100%"></td>
  </tr>
</table>

### Search

<table>
  <tr>
    <td width="50%" align="center"><strong>Emoji</strong><br><img src="assets/emoji.png" alt="Emoji picker" width="100%"></td>
    <td width="50%" align="center"><strong>Keybindings</strong><br><img src="assets/keybinds.png" alt="Keybinding search" width="100%"></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><strong>Clipboard history</strong><br><img src="assets/clipboard.png" alt="Clipboard history with an image preview" width="50%"></td>
  </tr>
</table>


### Live activities

<table>
  <tr>
    <td width="33%" align="center"><strong>Downloading</strong><br><img src="assets/download.png" alt="Download progress" width="100%"></td>
    <td width="33%" align="center"><strong>Downloaded</strong><br><img src="assets/download-done.png" alt="Download complete" width="100%"></td>
    <td width="33%" align="center"><strong>Updated</strong><br><img src="assets/update-done.png" alt="System update complete" width="100%"></td>
  </tr>
</table>

## Install

Requires Omarchy 4 and its Quickshell shell.

```sh
omarchy plugin add https://github.com/Guilhermerisu/island.git
omarchy bar use guilhermerisu.island
```

On first launch, click the amber **Click to Setup** pill. It installs
Island's notification companion, connects supported Omarchy menu entries, and
writes `~/.config/hypr/island-bindings.lua`, which points the keys you already
use for the menu, launcher, emoji, clipboard, and other views at the island.

## Usage

### Controls

| Action | Result |
| --- | --- |
| Click the clock | Open the control center. |
| Click album art or sound wave | Open the player. |
| Click a notification | Dismiss it. |
| Click a download or update | Open the file (or your Downloads folder). |
| Click the copied pill | Open the clipboard history. |
| Press Esc | Close the open view. |
| Super + Shift + Space | Hide or show the pill (notifications and views still appear). |

### Settings

Open the control center and click the gear. Changes apply right away and are
saved to `~/.config/omarchy/island.json`, which you can also edit by hand.
In Control Center, click the pencil to edit its cards. Drag cards to rearrange
them, click a minus badge to hide one, or use **Add Controls** to restore it.
Under **Keybinds**, click a shortcut's keys and type new ones to change it, or
press Backspace to remove it and give the key back to Omarchy. **Restore
Defaults** matches your keys again. These are saved to
`~/.config/hypr/island-bindings.lua`.

### Ask AI

Questions typed in the launcher are answered by the AI chosen under **Ask With**
in Settings, through its command-line tool:

- **Claude:** [Claude Code](https://claude.com/claude-code), signed in (`claude`).
- **Codex:** [Codex CLI](https://github.com/openai/codex), signed in (`codex`).

Choose **None** to turn asking and all AI features off.

## Uninstall

```sh
bash ~/.config/omarchy/plugins/guilhermerisu.island/companion/uninstall.sh
```

It switches back to the stock bar, removes the notification companion (Omarchy's
own notifications come back), undoes the `shell.json` and Omarchy menu changes
the setup made, deletes `island-bindings.lua`, removes Island, and restarts the
shell.

## License

[MIT](LICENSE)
