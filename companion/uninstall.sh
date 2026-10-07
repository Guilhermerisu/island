#!/bin/bash
# Uninstalls Island: switches back to the stock bar, removes the notification
# companion (Omarchy's own notification service and OSD come back with it),
# cleans shell.json, takes out the Omarchy menu overrides that still point at
# the island, deletes ~/.config/hypr/island-bindings.lua and the line in
# hyprland.lua that loads it, removes the island plugin itself, and restarts
# the shell.
#
# Kept: ~/.config/omarchy/island.json (your settings) and keybindings you
# pointed at the island yourself, which are listed so you can restore them.
#
#   bash uninstall.sh            asks before removing anything
#   bash uninstall.sh --yes      no questions
#   bash uninstall.sh --dry-run  shows what it would do and changes nothing
set -euo pipefail

island_id="guilhermerisu.island"
companion_id="guilhermerisu.notifications"
plugins_dir="$HOME/.config/omarchy/plugins"
config="$HOME/.config/omarchy/shell.json"
menu="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
menu_ids=(style.theme style.background apps system trigger.emoji learn.keybindings)

assume_yes=false dry_run=false
for arg in "$@"; do
  case "$arg" in
    --yes | -y) assume_yes=true ;;
    --dry-run | -n) dry_run=true ;;
    -h | --help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "uninstall.sh: unknown option: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '• %s\n' "$*"; }
run() { if $dry_run; then printf '    would run: %s\n' "$*"; else "$@"; fi; }

if ! $assume_yes && ! $dry_run; then
  prompt="Uninstall Island? This removes $island_id and $companion_id from $plugins_dir."
  if [[ -t 0 && -t 1 ]] && command -v gum >/dev/null; then
    gum confirm "$prompt" || { echo "Cancelled."; exit 1; }
  else
    echo "$prompt Run again with --yes to confirm." >&2
    exit 1
  fi
fi

# 1. Back to the stock bar, while the island is still installed to hand over.
step "Switching back to the stock bar"
run omarchy bar use omarchy.bar

# 2. The notification companion; removing a clone restores the original.
if [[ -e $plugins_dir/$companion_id ]]; then
  step "Removing the notification companion"
  run omarchy plugin remove "$companion_id" --yes
fi

# 3. shell.json: drop the companion and stop disabling the stock service.
if [[ -f $config ]]; then
  step "Cleaning $config"
  filter='
    .plugins = ((.plugins // []) | map(select(.id != "'"$companion_id"'")))
    | .disabledPlugins = ((.disabledPlugins // []) | map(select(. != "omarchy.notifications" and . != "omarchy.osd")))'
  if $dry_run; then
    diff <(jq . "$config") <(jq "$filter" "$config") | sed 's/^/    /' || true
  else
    cp "$config" "$config.bak.$(date +%s)"
    tmp=$(mktemp "$config.XXXXXX")
    jq "$filter" "$config" >"$tmp" && mv "$tmp" "$config"
  fi
fi

# 4. Menu overrides, only the ones whose action still opens the island.
if [[ -f $menu ]]; then
  pattern=$(printf '%s|' "${menu_ids[@]}" | sed 's/\./\\./g; s/|$//')
  matches=$(grep -nE "^[[:space:]]*\"($pattern)\"[[:space:]]*:.*$island_id" "$menu" || true)
  if [[ -n $matches ]]; then
    step "Removing the island's entries from $menu"
    if $dry_run; then
      printf '%s\n' "$matches" | sed 's/^/    would remove line /'
    else
      cp "$menu" "$menu.bak.$(date +%s)"
      tmp=$(mktemp "$menu.XXXXXX")
      grep -vE "^[[:space:]]*\"($pattern)\"[[:space:]]*:.*$island_id" "$menu" >"$tmp" && mv "$tmp" "$menu"
      omarchy-menu refresh >/dev/null 2>&1 || true
    fi
  fi
fi

# 5. The keybindings file setup wrote, and its loader line in hyprland.lua.
if [[ -f $HOME/.config/hypr/island-bindings.lua ]]; then
  step "Removing ~/.config/hypr/island-bindings.lua"
  if $dry_run; then
    bash "$(dirname "$0")/bindings.sh" remove --dry-run
  else
    bash "$(dirname "$0")/bindings.sh" remove
  fi
fi

# 6. Keybindings of your own: list any that still open the island.
bindings=$(grep -nH "$island_id" "$HOME"/.config/hypr/*.lua 2>/dev/null | grep -v "/island-bindings.lua:" || true)
if [[ -n $bindings ]]; then
  step "These keybindings still open the island; restore them yourself:"
  printf '%s\n' "$bindings" | sed "s|$HOME|~|; s/^/    /"
fi

# 7. The island itself, last: this script lives inside it. Detached, so the
# removal and the shell restart outlive this process. `omarchy plugin remove`
# deletes a git checkout outright, so a checkout holding work that exists
# nowhere else (uncommitted changes, or commits not on its upstream) is kept.
island_dir="$plugins_dir/$island_id"
keep_reason=""
if [[ -d $island_dir/.git ]]; then
  if [[ -n $(git -C "$island_dir" status --porcelain 2>/dev/null) ]]; then
    keep_reason="it has uncommitted changes"
  elif ! git -C "$island_dir" rev-parse '@{u}' >/dev/null 2>&1; then
    keep_reason="its branch has no upstream to recover it from"
  elif [[ -n $(git -C "$island_dir" log '@{u}..' --oneline 2>/dev/null) ]]; then
    keep_reason="it has commits that aren't pushed"
  fi
fi
if [[ -n $keep_reason ]]; then
  step "Keeping $island_dir: $keep_reason. Remove it with: omarchy plugin remove $island_id"
  run setsid -f bash -c "exec </dev/null >/dev/null 2>&1; sleep 1; omarchy restart shell"
else
  step "Removing $island_id and restarting the shell"
  run setsid -f bash -c "exec </dev/null >/dev/null 2>&1; sleep 1; omarchy plugin remove '$island_id' --yes; omarchy restart shell"
fi

$dry_run && echo "Dry run: nothing was changed." || echo "Island uninstalled. Your settings are kept in ~/.config/omarchy/island.json."
