# paw 🐾

A menu-bar pet that tells you which Claude Code / Codex sessions need you.

- 🙀 waiting on you · 😸 finished · dimmed while they work · 😴 nothing pending
- Click a session to jump straight to its terminal tab
- The session you're looking at never badges — you're already on it
- Notification banners with sound, per persona
- Plan usage for both agents, with reset times
- Optional attention levels, for when a menu-bar icon isn't enough
- 13 personas: cat, dog, ghost, duck, robot, plant, coffee, dragon, startrek, pinkybrain, ibp, memes, friends

## Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/inna-gelfer/claude-paw/main/install.sh)"
```

Or clone and run `./install.sh`. It builds the menu-bar app, registers the Claude Code
hooks, wires Codex if you use it, and starts the app via launchd so it survives a reboot.
Re-run it to upgrade — it keeps your personas and settings. Uninstall with
`~/.claude/paw/uninstall.sh`.

## Requirements

| | |
|---|---|
| macOS | required — Swift/Cocoa menu bar, launchd, `lsappinfo` |
| Xcode command line tools | required to build (`xcode-select --install`) |
| python3 | required — ships with the command line tools |
| Claude Code | badges on waiting / done / working |
| Codex CLI | badges on turn end, chains to any `notify` you already had |
| `terminal-notifier` | optional (`brew install terminal-notifier`) — banners with click-to-jump and persona art |
| [herdr](https://herdr.dev) | optional — real session titles, and clicks land on the exact tab |

Linux and Windows are not supported.

## Settings

All three live in the menu, and persist as a one-word file in `~/.claude/paw/`.

**Persona** — switch the emoji set and sound. Add your own to `personas.json`: an emoji per
state (`waiting`/`working`/`done`/`idle`), a macOS `sound`, optional catchphrases. For real
art, add `"icon": "myname"` and drop `icons/myname-waiting.png` (square, transparent, ~128px).

**Attention** — how hard it nags while something is pending. Off by default.

| | |
|---|---|
| `blink` | pulses the menu-bar icon |
| `glow` | pulses a soft band along the top edge of every screen, click-through |
| `loud` | glows, and repeats the persona sound every 20s |

**Show usage** — Claude's 5-hour and weekly windows and Codex's window, each with its reset
time. No API calls and no credentials: Claude's numbers arrive on the statusline payload,
Codex's come from its own session logs. Hiding the rows leaves the numbers updating underneath.

## What it touches

| Path | |
|---|---|
| `~/.claude/paw/` | app, personas, settings, per-session state |
| `~/.claude/hooks/paw.py` | the hook |
| `~/.claude/settings.json` | 4 hook entries and the `statusLine` slot — your existing status line is kept and still renders (backed up to `.paw-bak`) |
| `~/.codex/config.toml` | the `notify` line, only if the file exists (backed up to `.paw-bak`) |
| `~/Library/LaunchAgents/com.paw.badge.plist` | keeps the app running |

## Troubleshooting

- **No icon in the menu bar** — `launchctl kickstart -k gui/$UID/com.paw.badge`, or check the build succeeded.
- **No banners** — `brew install terminal-notifier`, then allow its notifications in System Settings.
- **Glow doesn't appear** — it only fires while a session is waiting or done, never while they work.
- **No usage numbers** — they land when each agent next runs: Claude on its next statusline render, Codex on its next turn. Readings over a day old are hidden rather than shown as current.
- **Sessions show a folder name, and clicks land on the wrong tab** — paw couldn't find herdr.
  Expected if it isn't installed; otherwise the hook ran with a PATH that lacks it.

## Credits

The plan-usage harvester follows [alchemmist/tmux-agent-usage](https://github.com/alchemmist/tmux-agent-usage)
(MIT) — same cache-and-chain approach, and its freshness rule for the stale snapshots idle
sessions replay.

[MIT](LICENSE).
