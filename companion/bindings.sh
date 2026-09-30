#!/bin/bash
# Island's keybindings file, ~/.config/hypr/island-bindings.lua, loaded by one
# line in hyprland.lua right after the user's own bindings.
#
#   bindings.sh init               write the file if it's missing, taking the
#                                  keys the user already uses for each action
#   bindings.sh list               id, label, keys, and command of every island action
#   bindings.sh bound              every live binding: keys, description, command
#   bindings.sh set <id> <keys>    bind an action ("" clears it)
#   bindings.sh reset              forget every change and match the keys again
#   bindings.sh remove [--dry-run] delete the file and its loader line
set -euo pipefail

file="$HOME/.config/hypr/island-bindings.lua"
hyprland="$HOME/.config/hypr/hyprland.lua"
loader='require("default.hypr.require_optional").module("hypr.island-bindings")'
prefix="omarchy-shell guilhermerisu.island"

# id|label|island command|Omarchy default keys|stock commands that do the same
catalog=(
  'menu|Omarchy menu|show menu|SUPER + SPACE|omarchy-menu toggle;omarchy-menu toggle root;omarchy-menu'
  'apps|App launcher|apps|SUPER + ALT + SPACE|omarchy-menu toggle apps'
  'keybinds|Keybindings|show keybinds|SUPER + K|omarchy-menu-keybindings;omarchy-menu toggle learn.keybindings'
  'emoji|Emoji|show emoji|SUPER + CTRL + E|omarchy-shell shell toggle omarchy.emojis;omarchy-menu toggle trigger.emoji'
  'clipboard|Clipboard|show clipboard|SUPER + CTRL + V|omarchy-shell shell toggle omarchy.clipboard'
  'themes|Themes|themes|SUPER + SHIFT + CTRL + SPACE|omarchy-menu toggle theme;omarchy-menu toggle style.theme'
  'wallpapers|Wallpapers|wallpapers|SUPER + CTRL + SPACE|omarchy-menu toggle background;omarchy-menu toggle style.background'
  'power|Power menu|power|SUPER + ESCAPE|omarchy-menu toggle system'
  'controls|Control center|toggle||'
  'player|Now playing|show player||'
  'settings|Island settings|show settings||'
  'plugins|Plugins|show plugins||'
  'tray|System tray|show tray||'
)

field() { local IFS='|'; local parts=($1); printf '%s' "${parts[$2]:-}"; }

# "super + ctrl + e", "SUPER CTRL + E" → "SUPER + CTRL + E"
normalize() {
  local words=() mods=() key="" w
  read -ra words <<<"${1//+/ }"
  for w in "${words[@]}"; do
    w=${w^^}
    case "$w" in
      CONTROL) w=CTRL ;;
      META | WIN | LOGO | MOD4) w=SUPER ;;
    esac
    case "$w" in SUPER | SHIFT | CTRL | ALT) mods+=("$w") ;; *) key=$w ;; esac
  done
  [[ -n $key ]] || return 0
  local out="" m
  for m in SUPER SHIFT CTRL ALT; do
    [[ " ${mods[*]} " == *" $m "* ]] && out+="$m + "
  done
  printf '%s%s' "$out" "$key"
}

# Every live binding as "keys<TAB>description<TAB>command", from Omarchy's own
# keybinding list. A list that can't be read counts as empty, so setup falls
# back to Omarchy's default keys instead of failing.
records() {
  bash -c 'set -- --print; source "$(command -v omarchy-menu-keybindings)" >/dev/null; output_binding_records' 2>/dev/null |
    while IFS=$'\t' read -r label _ arg; do
      [[ $label == *"→"* ]] || continue
      local keys=${label%%→*} description=${label#*→}
      keys=$(normalize "$keys")
      description=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$description")
      [[ -n $keys ]] && printf '%s\t%s\t%s\n' "$keys" "$description" "$arg"
    done || true
}

# The file's current keys, as "command<TAB>keys".
current() {
  [[ -f $file ]] || return 0
  sed -nE 's/^island\("([^"]*)", "[^"]*", "([^"]*)"\)$/\2\t\1/p' "$file"
}

declare -A keys_for
load_current() {
  local command keys spec
  while IFS=$'\t' read -r command keys; do
    for spec in "${catalog[@]}"; do
      if [[ $(field "$spec" 2) == "$command" ]]; then keys_for[$(field "$spec" 0)]=$keys; fi
    done
  done < <(current)
}

write_file() {
  local tmp spec id
  mkdir -p "$(dirname "$file")"
  tmp=$(mktemp "$file.XXXXXX")
  {
    echo "-- Island keybindings, written by Island's setup. Change them in Island's"
    echo "-- Settings → Keybinds; removing one gives the key back to Omarchy."
    echo "local function island(keys, description, command)"
    echo "  hl.unbind(keys)"
    echo "  o.bind(keys, description, \"$prefix \" .. command)"
    echo "end"
    echo
    for spec in "${catalog[@]}"; do
      id=$(field "$spec" 0)
      [[ -n ${keys_for[$id]:-} ]] || continue
      printf 'island("%s", "%s", "%s")\n' "${keys_for[$id]}" "$(field "$spec" 1)" "$(field "$spec" 2)"
    done
    echo
    echo "-- While Settings records a shortcut, the island switches to this submap so"
    echo "-- the keys reach it instead of running their bindings. Its one bind leaves it."
    echo 'hl.define_submap("island-record", function()'
    echo '  hl.bind("SUPER + SHIFT + CTRL + ALT + ESCAPE", hl.dsp.submap("reset"))'
    echo 'end)'
  } >"$tmp"
  mv "$tmp" "$file"
}

add_loader() {
  [[ -f $hyprland ]] || return 0
  grep -qF "$loader" "$hyprland" && return 0
  cp "$hyprland" "$hyprland.bak.$(date +%s)"
  local tmp
  tmp=$(mktemp "$hyprland.XXXXXX")
  awk -v loader="$loader" '
    { print }
    !done && /^[[:space:]]*require\("hypr\.bindings"\)/ { print loader; done = 1 }
    END { if (!done) print loader }' "$hyprland" >"$tmp"
  mv "$tmp" "$hyprland"
}

reload() { hyprctl reload >/dev/null 2>&1 || true; }

cmd_init() {
  [[ -f $file ]] && { add_loader; return 0; }
  local live spec id command keys stock default
  live=$(records)
  for spec in "${catalog[@]}"; do
    id=$(field "$spec" 0)
    command="$prefix $(field "$spec" 2)"
    stock=$(field "$spec" 4)
    keys=$(awk -F '\t' -v own="$command" -v stock="$stock" '
      BEGIN { n = split(stock, list, ";"); for (i = 1; i <= n; i++) match_[list[i]] = 1; match_[own] = 1 }
      $1 !~ /XF86/ && ($3 in match_) { print $1; exit }' <<<"$live")
    if [[ -z $keys ]]; then
      default=$(field "$spec" 3)
      if [[ -n $default ]] && ! grep -qxF "$default" < <(cut -f1 <<<"$live"); then keys=$default; fi
    fi
    keys_for[$id]=$keys
  done
  write_file
  add_loader
  reload
}

cmd_list() {
  load_current
  local spec id
  for spec in "${catalog[@]}"; do
    id=$(field "$spec" 0)
    printf '%s\t%s\t%s\t%s\n' "$id" "$(field "$spec" 1)" "${keys_for[$id]:-}" "$prefix $(field "$spec" 2)"
  done
}

known_id() {
  local spec
  for spec in "${catalog[@]}"; do [[ $(field "$spec" 0) == "$1" ]] && return 0; done
  echo "bindings.sh: unknown action: $1" >&2
  exit 1
}

cmd_set() {
  local id=$1 keys spec other
  known_id "$id"
  keys=$(normalize "${2:-}")
  if [[ -n $keys && ! $keys =~ ^[A-Z0-9_+\ :]+$ ]]; then
    echo "bindings.sh: invalid keys: $2" >&2
    exit 1
  fi
  load_current
  for spec in "${catalog[@]}"; do
    other=$(field "$spec" 0)
    if [[ -n $keys && $other != "$id" && ${keys_for[$other]:-} == "$keys" ]]; then keys_for[$other]=""; fi
  done
  keys_for[$id]=$keys
  write_file
  add_loader
  reload
}

cmd_reset() {
  rm -f "$file"
  reload
  cmd_init
}

cmd_remove() {
  local dry=false
  [[ ${1:-} == "--dry-run" ]] && dry=true
  if $dry; then
    [[ -f $file ]] && echo "    would remove $file"
    [[ -f $hyprland ]] && grep -qF "$loader" "$hyprland" && echo "    would remove its loader line from $hyprland"
    return 0
  fi
  rm -f "$file"
  if [[ -f $hyprland ]] && grep -qF "$loader" "$hyprland"; then
    cp "$hyprland" "$hyprland.bak.$(date +%s)"
    local tmp
    tmp=$(mktemp "$hyprland.XXXXXX")
    grep -vxF "$loader" "$hyprland" >"$tmp" || true
    mv "$tmp" "$hyprland"
  fi
  reload
}

case "${1:-}" in
  init) cmd_init ;;
  list) cmd_list ;;
  bound) records ;;
  set) (( $# >= 2 )) || { echo "Usage: bindings.sh set <id> <keys>" >&2; exit 1; }; cmd_set "$2" "${3:-}" ;;
  reset) cmd_reset ;;
  remove) cmd_remove "${2:-}" ;;
  *) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
