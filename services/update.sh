#!/bin/bash
# Updates the island with Omarchy's plugin updater, then restarts the shell.
# IslandUpdater runs it detached, since updating the plugin folder reloads the
# island (and would end this script with it). When the update can't go ahead,
# it works out why and tells the island (`updateFailed`), which shows it as a
# banner; a notification stands in when the island can't be reached.
#
# Usage: update.sh <plugin-folder>
#
# Everything runs from main, which bash reads in full before running it, so the
# update replacing this file mid-run can't change what runs.

main() {
  dir=$1
  id=${dir##*/}
  shown_dir=${dir/#$HOME/\~}
  export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -oBatchMode=yes}"

  cd "$dir" 2>/dev/null || { report "$shown_dir isn't there anymore."; return; }
  command -v omarchy-plugin-update >/dev/null ||
    { report "This Omarchy has no plugin updater. Update Omarchy, then try again."; return; }

  local before out
  before=$(git rev-parse HEAD 2>/dev/null)
  # A new HEAD means the update landed, even if a step after it (the plugin
  # rescan) complained.
  if out=$(omarchy-plugin-update "$id" --yes 2>&1) || [[ $(git rev-parse HEAD 2>/dev/null) != "$before" ]]; then
    omarchy restart shell
    return
  fi
  if [[ $out == *"cannot fast-forward"* ]] && rewritten; then
    # Same changes as GitHub's, under new hashes: take GitHub's, going back if
    # the new version doesn't pass the plugin check. checkout (not reset)
    # refuses to overwrite a file that isn't part of Island.
    local branch
    branch=$(git symbolic-ref -q --short HEAD)
    if move_to FETCH_HEAD; then
      if omarchy-plugin-validate . >/dev/null 2>&1; then
        omarchy-shell -q shell rescanPlugins
        omarchy restart shell
        return
      fi
      move_to "$before"
      out="failed validation"
    fi
  fi
  report "$(reason "$out")"
}

# Moves the checkout (its branch, if it's on one) to a commit, the way
# git checkout does: never over edits or untracked files.
move_to() {
  if [[ -n $branch ]]; then git checkout -q -B "$branch" "$1" 2>/dev/null
  else git checkout -q --detach "$1" 2>/dev/null
  fi
}

# Whether the checkout only falls behind because GitHub's history was
# rewritten (commit messages edited and force-pushed): it has commits GitHub
# doesn't, every one has a commit with the same changes on GitHub, and
# nothing's edited in the folder.
rewritten() {
  [[ -z $(git status --porcelain --untracked-files=no 2>/dev/null) ]] || return 1
  git rev-parse -q --verify FETCH_HEAD >/dev/null || return 1
  ! git merge-base --is-ancestor HEAD FETCH_HEAD 2>/dev/null || return 1
  local cherry
  cherry=$(git cherry FETCH_HEAD HEAD 2>/dev/null) || return 1
  [[ -n $cherry && $cherry != *"+ "* ]]
}

# Why omarchy-plugin-update failed, from its last message and the checkout.
reason() {
  local last=${1##*$'\n'}
  last=${last#omarchy-plugin-update: }
  case $last in
  "fetch failed"*)
    echo "Couldn't reach GitHub. Check the connection, then try again."
    ;;
  *"failed validation"*)
    echo "The new version didn't pass Omarchy's plugin check, so Island stayed as it was. Update Omarchy, then try again."
    ;;
  "cannot fast-forward"*)
    blocker
    ;;
  *)
    echo "${last:-omarchy plugin update stopped without saying why.}"
    ;;
  esac
}

# What keeps the checkout from moving to the version just fetched.
blocker() {
  local changed added f n in_way=()
  changed=$(git status --porcelain --untracked-files=no 2>/dev/null | cut -c4-)
  if [[ -n $changed ]]; then
    echo "You've changed $(names "$changed") in $shown_dir. Run git stash there to set the changes aside, then try again."
    return
  fi
  added=$(git diff --name-only --diff-filter=A HEAD FETCH_HEAD 2>/dev/null)
  while IFS= read -r f; do
    [[ -n $f && -e $f ]] && in_way+=("$f")
  done <<<"$added"
  if (( ${#in_way[@]} )); then
    echo "The new version adds $(names "$(printf '%s\n' "${in_way[@]}")"), which already exists in $shown_dir. Move it away, then try again."
    return
  fi
  if ! git merge-base --is-ancestor HEAD FETCH_HEAD 2>/dev/null; then
    n=$(git rev-list --count FETCH_HEAD..HEAD 2>/dev/null)
    if [[ $n == 1 ]]; then n="a commit that isn't"; else n="$n commits that aren't"; fi
    echo "Your copy in $shown_dir has $n on GitHub. Rebase or drop it, then try again."
    return
  fi
  echo "Your copy in $shown_dir can't move to the new version. Check it with git status there."
}

# "a", "a and b", or "a and 3 other files", from one name per line.
names() {
  local first n
  first=${1%%$'\n'*}
  n=$(grep -c . <<<"$1")
  if (( n == 1 )); then echo "$first"
  elif (( n == 2 )); then echo "$first and ${1#*$'\n'}"
  else echo "$first and $((n - 1)) other files"
  fi
}

report() {
  omarchy-shell "$id" updateFailed "$1" >/dev/null 2>&1 ||
    notify-send -a Island -i system-software-update "Island Update" "Couldn't update. $1"
}

main "$@"
