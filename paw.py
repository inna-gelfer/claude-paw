#!/usr/bin/env python3
"""Attention badge: record this agent's state, name it, and pop a notification.

Fed by Claude Code hooks (JSON on stdin) and by the codex notify shim.
"""
import json, os, shutil, subprocess, sys, time

state = sys.argv[1] if len(sys.argv) > 1 else "done"
DIR = os.path.expanduser("~/.claude/paw")
# codex routes this through its computer-use client, whose PATH has no Homebrew -
# without the fallback the pane is never found and clicks land on the wrong tab
HERDR = shutil.which("herdr") or next(
    (p for p in ("/opt/homebrew/bin/herdr", "/usr/local/bin/herdr") if os.access(p, os.X_OK)), "")
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

def codex_usage():
    """Codex reports its own limits in its session log - newest one wins, 60s TTL."""
    out = os.path.join(DIR, "usage-codex.json")
    try:
        if time.time() - os.path.getmtime(out) < 60:
            return
    except OSError:
        pass
    sessions = os.path.expanduser(os.environ.get("CODEX_HOME", "~/.codex") + "/sessions")
    logs = []
    for root, _, files in os.walk(sessions):
        logs += [os.path.join(root, f) for f in files if f.endswith(".jsonl")]
    for log in sorted(logs, key=os.path.getmtime, reverse=True)[:5]:
        with open(log, "rb") as f:
            f.seek(max(0, os.path.getsize(log) - 512 * 1024))
            lines = [l for l in f.read().splitlines() if b'"rate_limits"' in l]
        for line in reversed(lines):
            try:
                r = json.loads(line)["payload"]["rate_limits"]["primary"]
                pct = r["used_percent"]
            except Exception:
                continue
            with open(out, "w") as f:
                json.dump({"pct": pct, "window": r.get("window_minutes"),
                           "reset": r.get("resets_at"), "at": time.time()}, f)
            return


try:
    codex_usage()
except Exception:
    pass  # usage is a nicety; never let it break the badge

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
    """This agent's pane - its live title names the session, its tab is the click target."""
    if not HERDR:
        return {}

    def ask(*args):
        # herdr reports errors on stderr and leaves stdout empty, so a failed step
        # must answer "nothing" - raising here would skip every fallback below
        try:
            out = subprocess.run([HERDR, *args], capture_output=True, timeout=5).stdout
            return json.loads(out).get("result") or {}
        except Exception:
            return {}

    try:
        # codex's notify chain carries the pane id of wherever its client was first
        # launched, which is usually long closed - a miss here is not the answer
        if pane_id:
            got = ask("pane", "get", pane_id).get("pane")
            if got:
                return got
        panes = ask("pane", "list").get("panes", [])
        for p in panes:
            if (p.get("agent_session") or {}).get("value") == key:
                return p
        here = hook.get("cwd") or os.getcwd()
        same = [p for p in panes if (p.get("foreground_cwd") or p.get("cwd")) == here]
        if len(same) == 1:
            return same[0]
        # codex panes report no session either, so take the codex agent that just
        # stopped working: finishing is what fired this notification
        if (hook.get("agent") or "") == "codex":
            done = [a for a in ask("agent", "list").get("agents", [])
                    if a.get("agent") == "codex" and a.get("agent_status") != "working"]
            if done:
                return max(done, key=lambda a: a.get("state_change_seq") or 0)
    except Exception:
        pass
    return {}


def workspace_label(ws_id):
    """Two panes can share a title; the space they sit in is what tells them apart."""
    if not HERDR or not ws_id:
        return ""
    try:
        out = subprocess.run([HERDR, "workspace", "list"], capture_output=True, timeout=3).stdout
        for w in json.loads(out)["result"]["workspaces"]:
            if w.get("workspace_id") == ws_id:
                return w.get("label") or ""
    except Exception:
        pass
    return ""


try:
    personas = json.load(open(os.path.join(DIR, "personas.json")))
    current = open(os.path.join(DIR, "persona")).read().strip()
except Exception:
    personas, current = {}, "cat"
skin = personas.get(current) or {"waiting": "🙀", "done": "😸", "sound": "Glass"}

pane = herdr_pane()
# Without HERDR_PANE_ID every codex session keys on "unknown" and they overwrite
# each other - once the pane is resolved, it is the identity.
if not hook.get("session_id") and pane.get("pane_id"):
    key = pane["pane_id"]
    path = os.path.join(DIR, key.replace(":", "-") + ".json")
title = pane.get("terminal_title_stripped") or os.path.basename(hook.get("cwd") or os.getcwd())
space = workspace_label(pane.get("workspace_id"))
name = "%s · %s" % (space, title) if space else title
# herdr can jump to the exact tab; elsewhere (GoLand, plain Terminal) just raise the app
app = os.environ.get("__CFBundleIdentifier") or GHOSTTY
# Raise the terminal first, then focus: activating an app restores its last-used
# window, which undoes a tab focus that ran before it.
focus = "open -b %s" % app
if pane.get("tab_id"):
    focus += "; %s tab focus %s >/dev/null 2>&1" % (HERDR, pane["tab_id"])

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
