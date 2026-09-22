// Menu-bar pet: which Claude/Codex sessions want you. Click one to jump to it.
import Cocoa

let dir = NSString(string: "~/.claude/paw").expandingTildeInPath
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

func json(_ path: String) -> [String: Any] {
    guard let d = FileManager.default.contents(atPath: path),
          let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
    return j
}

func persona() -> (String, [String: Any]) {
    let all = json(dir + "/personas.json")
    let name = (try? String(contentsOfFile: dir + "/persona", encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "cat"
    return (name, all[name] as? [String: Any] ?? [:])
}

struct Row { let state: String, name: String, at: Double, focus: String, file: String,
              pane: String, app: String }

let herdrBin = ["/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"]
    .first { FileManager.default.isExecutableFile(atPath: $0) }

/// The pane the user is actually looking at, or "" if herdr isn't around.
func focusedPane() -> String {
    guard let bin = herdrBin else { return "" }
    let p = Process()
    p.launchPath = bin
    p.arguments = ["pane", "list"]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    guard (try? p.run()) != nil else { return "" }
    let d = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let r = j["result"] as? [String: Any],
          let panes = r["panes"] as? [[String: Any]] else { return "" }
    return panes.first { $0["focused"] as? Bool == true }?["pane_id"] as? String ?? ""
}

func rows() -> [Row] {
    var out: [Row] = []
    for f in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
    where f.hasSuffix(".json") && f != "personas.json" {
        let j = json(dir + "/" + f)
        guard let s = j["state"] as? String else { continue }
        let agent = j["agent"] as? String ?? "claude"
        out.append(Row(state: s,
                       name: (j["name"] as? String ?? "?") + (agent == "claude" ? "" : " · " + agent),
                       at: j["at"] as? Double ?? 0, focus: j["focus"] as? String ?? "",
                       file: dir + "/" + f, pane: j["pane"] as? String ?? "",
                       app: j["app"] as? String ?? ""))
    }
    return out.sorted { $0.at > $1.at }
}

/// A session you are looking at right now is one you have already seen - drop it.
func visibleRows() -> [Row] {
    let all = rows()
    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    guard all.contains(where: { $0.app == front && !$0.pane.isEmpty }) else { return all }
    let focused = focusedPane()
    guard !focused.isEmpty else { return all }
    for r in all where r.pane == focused { try? FileManager.default.removeItem(atPath: r.file) }
    return all.filter { $0.pane != focused }
}

/// "5h" / "7d" from a window length in minutes.
func window(_ minutes: Int) -> String {
    minutes >= 1440 ? "\(minutes / 1440)d" : "\(minutes / 60)h"
}

func resetsAt(_ v: Any?) -> String {
    guard let epoch = v as? Double, epoch > 0 else { return "" }
    let d = Date(timeIntervalSince1970: epoch)
    let f = DateFormatter()
    f.dateFormat = d.timeIntervalSinceNow < 24 * 3600 ? "HH:mm" : "EEE HH:mm"
    return " · resets " + f.string(from: d)
}

/// Plan usage per agent. Claude's arrives on the statusline, codex's from its
/// session log - both stop updating when you stop using that agent, so a
/// reading older than a day is dropped rather than shown as current.
func usageRows() -> [String] {
    var out: [String] = []
    let c = json(dir + "/usage-claude.json")
    if let five = c["five"] as? Double, Date().timeIntervalSince1970 - (c["at"] as? Double ?? 0) < 86400 {
        var line = String(format: "claude   5h %.0f%%", five)
        if let week = c["week"] as? Double { line += String(format: " · 7d %.0f%%", week) }
        out.append(line + resetsAt(c["five_reset"]))
    }
    let x = json(dir + "/usage-codex.json")
    if let pct = x["pct"] as? Double, Date().timeIntervalSince1970 - (x["at"] as? Double ?? 0) < 86400 {
        let w = window(x["window"] as? Int ?? 10080)
        out.append(String(format: "codex    %@ %.0f%%", w, pct) + resetsAt(x["reset"]))
    }
    return out
}

func ago(_ t: Double) -> String {
    let m = Int((Date().timeIntervalSince1970 - t) / 60)
    return m < 1 ? "just now" : (m < 60 ? "\(m)m ago" : "\(m / 60)h ago")
}

func shell(_ cmd: String) {
    let p = Process()
    p.launchPath = "/bin/sh"
    p.arguments = ["-c", cmd]
    try? p.run()
}

func hex(_ h: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: h.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return NSColor(red: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

// The Starfleet delta, drawn as a path so it stays crisp at any menu-bar scale.
func delta(_ fill: NSColor) -> NSImage {
    let size: CGFloat = 18
    return NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let s = { (x: CGFloat, y: CGFloat) in NSPoint(x: x * size, y: y * size) }
        let p = NSBezierPath()
        p.move(to: s(0.50, 0.99))
        p.curve(to: s(0.97, 0.03), controlPoint1: s(0.58, 0.68), controlPoint2: s(0.80, 0.26))
        p.curve(to: s(0.50, 0.32), controlPoint1: s(0.82, 0.11), controlPoint2: s(0.65, 0.20))
        p.curve(to: s(0.03, 0.03), controlPoint1: s(0.35, 0.20), controlPoint2: s(0.18, 0.11))
        p.curve(to: s(0.50, 0.99), controlPoint1: s(0.20, 0.26), controlPoint2: s(0.42, 0.68))
        fill.setFill()
        p.fill()
        NSColor.black.setStroke()
        p.lineWidth = size * 0.025
        p.lineJoinStyle = .round
        p.stroke()
        let star = NSBezierPath()
        for i in 0..<10 {
            let r: CGFloat = i % 2 == 0 ? 0.20 : 0.082
            let a = CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 5
            let pt = s(0.50 + r * cos(a), 0.50 + r * sin(a))
            i == 0 ? star.move(to: pt) : star.line(to: pt)
        }
        star.close()
        NSColor.black.setFill()
        star.fill()
        return true
    }
}

// A persona can ship art as icons/<icon>-<state>.png; otherwise its emoji is used.
func art(_ skin: [String: Any], _ state: String) -> NSImage? {
    guard let icon = skin["icon"] as? String else { return nil }
    if icon == "delta" {
        let c = skin["colors"] as? [String: String] ?? [:]
        return delta(hex(c[state] ?? "#8E8E93"))
    }
    guard let img = NSImage(contentsOfFile: "\(dir)/icons/\(icon)-\(state).png") else { return nil }
    img.size = NSSize(width: 18, height: 18)
    return img
}

// How hard the badge nags while something is pending: off|blink|glow|loud.
// Opt-in, one word in ~/.claude/paw/attention. Menu > Attention to switch.
let levels = ["off", "blink", "glow", "loud"]
func attention() -> String {
    let v = (try? String(contentsOfFile: dir + "/attention", encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return levels.contains(v) ? v : "off"
}

var pending = false      // something wants you: drives blink, glow and the nag sound
var baseAlpha: CGFloat = 1
var lastNag: Double = 0
var glowWindows: [NSWindow] = []

/// A soft pulsing glow along the top edge of every screen, where the badge lives.
/// Click-through, so the menu bar underneath still works.
func glow(_ on: Bool) {
    guard on else {
        glowWindows.forEach { $0.orderOut(nil) }
        glowWindows = []
        return
    }
    guard glowWindows.count != NSScreen.screens.count else { return }
    glow(false)
    let (_, skin) = persona()
    let color = hex((skin["colors"] as? [String: String] ?? [:])["waiting"] ?? "#FF9500")
    for screen in NSScreen.screens {
        let h: CGFloat = 10
        let strip = NSRect(x: screen.frame.minX, y: screen.frame.maxY - h,
                           width: screen.frame.width, height: h)
        let w = NSWindow(contentRect: strip, styleMask: .borderless,
                         backing: .buffered, defer: false)
        w.level = .screenSaver
        w.backgroundColor = .clear
        w.isOpaque = false
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        let v = NSView(frame: NSRect(origin: .zero, size: strip.size))
        v.wantsLayer = true
        let g = CAGradientLayer()
        g.frame = v.bounds
        g.colors = [color.withAlphaComponent(0.8).cgColor, color.withAlphaComponent(0).cgColor]
        g.startPoint = CGPoint(x: 0.5, y: 1)
        g.endPoint = CGPoint(x: 0.5, y: 0)
        v.layer?.addSublayer(g)
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.25
        pulse.toValue = 0.85
        pulse.duration = 1.4
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        v.layer?.add(pulse, forKey: "pulse")
        w.contentView = v
        w.orderFrontRegardless()
        glowWindows.append(w)
    }
}

func updateBadge() {
    let (_, skin) = persona()
    let r = visibleRows()
    let counts = ["waiting", "done", "working"].map { s in r.filter { $0.state == s }.count }
    let live = counts[0] > 0 ? "waiting" : (counts[1] > 0 ? "done" : (counts[2] > 0 ? "working" : "idle"))
    let n = counts.first(where: { $0 > 0 }) ?? 0
    guard let b = item.button else { return }
    pending = live == "waiting" || live == "done"
    let mode = attention()
    baseAlpha = pending ? 1 : 0.55
    b.alphaValue = baseAlpha
    glow(pending && (mode == "glow" || mode == "loud"))
    // loud repeats the persona sound until you deal with it
    let now = Date().timeIntervalSince1970
    if pending, mode == "loud", now - lastNag > 20 {
        lastNag = now
        shell("afplay /System/Library/Sounds/\(skin["sound"] as? String ?? "Glass").aiff &")
    }
    if let image = art(skin, live) {
        b.image = image
        b.imagePosition = .imageLeading
        b.title = n > 1 ? " \(n)" : ""
    } else {
        b.image = nil
        b.title = (skin[live] as? String ?? "🐾") + (n > 1 ? String(n) : "")
    }
}

// Built only when the menu opens - rebuilding on a timer tears it down mid-click.
class Handler: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        let (pname, skin) = persona()
        menu.removeAllItems()
        for r in visibleRows() {
            let mi = NSMenuItem(title: "\(skin[r.state] as? String ?? "🐾") \(r.name) — \(ago(r.at))",
                                action: #selector(jump(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = [r.focus, r.file]
            menu.addItem(mi)
        }
        if menu.items.isEmpty {
            menu.addItem(NSMenuItem(title: "nothing pending", action: nil, keyEquivalent: ""))
        }
        let usage = usageRows()
        if !usage.isEmpty {
            menu.addItem(.separator())
            for u in usage {
                let mi = NSMenuItem(title: u, action: nil, keyEquivalent: "")
                mi.isEnabled = false
                menu.addItem(mi)
            }
        }
        menu.addItem(.separator())
        let pm = NSMenuItem(title: "Persona", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let all = json(dir + "/personas.json")
        for k in all.keys.sorted() {
            let s = all[k] as? [String: Any] ?? [:]
            let glyphs = ["waiting", "working", "done", "idle"]
                .map { s[$0] as? String ?? "" }.joined(separator: " ")
            let mi = NSMenuItem(title: "\(glyphs)  \(k)", action: #selector(setPersona(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = k
            mi.state = (k == pname) ? .on : .off
            sub.addItem(mi)
        }
        pm.submenu = sub
        menu.addItem(pm)
        let am = NSMenuItem(title: "Attention", action: nil, keyEquivalent: "")
        let asub = NSMenu()
        let now = attention()
        for l in levels {
            let mi = NSMenuItem(title: l, action: #selector(setAttention(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = l
            mi.state = (l == now) ? .on : .off
            asub.addItem(mi)
        }
        am.submenu = asub
        menu.addItem(am)
        let q = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        q.target = self
        menu.addItem(q)
    }

    // Jumping to a session counts as attending to it, so its badge clears.
    @objc func jump(_ sender: NSMenuItem) {
        guard let v = sender.representedObject as? [String] else { return }
        if !v[0].isEmpty { shell(v[0]) }
        try? FileManager.default.removeItem(atPath: v[1])
        updateBadge()
    }
    @objc func setPersona(_ sender: NSMenuItem) {
        try? (sender.representedObject as? String ?? "cat")
            .write(toFile: dir + "/persona", atomically: true, encoding: .utf8)
        updateBadge()
    }
    @objc func setAttention(_ sender: NSMenuItem) {
        try? (sender.representedObject as? String ?? "off")
            .write(toFile: dir + "/attention", atomically: true, encoding: .utf8)
        updateBadge()
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let handler = Handler()
let menu = NSMenu()
menu.delegate = handler
item.menu = menu

NSApplication.shared.setActivationPolicy(.accessory)
updateBadge()
Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in updateBadge() }
var blinkDim = false
Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
    let mode = attention()
    blinkDim = (pending && (mode == "blink" || mode == "loud")) ? !blinkDim : false
    item.button?.alphaValue = blinkDim ? 0.15 : baseAlpha
}
NSApplication.shared.run()
