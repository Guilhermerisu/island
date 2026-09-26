#!/bin/bash
# Prints the state of the guilhermerisu.notifications companion as one word:
#   ok           installed, identical to this repo's copy, and enabled
#   missing      not installed in ~/.config/omarchy/plugins
#   outdated     installed but differs from this repo's copy
#   not-enabled  installed, but shell.json doesn't load it (or still loads
#                the stock omarchy.notifications alongside it)

here=$(cd "$(dirname "$0")" && pwd)
source_dir="$here/guilhermerisu.notifications"
target_dir="$HOME/.config/omarchy/plugins/guilhermerisu.notifications"
config="$HOME/.config/omarchy/shell.json"

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

echo ok
