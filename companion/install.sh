#!/bin/bash
# Installs (or updates) the guilhermerisu.notifications companion from this repo,
# enables it in shell.json in place of the stock notification service, and
# restarts the shell so the new notification server takes over.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
source_dir="$here/guilhermerisu.notifications"
plugins_dir="$HOME/.config/omarchy/plugins"
target_dir="$plugins_dir/guilhermerisu.notifications"
config="$HOME/.config/omarchy/shell.json"

mkdir -p "$plugins_dir"
staging=$(mktemp -d "$plugins_dir/.guilhermerisu.notifications.XXXXXX")
cp -a "$source_dir/." "$staging/"
rm -rf "$target_dir"
mv "$staging" "$target_dir"

[[ -f $config ]] || echo '{}' >"$config"
cp "$config" "$config.bak.$(date +%s)"

disable='["omarchy.notifications"]'
# The OLED guard paints a full-width strip that is useless around the island.
[[ -d $plugins_dir/oled.guard ]] && disable='["omarchy.notifications", "oled.guard"]'

tmp=$(mktemp "$config.XXXXXX")
jq --argjson disable "$disable" '
  .plugins = ((.plugins // []) | if map(.id) | index("guilhermerisu.notifications") then . else . + [{ id: "guilhermerisu.notifications" }] end)
  | .disabledPlugins = (((.disabledPlugins // []) + $disable) | unique)
' "$config" >"$tmp"
mv "$tmp" "$config"

# Detached: this script usually runs from inside the shell being restarted.
setsid -f omarchy restart shell >/dev/null 2>&1 </dev/null
echo installed
