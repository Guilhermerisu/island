<p align="center">
  <img src="assets/readme/hero.webp" alt="Island, the Dynamic Island for Omarchy: music on the island and the full player, a download, Claude Code at work, screen recording, headphones connecting, a timer, a meeting in 10 minutes, a notification, a finished system update, the weather and calendar addons, Control Center and editing it, and the Settings, Displays, and Agents pages" width="100%">
</p>

<p align="center">
  <a href="https://github.com/Guilhermerisu/island/stargazers"><img src="https://img.shields.io/github/stars/Guilhermerisu/island?style=flat-square&color=3a8a72" alt="GitHub stars"></a>
  <a href="https://github.com/Guilhermerisu/island/commits"><img src="https://img.shields.io/github/last-commit/Guilhermerisu/island?style=flat-square&color=3a8a72" alt="Last commit"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Guilhermerisu/island?style=flat-square&color=3a8a72" alt="License"></a>
</p>

<a id="install"></a>
<h2 align="center">Install</h2>

```sh
omarchy plugin add https://github.com/Guilhermerisu/island.git
omarchy bar use guilhermerisu.island
```

<br>

<a id="features"></a>
<h2 align="center">Features</h2>

<p align="center">
  <img src="assets/readme/activities.webp" alt="Live activities: the resting island with music, a download and a system update in progress, Claude Code at work, screen recording, Bluetooth headphones, an upcoming event, a call, a timer, volume, workspaces, low battery, notifications from an app and from Claude Code, copied text, Wi-Fi, charging, and a finished download and update" width="100%">
</p>

<br>

<p align="center">
  <img src="assets/readme/control.webp" alt="Control Center with quick controls, sound, and notifications, and the Island settings pane" width="100%">
</p>

<br>

<p align="center">
  <img src="assets/readme/menus.webp" alt="Every menu: app launcher, Omarchy menu, theme and wallpaper switchers, clipboard history, and emoji picker" width="100%">
</p>

<br>

<p align="center">
  <img src="assets/readme/addons.webp" alt="Addons: Claude Code at work on the island, collapsed and expanded, a Teams call, weather with an hourly forecast, a question asked from the launcher and the AI's answer in the island, a timer, a calendar with the day's events, and the Addons, Agents, Displays, and System Stats settings pages" width="100%">
</p>

<br>

<a id="faq"></a>
<h2 align="center">FAQ</h2>

<details>
<summary><b>Do my other Omarchy plugins still work?</b></summary>
<br>

Plugins that add their own panel, overlay, or menu keep working. Open the
Plugins view (Settings → Keybinds, or the Plugins addon) to enable one and open
it.

Plugins that add a **bar widget** can't be drawn in the island, but they still
open: Island keeps the third-party widgets of your `shell.json` bar layout alive
off screen, and their panel opens under the island, from the Plugins view or
from `omarchy-shell shell toggle <plugin-id>` bound to a key.
</details>

<details>
<summary><b>Can I turn off a live activity I don't want?</b></summary>
<br>

Yes. Each one has its own switch in Settings → Live Activities: Now Playing,
Play & Pause, Workspace Indicator, Downloads, Screen Recording, System Updates,
Bluetooth Devices, Network, Battery, Volume, Brightness, and Clipboard.
</details>

<details>
<summary><b>Can I change the keyboard shortcuts?</b></summary>
<br>

Yes. Open Settings → Keybinds, pick a shortcut, and press the new keys. An
addon's shortcuts are set in its options on the Addons page.
</details>

<details>
<summary><b>How does Island update?</b></summary>
<br>

Island checks GitHub shortly after the shell starts and then every six hours.
When a new version is out, the island shows **Island Update: A new version is
ready. Click to update.** Click it, and Island updates and restarts the shell.
This needs the plugin to be a git checkout, which `omarchy plugin add` gives
you, with no local changes.
</details>

<details>
<summary><b>Can it look like a MacBook notch?</b></summary>
<br>

Yes. Turn on **Notch Style** in Settings → General to attach the island to the
top edge of the screen.
</details>

<details>
<summary><b>How do I uninstall it?</b></summary>
<br>

```sh
bash ~/.config/omarchy/plugins/guilhermerisu.island/companion/uninstall.sh
```

It switches back to the stock bar, removes the notification companion
(Omarchy's own notifications come back), undoes the `shell.json` and Omarchy
menu changes the setup made, deletes `island-bindings.lua`, removes Island, and
restarts the shell.
</details>

<br>

<p align="center"><sub>Released under the <a href="LICENSE">MIT license</a>.</sub></p>
