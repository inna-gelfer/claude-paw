# paw 🐾

A menu-bar pet that tells you which Claude Code / Codex sessions need you.

- 🙀 a session is waiting on you · 😸 one finished · dimmed while they work · 😴 nothing pending
- Click a session in the menu to jump straight to its terminal tab
- The session you are currently looking at never badges — you are already on it
- Notification banners with sound, per persona
- 13 personas (cat, dog, ghost, duck, robot, plant, coffee, dragon, startrek, pinkybrain, ibp, memes, friends)

## Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/inna-gelfer/claude-paw/main/install.sh)"
```

Or clone and run `./install.sh`. Either way it builds the menu-bar app, registers the
Claude Code hooks, wires Codex if you use it, and starts the app via launchd (so it
comes back after a reboot). Re-run it to upgrade; it keeps your persona and edits.

Uninstall: `~/.claude/paw/uninstall.sh`.

## Requirements

| | |
|---|---|
| macOS | required — menu bar app is Swift/Cocoa, launchd, `lsappinfo` |
| Xcode command line tools | required to build (`xcode-select --install`) |
| python3 | required — ships with the command line tools |
| Claude Code | supported: badges on waiting / done / working |
| Codex CLI | supported: badges on turn end, chains to any `notify` you already had |
| `terminal-notifier` | optional (`brew install terminal-notifier`) — banners with click-to-jump and persona art; without it you get plain macOS notifications |
| [herdr](https://herdr.dev) | optional — real session titles and click-to-exact-tab; without it you get the folder name and the app is raised |

Linux and Windows are not supported.

## What it touches

| Path | |
|---|---|
| `~/.claude/paw/` | app, personas, per-session state |
| `~/.claude/hooks/paw.py` | the hook |
| `~/.claude/settings.json` | 4 hook entries (backed up to `.paw-bak`) |
| `~/.codex/config.toml` | `notify` line, only if the file exists (backed up to `.paw-bak`) |
| `~/Library/LaunchAgents/com.paw.badge.plist` | keeps the app running |

## Personas

Menu > Persona to switch. Edit `~/.claude/paw/personas.json` to add your own — one entry
per persona, an emoji per state (`waiting`/`working`/`done`/`idle`), a macOS `sound`, and
optional catchphrases. For real art instead of emoji add `"icon": "myname"` and drop
`~/.claude/paw/icons/myname-waiting.png` (square, transparent, ~128px).

## Troubleshooting

- **No icon in the menu bar** — `launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.paw.badge.plist`, or check the build succeeded.
- **No banners** — `brew install terminal-notifier`, and allow notifications for it in System Settings.
- **Sessions all show a folder name** — that's the no-herdr fallback, working as intended.
