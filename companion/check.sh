#!/bin/bash
# Prints the state of the guilhermerisu.notifications companion as one word:
#   ok           installed, identical to this repo's copy, and enabled
#   missing      not installed in ~/.config/omarchy/plugins
#   outdated     installed but differs from this repo's copy
#   not-enabled  installed, but shell.json doesn't load it (or still loads
#                the stock omarchy.notifications alongside it)
#   menu-invalid the Omarchy menu extension isn't valid JSONC, so Omarchy
#                ignores it and setup can't add the island's entries to it
#   menu         the Omarchy menu's Theme, Background, Apps, System, Emoji, or Keybindings entry
#                (and the shortcuts that open them) doesn't open the island yet
#   bindings     ~/.config/hypr/island-bindings.lua hasn't been written yet

here=$(cd "$(dirname "$0")" && pwd)
source_dir="$here/guilhermerisu.notifications"
target_dir="$HOME/.config/omarchy/plugins/guilhermerisu.notifications"
config="$HOME/.config/omarchy/shell.json"
menu="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

if [[ ! -f $target_dir/manifest.json ]]; then
  echo missing
  exit 0
fi

if ! diff -rq "$source_dir" "$target_dir" >/dev/null 2>&1; then
  echo outdated
  exit 0
fi

if ! jq -e '
  ((.plugins // []) | map(.id) | index("guilhermerisu.notifications")) != null
  and ((.disabledPlugins // []) | index("omarchy.notifications")) != null
' "$config" >/dev/null 2>&1; then
  echo not-enabled
  exit 0
fi

if [[ -f $menu ]] && ! perl -0pe 's#^\s*//[^\n]*(\n|$)##gm; s#,(\s*[}\]])#$1#g' "$menu" |
  jq -e 'type == "object"' >/dev/null 2>&1; then
  echo menu-invalid
  exit 0
fi

# A user's own override of either entry is theirs to keep; only nag when a
# default entry is still in charge.
for entry in style.theme style.background apps system trigger.emoji learn.keybindings; do
  if ! grep -q "\"$entry\"" "$menu" 2>/dev/null; then
    echo menu
    exit 0
  fi
done

if [[ ! -f $HOME/.config/hypr/island-bindings.lua ]]; then
  echo bindings
  exit 0
fi

echo ok
