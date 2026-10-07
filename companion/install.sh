#!/bin/bash
# Installs (or updates) the guilhermerisu.notifications companion from this repo,
# enables it in shell.json in place of the stock notification service, turns
# the stock OSD off so Omarchy's popups show on the island instead, points
# the Omarchy menu's Theme, Background, System, and Apps entries at the island,
# writes ~/.config/hypr/island-bindings.lua (see bindings.sh), and restarts the
# shell so the new notification server takes over.
#
# The shell reloads every plugin, the island included, as soon as anything
# changes in ~/.config/omarchy/plugins, so the companion is moved into place
# last. Progress goes to $status (running, done, or "failed <reason>"), which
# the island watches, so a reloaded island still knows setup is running and
# can say why it failed.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
source_dir="$here/guilhermerisu.notifications"
plugins_dir="$HOME/.config/omarchy/plugins"
target_dir="$plugins_dir/guilhermerisu.notifications"
config="$HOME/.config/omarchy/shell.json"
menu="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
status="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/island-setup"

mkdir -p "$(dirname "$status")"
printf 'running %s\n' "$(date +%s)" >"$status"
fail_reason=""
fail() {
  fail_reason="${*//$HOME/\~}"
  echo "install.sh: $*" >&2
  exit 1
}
finish() {
  local code=$?
  [[ ! -d ${staging:-} ]] || rm -rf -- "$staging"
  if (( code == 0 )); then echo done >"$status"; else printf 'failed %s\n' "${fail_reason:-setup stopped unexpectedly}" >"$status"; fi
}
trap finish EXIT
# Anything else that fails: its error is in the log beside the status file.
trap '[[ -n $fail_reason ]] || fail_reason="setup hit an unexpected error; details are in ${status//$HOME/\~}.log"' ERR

mkdir -p "$plugins_dir"
if [[ -L $target_dir || ( -e $target_dir && ! -d $target_dir ) ]]; then
  fail "$target_dir isn't a folder, so setup won't replace it"
fi
if [[ -e $target_dir/.git || -L $target_dir/.git ]]; then
  fail "$target_dir is a git checkout, so setup won't replace it"
fi

# Staged under a hidden name, which the shell's plugin watcher ignores.
staging=""
if [[ ! -d $target_dir ]] || ! diff -rq "$source_dir" "$target_dir" >/dev/null 2>&1; then
  staging=$(mktemp -d "$plugins_dir/.guilhermerisu.notifications.XXXXXX")
  cp -a "$source_dir/." "$staging/"
  omarchy-plugin-validate "$staging" || fail "the notification companion didn't pass Omarchy's plugin check"
fi

[[ -f $config ]] || echo '{}' >"$config"
jq -e 'type == "object"' "$config" >/dev/null 2>&1 || fail "$config isn't valid JSON"
cp "$config" "$config.bak.$(date +%s)"

disable='["omarchy.notifications","omarchy.osd"]'

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
# Omarchy's own parsing: whole-line // comments and trailing commas are
# stripped, then the rest must be a JSON object.
valid_menu() {
  perl -0pe 's#^\s*//[^\n]*(\n|$)##gm; s#,(\s*[}\]])#$1#g' "$1" | jq -e 'type == "object"' >/dev/null 2>&1
}
if [[ ! -f $menu ]]; then
  mkdir -p "$(dirname "$menu")"
  printf '{\n}\n' >"$menu"
fi
# A menu file Omarchy can't parse is the user's (and other tools') to fix, so
# leave it alone and finish the rest of setup; the island asks for the fix.
menu_ok=true
if ! valid_menu "$menu"; then
  menu_ok=false
  echo "install.sh: $menu isn't valid JSONC (a missing closing brace or comma?)," \
    "so Omarchy ignores it; skipped the Island menu entries. Fix it, then click the island's setup pill." >&2
fi
backed_up=false
for spec in "${menu_entries[@]}"; do
  $menu_ok || break
  id=${spec%%|*} line=${spec#*|}
  grep -q "\"$id\"" "$menu" && continue
  if ! $backed_up; then menu_backup="$menu.bak.$(date +%s)"; cp "$menu" "$menu_backup"; backed_up=true; fi
  tmp=$(mktemp "$menu.XXXXXX")
  # Insert before the file's final closing brace, adding a comma to the entry
  # above it when that entry doesn't already end in one.
  awk -v entry="$line" '
    { lines[NR] = $0 }
    /^[[:space:]]*}[[:space:]]*$/ { last = NR }
    END {
      for (i = last - 1; i >= 1; i--) if (lines[i] !~ /^[[:space:]]*(\/\/.*)?$/) break
      if (i >= 1 && lines[i] !~ /[{,][[:space:]]*$/) sub(/[[:space:]]*$/, ",", lines[i])
      for (i = 1; i <= NR; i++) {
        if (i == last) print entry
        print lines[i]
      }
    }' "$menu" >"$tmp"
  mv "$tmp" "$menu"
done
# Omarchy drops every override in a menu file it can't parse (MenuModel.js
# strips whole-line // comments and trailing commas, then parses JSON), so
# put the original back rather than leave a broken file.
if $backed_up && ! valid_menu "$menu"; then
  cp "$menu_backup" "$menu"
  menu_restored=true
  echo "install.sh: couldn't add the Island entries to $menu; restored it from $menu_backup" >&2
fi
omarchy-menu refresh >/dev/null 2>&1 || true

bash "$here/bindings.sh" init

# Last: this is what makes the shell reload the island.
if [[ -n $staging ]]; then
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
    fail "couldn't move the notification companion into place; the previous copy was restored"
  fi
  staging=""
  [[ -z $backup ]] || echo "Previous notification companion saved at $backup"
fi

# Detached: this script usually runs from inside the shell being restarted.
setsid -f omarchy restart shell >/dev/null 2>&1 </dev/null
if ! $menu_ok || ${menu_restored:-false}; then echo "installed, but the Omarchy menu entries weren't added"; else echo installed; fi
