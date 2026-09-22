#!/usr/bin/env python3
"""Claude Code statusLine slot: record account usage, then run whatever
statusline was here before and pass its output straight through.

Claude Code hands the render JSON on stdin, and it carries rate_limits - the
only local source for plan usage. Cache idea and the freshness rule are lifted
from alchemmist/tmux-agent-usage (MIT).
"""
import json, os, subprocess, sys, time

DIR = os.path.expanduser("~/.claude/paw")
raw = sys.stdin.read()
try:
    limits = (json.loads(raw).get("rate_limits") or {})
except Exception:
    limits = {}

five, week = limits.get("five_hour") or {}, limits.get("seven_day") or {}
if isinstance(five.get("used_percentage"), (int, float)):
    new = {"five": five["used_percentage"], "five_reset": five.get("resets_at"),
           "week": week.get("used_percentage"), "week_reset": week.get("resets_at"),
           "at": time.time()}
    path = os.path.join(DIR, "usage-claude.json")
    try:
        old = json.load(open(path))
    except Exception:
        old = {}
    # An idle session re-renders the last snapshot it saw, so without this the
    # reading walks backwards: keep the later window, or the higher reading
    # within one window, since usage only climbs until the window resets.
    a, b = str(new["five_reset"] or ""), str(old.get("five_reset") or "")
    if (a > b) if a != b else (new["five"] >= (old.get("five") or 0)):
        with open(path, "w") as f:
            json.dump(new, f)

try:
    cmd = json.load(open(os.path.join(DIR, "statusline-original.json")))["command"]
except Exception:
    sys.exit(0)
subprocess.run(["bash", "-c", cmd], input=raw.encode())
