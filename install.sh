#!/bin/bash
# Installs paw: a menu-bar pet showing which Claude Code / Codex sessions need you.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
REPO="${PAW_REPO:-https://github.com/inna-gelfer/claude-paw}"

# piped from curl: the sources aren't next to the script, so fetch them
if [ ! -f "$SRC/menubar.swift" ]; then
  SRC="$(mktemp -d)"
  echo "==> downloading paw"
  curl -fsSL "$REPO/archive/refs/heads/main.tar.gz" | tar xz -C "$SRC" --strip-components=1
fi

[ "$(uname)" = Darwin ] || { echo "paw is macOS only"; exit 1; }
command -v swiftc >/dev/null || { echo "need the Xcode command line tools: xcode-select --install"; exit 1; }
DIR="$HOME/.claude/paw"
mkdir -p "$DIR/icons" "$HOME/.claude/hooks"

cp "$SRC/menubar.swift" "$SRC/codex-notify.py" "$SRC/uninstall.sh" "$DIR/"
cp "$SRC"/icons/*.png "$DIR/icons/" 2>/dev/null || true
cp "$SRC/paw.py" "$HOME/.claude/hooks/paw.py"
chmod +x "$DIR/codex-notify.py" "$DIR/uninstall.sh" "$HOME/.claude/hooks/paw.py"
[ -f "$DIR/personas.json" ] || cp "$SRC/personas.json" "$DIR/"   # keep local edits
[ -f "$DIR/persona" ] || echo cat > "$DIR/persona"

echo "==> building menu bar app"
swiftc -O -o "$DIR/paw" "$DIR/menubar.swift"

echo "==> registering hooks in settings.json"
python3 - "$HOME" <<'PY'
import json, os, sys
p = os.path.join(sys.argv[1], ".claude", "settings.json")
s = json.load(open(p)) if os.path.exists(p) else {}
if os.path.exists(p):
    json.dump(s, open(p + ".paw-bak", "w"), indent=2)
h = s.setdefault("hooks", {})
for event, arg in [("Notification", "waiting"), ("Stop", "done"),
                   ("UserPromptSubmit", "working"), ("SessionEnd", "clear")]:
    kept = [e for e in h.get(event, []) if "paw.py" not in json.dumps(e)]
    kept.append({"matcher": "*", "hooks": [{"type": "command",
        "command": 'python3 "$HOME/.claude/hooks/paw.py" %s' % arg, "timeout": 10}]})
    h[event] = kept
json.dump(s, open(p, "w"), indent=2)
PY

CFG="$HOME/.codex/config.toml"
if [ -f "$CFG" ]; then
  echo "==> wiring codex notify"
  python3 - "$CFG" "$DIR" <<'PY'
import json, os, re, sys
cfg, d = sys.argv[1], sys.argv[2]
shim = os.path.join(d, "codex-notify.py")
s = open(cfg).read()
m = re.search(r'^notify = (\[.*\])$', s, re.M)
line = 'notify = ["python3", "%s", "turn-ended"]' % shim
# codex nests a previous notify program as an escaped JSON string, so drop every
# backslash before looking for ourselves - missing it chains paw to a program
# whose own --previous-notify calls paw back
if m and shim in m.group(1).replace("\\", ""):
    print("   already wired")
elif m:
    json.dump(json.loads(m.group(1)), open(os.path.join(d, "codex-chain.json"), "w"))
    open(cfg + ".paw-bak", "w").write(s)
    open(cfg, "w").write(s.replace(m.group(0), line))
    print("   chained to your existing notify program")
else:
    open(cfg, "a").write("\n" + line + "\n")
PY
fi

echo "==> starting menu bar app"
mkdir -p "$HOME/Library/LaunchAgents"
PLIST="$HOME/Library/LaunchAgents/com.paw.badge.plist"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.paw.badge</string>
  <key>ProgramArguments</key><array><string>$DIR/paw</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLISTEOF
launchctl bootout "gui/$UID/com.paw.badge" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"

command -v terminal-notifier >/dev/null || echo "!! brew install terminal-notifier  (for banners with click-to-jump)"
command -v herdr >/dev/null || echo "!! no herdr: sessions show their folder name, clicks raise the app not the tab"
echo "done — look top right. Menu > Persona to switch."
