# Contributing to Island

Thanks for helping improve Island. Bug reports, small fixes, and focused feature
proposals are welcome.

## Before you start

Island targets Omarchy 4 and runs inside its Quickshell shell. Use a current
Omarchy installation for visual and runtime checks. The root `manifest.json`
defines the bar plugin; `companion/guilhermerisu.notifications/` contains the
separate notification service. Keep their IDs and entry points consistent with
the QML and shell commands that refer to them.

For a bug report, include the Omarchy version, the steps to reproduce, what you
expected, and what happened. Screenshots or short recordings help with visual
issues. Remove personal information from logs and screenshots before posting.

## Making a change

1. For broad changes to installation, removal, or user configuration, discuss
   the approach in an issue first.
2. Keep each pull request focused. Explain the behavior change and any new
   commands or dependencies.
3. Preserve user settings and local changes. When editing `shell.json` or menu
   overrides, keep unrelated entries intact and provide a clear removal path.
4. Do not edit Omarchy's packaged files under `/usr/share/omarchy/`. Use them as
   a reference only.

The main UI is in `Island.qml`, `components/`, and `views/`. Companion setup and
removal live in `companion/`. Update the README when a user-facing action,
dependency, or configuration path changes.

## Checking your work

From the repository root, run:

```sh
omarchy plugin validate .
omarchy plugin validate companion/guilhermerisu.notifications
bash -n companion/check.sh companion/install.sh companion/uninstall.sh
git diff --check
```

For visual changes, check the affected views in a running Omarchy session and
include a screenshot in the pull request. For setup or removal changes, test a
fresh install, a repeat run, and `companion/uninstall.sh --dry-run`. Confirm that
unrelated user configuration survives. Do not run destructive setup or removal
checks against a session with changes you cannot restore.

In the pull request, summarize what changed, how you checked it, and any known
limitations. Do not include credentials, notification history, or other personal
state in fixtures or screenshots.
