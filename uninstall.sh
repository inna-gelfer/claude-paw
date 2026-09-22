#!/bin/bash
set -uo pipefail
launchctl bootout "gui/$UID/com.paw.badge" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.paw.badge.plist" "$HOME/.claude/hooks/paw.py"
python3 - "$HOME" <<'SL'
import json, os, sys
home = sys.argv[1]
p = os.path.join(home, ".claude", "settings.json")
s = json.load(open(p))
if "paw-status.py" in (s.get("statusLine") or {}).get("command", ""):
    orig = os.path.join(home, ".claude", "paw", "statusline-original.json")
    if os.path.exists(orig):
        s["statusLine"] = json.load(open(orig))
    else:
        s.pop("statusLine", None)
    json.dump(s, open(p, "w"), indent=2)
SL
rm -rf "$HOME/.claude/paw"
python3 - "$HOME" <<'PY'
import json, os, sys
p = os.path.join(sys.argv[1], ".claude", "settings.json")
s = json.load(open(p))
for e in list(s.get("hooks", {})):
    s["hooks"][e] = [x for x in s["hooks"][e] if "paw.py" not in json.dumps(x)]
    if not s["hooks"][e]:
        del s["hooks"][e]
json.dump(s, open(p, "w"), indent=2)
PY
echo "removed. codex config.toml: restore from its .paw-bak if you wired codex."
