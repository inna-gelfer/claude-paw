# paw 🐾

A menu-bar pet that tells you which Claude Code / Codex sessions need you.

- 🙀 a session is waiting on you · 😸 one finished · dimmed while they work · 😴 nothing pending
- Click a session in the menu to jump straight to its terminal tab
- The session you are currently looking at never badges — you are already on it
- Notification banners with sound, per persona
- **Attention levels** (optional, off by default) — Menu > Attention:
  `blink` pulses the menu-bar icon · `glow` pulses a soft band along the top edge of every screen ·
  `loud` glows and repeats the persona sound every 20s until you deal with it.
  Only fires while something is actually pending, and the glow is click-through.
- **Plan usage** in the menu for both agents — Claude's 5-hour and weekly windows, Codex's
  window, each with the time it resets. No API calls: Claude's numbers ride in on the
  statusline payload, Codex's come from its own session logs.
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
| `~/.claude/paw/` | app, personas, attention level, per-session state |
| `~/.claude/hooks/paw.py` | the hook |
| `~/.claude/settings.json` | 4 hook entries and the `statusLine` slot (backed up to `.paw-bak`; your existing status line is kept and still renders) |
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
- **Glow doesn't appear** — it only shows while a session is waiting or done, never while they work.
- **No usage numbers** — they appear once each agent runs again: Claude's on the next statusline render, Codex's on its next turn. Readings over a day old are hidden rather than shown as current.
- **Sessions all show a folder name** — that's the no-herdr fallback, working as intended.

## Credits

The plan-usage harvester follows [alchemmist/tmux-agent-usage](https://github.com/alchemmist/tmux-agent-usage) (MIT) — same cache-and-chain approach, same freshness rule for the snapshots idle sessions replay.
