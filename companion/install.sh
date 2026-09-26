#!/bin/bash
# Installs (or updates) the guilhermerisu.notifications companion from this repo,
# enables it in shell.json in place of the stock notification service, points
# the Omarchy menu's Theme and Background entries at the island's switchers,
# and restarts
# the shell so the new notification server takes over.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
source_dir="$here/guilhermerisu.notifications"
plugins_dir="$HOME/.config/omarchy/plugins"
target_dir="$plugins_dir/guilhermerisu.notifications"
config="$HOME/.config/omarchy/shell.json"
menu="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

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

# Menu entries: SUPER+SHIFT+CTRL+SPACE runs `omarchy-menu toggle theme` and
# SUPER+CTRL+SPACE `omarchy-menu toggle background`, which resolve to
# style.theme and style.background. The menu merge resets omitted fields, so
# the icon, label, and aliases are repeated from Omarchy's default entries.
# An existing override of either entry is left alone.
menu_entries=(
  'style.theme|  "style.theme": {"icon":"󰸌","label":"Theme","aliases":["theme","themes"],"action":"omarchy-shell guilhermerisu.island themes"},'
  'style.background|  "style.background": {"icon":"","label":"Background","aliases":["background","wallpaper"],"action":"omarchy-shell guilhermerisu.island wallpapers"},'
)
if [[ ! -f $menu ]]; then
  mkdir -p "$(dirname "$menu")"
  printf '{\n}\n' >"$menu"
fi
backed_up=false
for spec in "${menu_entries[@]}"; do
  id=${spec%%|*} line=${spec#*|}
  grep -q "\"$id\"" "$menu" && continue
  if ! $backed_up; then cp "$menu" "$menu.bak.$(date +%s)"; backed_up=true; fi
  tmp=$(mktemp "$menu.XXXXXX")
  # Insert before the file's final closing brace.
  awk -v entry="$line" '
    { lines[NR] = $0 }
    /^[[:space:]]*}[[:space:]]*$/ { last = NR }
    END {
      for (i = 1; i <= NR; i++) {
        if (i == last) print entry
        print lines[i]
      }
    }' "$menu" >"$tmp"
  mv "$tmp" "$menu"
done
omarchy-menu refresh >/dev/null 2>&1 || true

# Detached: this script usually runs from inside the shell being restarted.
setsid -f omarchy restart shell >/dev/null 2>&1 </dev/null
echo installed
