#!/bin/bash
# Installs (or updates) the guilhermerisu.notifications companion from this repo,
# enables it in shell.json in place of the stock notification service, points
# the Omarchy menu's Theme, Background, System, and Apps entries at the island,
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
if [[ -L $target_dir || ( -e $target_dir && ! -d $target_dir ) ]]; then
  echo "Refusing to replace a non-directory companion: $target_dir" >&2
  exit 1
fi
if [[ -e $target_dir/.git || -L $target_dir/.git ]]; then
  echo "Refusing to replace a git-managed companion: $target_dir" >&2
  exit 1
fi

if [[ ! -d $target_dir ]] || ! diff -rq "$source_dir" "$target_dir" >/dev/null 2>&1; then
  staging=$(mktemp -d "$plugins_dir/.guilhermerisu.notifications.XXXXXX")
  trap '[[ ! -d ${staging:-} ]] || rm -rf -- "$staging"' EXIT
  cp -a "$source_dir/." "$staging/"
  omarchy-plugin-validate "$staging"

  backup=""
  if [[ -d $target_dir ]]; then
    base="$plugins_dir/.guilhermerisu.notifications.bak.$(date -u +%Y%m%d%H%M%S)"
    backup="$base"
    n=1
    while [[ -e $backup || -L $backup ]]; do
      backup="${base}-${n}"
      n=$((n + 1))
    done
    mv -- "$target_dir" "$backup"
  fi

  if ! mv -- "$staging" "$target_dir"; then
    [[ -z $backup ]] || mv -- "$backup" "$target_dir"
    echo "Could not install notification companion; previous copy restored." >&2
    exit 1
  fi
  staging=""
  [[ -z $backup ]] || echo "Previous notification companion saved at $backup"
fi

[[ -f $config ]] || echo '{}' >"$config"
cp "$config" "$config.bak.$(date +%s)"

disable='["omarchy.notifications"]'

tmp=$(mktemp "$config.XXXXXX")
jq --argjson disable "$disable" '
  .plugins = ((.plugins // []) | if map(.id) | index("guilhermerisu.notifications") then . else . + [{ id: "guilhermerisu.notifications" }] end)
  | .disabledPlugins = (((.disabledPlugins // []) + $disable) | unique)
' "$config" >"$tmp"
mv "$tmp" "$config"

# Menu entries: SUPER+SHIFT+CTRL+SPACE runs `omarchy-menu toggle theme`,
# SUPER+CTRL+SPACE `omarchy-menu toggle background`, SUPER+ESCAPE and the
# power key `omarchy-menu toggle system`, and `omarchy-menu toggle apps` (the
# menu's Apps row, or any key bound to it) resolves to apps; the menu's
# Emoji row resolves to trigger.emoji and its Learn → Keybindings row to
# learn.keybindings. The
# menu merge resets omitted fields, so the icon, label, and aliases are
# repeated from Omarchy's default entries. An existing override of any of
# them is left alone.
menu_entries=(
  'style.theme|  "style.theme": {"icon":"󰸌","label":"Theme","aliases":["theme","themes"],"action":"omarchy-shell guilhermerisu.island themes"},'
  'style.background|  "style.background": {"icon":"","label":"Background","aliases":["background","wallpaper"],"action":"omarchy-shell guilhermerisu.island wallpapers"},'
  'apps|  "apps": {"icon":"󰀻","label":"Apps","aliases":["app","applications"],"action":"omarchy-shell guilhermerisu.island apps"},'
  'system|  "system": {"icon":"","label":"System","aliases":["power-menu"],"action":"omarchy-shell guilhermerisu.island power"},'
  'trigger.emoji|  "trigger.emoji": {"icon":"","label":"Emoji","aliases":["emoji","emojis"],"action":"omarchy-shell guilhermerisu.island show emoji"},'
  'learn.keybindings|  "learn.keybindings": {"icon":"","label":"Keybindings","action":"omarchy-shell guilhermerisu.island show keybinds"},'
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
