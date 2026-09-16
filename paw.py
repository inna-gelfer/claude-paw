#!/usr/bin/env python3
"""Attention badge: record this agent's state, name it, and pop a notification.

Fed by Claude Code hooks (JSON on stdin) and by the codex notify shim.
"""
import json, os, shutil, subprocess, sys, time

state = sys.argv[1] if len(sys.argv) > 1 else "done"
DIR = os.path.expanduser("~/.claude/paw")
HERDR = shutil.which("herdr") or ""
GHOSTTY = "com.mitchellh.ghostty"

try:
    hook = json.load(sys.stdin)
except Exception:
    hook = {}
if hook.get("agent_id"):  # subagents share the main session's badge
    sys.exit(0)

pane_id = os.environ.get("HERDR_PANE_ID", "")
key = hook.get("session_id") or pane_id or "unknown"
path = os.path.join(DIR, key.replace(":", "-") + ".json")
os.makedirs(DIR, exist_ok=True)

if state == "clear":
    try:
        os.remove(path)
    except OSError:
        pass
    sys.exit(0)


def frontmost():
    """Bundle id of the app in front, via LaunchServices (needs no accessibility grant)."""
    try:
        out = subprocess.run('lsappinfo info -only bundleID "$(lsappinfo front)"',
                             shell=True, capture_output=True, timeout=2).stdout.decode()
        return out.split("=")[-1].strip().strip('"')
    except Exception:
        return ""


def herdr_pane():
    """This agent's pane — its live title names the session, its tab is the click target."""
    if not HERDR:
        return {}
    try:
        if pane_id:
            out = subprocess.run([HERDR, "pane", "get", pane_id], capture_output=True, timeout=3).stdout
            return json.loads(out)["result"]["pane"]
        out = subprocess.run([HERDR, "pane", "list"], capture_output=True, timeout=3).stdout
        for p in json.loads(out)["result"]["panes"]:
            if (p.get("agent_session") or {}).get("value") == key:
                return p
    except Exception:
        pass
    return {}


try:
    personas = json.load(open(os.path.join(DIR, "personas.json")))
    current = open(os.path.join(DIR, "persona")).read().strip()
except Exception:
    personas, current = {}, "cat"
skin = personas.get(current) or {"waiting": "🙀", "done": "😸", "sound": "Glass"}

pane = herdr_pane()
name = pane.get("terminal_title_stripped") or os.path.basename(hook.get("cwd") or os.getcwd())
# herdr can jump to the exact tab; elsewhere (GoLand, plain Terminal) just raise the app
app = os.environ.get("__CFBundleIdentifier") or GHOSTTY
focus = ("%s tab focus %s >/dev/null 2>&1; " % (HERDR, pane["tab_id"]) if pane.get("tab_id") else "")
focus += "open -b %s" % app

# already looking at this session? then it needs no badge and no banner
if pane.get("focused") and app == frontmost():
    try:
        os.remove(path)
    except OSError:
        pass
    sys.exit(0)

with open(path, "w") as f:
    json.dump({"state": state, "name": name, "at": time.time(), "focus": focus,
               "pane": pane.get("pane_id", ""), "app": app,
               "agent": hook.get("agent") or "claude"}, f)

if state == "working":
    sys.exit(0)

msg = hook.get("message") or skin.get(state[:4] + "_say") or state
title = "%s %s" % (skin.get(state, "🐾"), name)
notifier = shutil.which("terminal-notifier")
if notifier:
    cmd = [notifier, "-title", title, "-message", msg, "-group", key,
           "-sound", skin.get("sound", "Glass")]
    icon = os.path.join(DIR, "icons", "%s-%s.png" % (skin.get("icon"), state))
    if os.path.exists(icon):
        cmd += ["-contentImage", icon]
    cmd += ["-execute", focus]
    subprocess.run(cmd, capture_output=True)
else:
    subprocess.run(["osascript", "-e", 'display notification %s with title %s sound name "Glass"'
                    % (json.dumps(msg), json.dumps(title))], capture_output=True)
