#!/usr/bin/env python3
"""Codex notify shim: forwards to whatever notify program was configured before, adds the badge."""
import json, os, subprocess, sys

DIR = os.path.dirname(os.path.abspath(__file__))
# install.sh records any pre-existing codex notify program here so it keeps working
chain = os.path.join(DIR, "codex-chain.json")
if os.path.exists(chain):
    try:
        prev = json.load(open(chain))
        if prev and os.path.exists(prev[0]):
            subprocess.Popen(prev + [sys.argv[-1]])  # prev carries its own flags; codex appends only the payload
    except Exception:
        pass

try:
    payload = json.loads(sys.argv[-1])
except Exception:
    payload = {}
msg = " ".join((payload.get("last-assistant-message") or "turn finished").split())[:120]
subprocess.run(["python3", os.path.expanduser("~/.claude/hooks/paw.py"), "done"],
               input=json.dumps({"message": msg, "agent": "codex"}).encode())
