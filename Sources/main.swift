import AppKit
import QuartzCore

// MARK: - 尺寸与配色

var CELL: CGFloat = 4
var PAD: CGFloat = 8
var PET_W: CGFloat { 30 * CELL }
var PET_H: CGFloat { 21 * CELL }
var VIEW_W: CGFloat { PET_W + PAD * 2 }
var VIEW_H: CGFloat { PET_H + PAD * 2 }

let claudeOrange = NSColor(srgbRed: 204.0 / 255.0, green: 124.0 / 255.0, blue: 94.0 / 255.0, alpha: 1)
let claudeShadow = NSColor(srgbRed: 184.0 / 255.0, green: 106.0 / 255.0, blue: 79.0 / 255.0, alpha: 1)
let cream = NSColor(srgbRed: 248.0 / 255.0, green: 248.0 / 255.0, blue: 248.0 / 255.0, alpha: 1)
let ink = NSColor(srgbRed: 0.28, green: 0.18, blue: 0.14, alpha: 1)

/// 以「格子」为单位取矩形，原点在视图左下角。
func cellRect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> NSRect {
    NSRect(x: PAD + x0 * CELL, y: PAD + y0 * CELL, width: (x1 - x0) * CELL, height: (y1 - y0) * CELL)
}

// MARK: - 姿态

struct Particle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var maxLife: CGFloat
}

enum EyeStyle {
    case normal, happy, dizzy
}

struct Pose {
    var bob: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var tilt: CGFloat = 0
    var eyeOpen: CGFloat = 1
    var eyeWide: CGFloat = 1
    var eyeOffsetX: CGFloat = 0
    var eyeStyle: EyeStyle = .normal
    var armLeft: CGFloat = 0
    var armRight: CGFloat = 0
    var legLift: [CGFloat] = [0, 0, 0, 0]
}

// MARK: - 视图

final class PetView: NSView {
    weak var controller: PetController?
    var pose = Pose()
    var particles: [Particle] = []

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(false)
        drawPet(ctx)
        drawParticles(ctx)
    }

    private func drawPet(_ ctx: CGContext) {
        let p = pose
        ctx.saveGState()
        let ax = PAD + 16 * CELL
        let ay = PAD
        ctx.translateBy(x: ax, y: ay + p.bob)
        ctx.rotate(by: p.tilt)
        ctx.scaleBy(x: p.scaleX, y: p.scaleY)
        ctx.translateBy(x: -ax, y: -ay)

        // 腿（先画，被身体压住接缝）
        let legX: [(CGFloat, CGFloat)] = [(6.5, 8.5), (10.5, 12.5), (19.5, 21.5), (23.5, 25.5)]
        for (i, lx) in legX.enumerated() {
            let lift = p.legLift[i]
            ctx.setFillColor(claudeShadow.cgColor)
            ctx.fill(cellRect(lx.0, lift, lx.1, 4.4))
        }

        // 手臂（在身体后面）
        drawArm(ctx, side: -1, angle: p.armLeft)
        drawArm(ctx, side: 1, angle: p.armRight)

        // 身体
        ctx.setFillColor(claudeOrange.cgColor)
        ctx.fill(cellRect(4, 4, 28, 21))

        drawEyes(ctx)

        ctx.restoreGState()
    }

    private func drawArm(_ ctx: CGContext, side: CGFloat, angle: CGFloat) {
        let shoulderX = PAD + (side < 0 ? 5.0 : 27.0) * CELL
        let shoulderY = PAD + 15.5 * CELL
        ctx.saveGState()
        ctx.translateBy(x: shoulderX, y: shoulderY)
        ctx.rotate(by: angle * side)
        ctx.translateBy(x: -shoulderX, y: -shoulderY)
        ctx.setFillColor(claudeOrange.cgColor)
        if side < 0 {
            ctx.fill(cellRect(1.5, 13, 4.5, 17.5))
        } else {
            ctx.fill(cellRect(27.5, 13, 30.5, 17.5))
        }
        ctx.restoreGState()
    }

    private func drawEyes(_ ctx: CGContext) {
        let p = pose
        let eyeCenterY = PAD + 16 * CELL
        let eyeW: CGFloat = 2 * CELL
        let eyeH = max(1.2, 2 * CELL * p.eyeOpen * p.eyeWide)
        let dx = p.eyeOffsetX
        let centers: [CGFloat] = [PAD + 9.5 * CELL, PAD + 22.5 * CELL]

        switch p.eyeStyle {
        case .happy:
            ctx.setStrokeColor(cream.cgColor)
            ctx.setLineWidth(max(1.8, 0.55 * CELL))
            ctx.setLineCap(.square)
            for cx in centers {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: cx - eyeW / 2, y: eyeCenterY - 1.2))
                path.addLine(to: CGPoint(x: cx, y: eyeCenterY + 2.4))
                path.addLine(to: CGPoint(x: cx + eyeW / 2, y: eyeCenterY - 1.2))
                ctx.addPath(path)
                ctx.strokePath()
            }

        case .dizzy:
            ctx.setStrokeColor(cream.cgColor)
            ctx.setLineWidth(max(1.8, 0.5 * CELL))
            ctx.setLineCap(.square)
            let s = 0.55 * CELL
            for cx in centers {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: cx - s, y: eyeCenterY - s))
                path.addLine(to: CGPoint(x: cx + s, y: eyeCenterY + s))
                path.move(to: CGPoint(x: cx + s, y: eyeCenterY - s))
                path.addLine(to: CGPoint(x: cx - s, y: eyeCenterY + s))
                ctx.addPath(path)
                ctx.strokePath()
            }

        case .normal:
            ctx.setFillColor(cream.cgColor)
            for cx in centers {
                let r = NSRect(x: cx + dx - eyeW / 2,
                               y: eyeCenterY - eyeH / 2,
                               width: eyeW,
                               height: eyeH)
                ctx.fill(r)
            }
        }
    }

    private func drawParticles(_ ctx: CGContext) {
        let pattern: [[Int]] = [
            [0, 1, 1, 0, 1, 1, 0],
            [1, 1, 1, 1, 1, 1, 1],
            [0, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 1, 0, 0],
            [0, 0, 0, 1, 0, 0, 0],
        ]
        let px: CGFloat = 2
        for pt in particles {
            let alpha = max(0, pt.life / pt.maxLife)
            ctx.setFillColor(claudeOrange.withAlphaComponent(alpha).cgColor)
            for (row, bits) in pattern.enumerated() {
                for (col, b) in bits.enumerated() where b == 1 {
                    ctx.fill(NSRect(x: pt.x + CGFloat(col) * px,
                                    y: pt.y - CGFloat(row) * px,
                                    width: px, height: px))
                }
            }
        }
    }

    /// 命中区域：身体、手臂、四条腿。
    func hitAreaContains(_ p: NSPoint) -> Bool {
        let rects: [NSRect] = [
            cellRect(4, 4, 28, 21),
            cellRect(1.5, 13, 4.5, 17.5),
            cellRect(27.5, 13, 30.5, 17.5),
            cellRect(6.5, 0, 8.5, 4.4),
            cellRect(10.5, 0, 12.5, 4.4),
            cellRect(19.5, 0, 21.5, 4.4),
            cellRect(23.5, 0, 25.5, 4.4),
        ]
        return rects.contains { $0.insetBy(dx: -3, dy: -3).contains(p) }
    }

    override func mouseDown(with event: NSEvent) {
        controller?.mouseDown(event)
    }

    override func mouseDragged(with event: NSEvent) {
        controller?.mouseDragged(event)
    }

    override func mouseUp(with event: NSEvent) {
        controller?.mouseUp(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = controller?.makeContextMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

// MARK: - 气泡

final class BubbleView: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }
    var subtitle: String = "" {
        didSet { needsDisplay = true }
    }

    private let mainFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    private let subFont = NSFont.systemFont(ofSize: 10.5, weight: .semibold)

    func measure(_ text: String, _ subtitle: String) -> CGFloat {
        let a = (text as NSString).size(withAttributes: [.font: mainFont]).width
        let b = (subtitle as NSString).size(withAttributes: [.font: subFont]).width
        return min(max(max(a, b) + 30, 72), 240)
    }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        let bubbleRect = NSRect(x: 1, y: 10, width: b.width - 2, height: b.height - 11)

        let body = NSBezierPath(roundedRect: bubbleRect, xRadius: 10, yRadius: 10)
        let cx = b.midX
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: cx - 6, y: 11))
        tail.line(to: NSPoint(x: cx, y: 1))
        tail.line(to: NSPoint(x: cx + 6, y: 11))
        tail.close()

        let border = NSColor(srgbRed: 0.86, green: 0.79, blue: 0.75, alpha: 1)

        // 先画气泡底和边，再用尾巴的填充盖住两者交界处
        NSColor.white.setFill()
        body.fill()
        border.setStroke()
        body.lineWidth = 1.5
        body.stroke()

        NSColor.white.setFill()
        tail.fill()

        let tailSides = NSBezierPath()
        tailSides.move(to: NSPoint(x: cx - 6, y: 12))
        tailSides.line(to: NSPoint(x: cx, y: 1.5))
        tailSides.line(to: NSPoint(x: cx + 6, y: 12))
        tailSides.lineWidth = 1.5
        tailSides.lineCapStyle = .round
        border.setStroke()
        tailSides.stroke()

        let mainAttrs: [NSAttributedString.Key: Any] = [.font: mainFont, .foregroundColor: ink]
        let mainSize = (text as NSString).size(withAttributes: mainAttrs)

        if subtitle.isEmpty {
            let pt = NSPoint(x: b.midX - mainSize.width / 2,
                             y: bubbleRect.midY - mainSize.height / 2 + 1)
            (text as NSString).draw(at: pt, withAttributes: mainAttrs)
        } else {
            let pt = NSPoint(x: b.midX - mainSize.width / 2,
                             y: bubbleRect.midY - mainSize.height / 2 + 8)
            (text as NSString).draw(at: pt, withAttributes: mainAttrs)

            let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: claudeOrange]
            let subSize = (subtitle as NSString).size(withAttributes: subAttrs)
            let subPt = NSPoint(x: b.midX - subSize.width / 2,
                                y: bubbleRect.midY - subSize.height / 2 - 7)
            (subtitle as NSString).draw(at: subPt, withAttributes: subAttrs)
        }
    }
}

final class BubbleWindow: NSWindow {
    private let bubbleView = BubbleView()
    private var hideItem: DispatchWorkItem?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 100, height: 48),
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = bubbleView
        isReleasedWhenClosed = false
        alphaValue = 0
    }

    func show(_ text: String, subtitle: String, above petWindow: NSWindow) {
        hideItem?.cancel()
        let w = bubbleView.measure(text, subtitle)
        let h: CGFloat = subtitle.isEmpty ? 48 : 66
        setContentSize(NSSize(width: w, height: h))
        bubbleView.text = text
        bubbleView.subtitle = subtitle
        follow(petWindow)
        alphaValue = 1
        orderFrontRegardless()

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                self.animator().alphaValue = 0
            }, completionHandler: {
                self.orderOut(nil)
            })
        }
        hideItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    func follow(_ petWindow: NSWindow) {
        let w = frame.width
        var x = petWindow.frame.midX - w / 2
        var y = petWindow.frame.maxY + 2
        if let screen = petWindow.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            x = max(vf.minX + 4, min(x, vf.maxX - w - 4))
            y = min(y, vf.maxY - frame.height - 4)
        }
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - 窗口

final class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - 控制器

final class PetController: NSObject, NSApplicationDelegate {
    static let lines = [
        "嗨！", "在呢～", "戳我干嘛", "要不要写点代码？",
        "今天也一起加油", "我在摸鱼", "Claude 在此", "摸摸头",
        "再戳就熟了", "你很闲哦", "有 bug 吗？", "想我了？",
    ]
    static let comboLines = [
        "又戳！", "还来？", "上瘾了是吧", "手速不错",
    ]
    static let comboLines2 = [
        "喂喂喂", "轻点轻点", "我要晕了", "手不酸吗", "再戳要收费了",
    ]
    static let comboLines3 = [
        "脑袋要戳穿了", "我叫啦！", "再戳我要罢工", "已戳成筛子",
    ]
    static let comboLines4 = [
        "啊啊啊啊", "救命", "我记住你了", "这算工伤", "已报警（假的）",
    ]

    var window: PetWindow!
    var view: PetView!
    var bubble: BubbleWindow!
    var statusItem: NSStatusItem!
    var timer: Timer?

    var t: TimeInterval = 0
    var lastTick: TimeInterval = 0

    var nextBlink: TimeInterval = 1.5
    var blinkEnd: TimeInterval = 0
    var nextIdle: TimeInterval = 4
    var idleStart: TimeInterval = -10
    var idleKind: Int = 0

    var happyEnd: TimeInterval = 0
    var squashStart: TimeInterval = -10
    var waveStart: TimeInterval = -10

    var clickCount = 0
    var lastClickTime: TimeInterval = -100
    var reactionLevel = 0

    var isDragging = false
    var dragStartScreen = NSPoint.zero
    var dragStartOrigin = NSPoint.zero
    var didMove = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let saved = UserDefaults.standard.object(forKey: "petCell") as? Double,
           saved >= 2, saved <= 8 {
            CELL = CGFloat(saved)
            PAD = max(6, CELL * 2)
        }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let x = vf.midX - VIEW_W / 2
        let y = vf.minY + 24

        window = PetWindow(contentRect: NSRect(x: x, y: y, width: VIEW_W, height: VIEW_H),
                           styleMask: [.borderless],
                           backing: .buffered,
                           defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        view = PetView(frame: NSRect(x: 0, y: 0, width: VIEW_W, height: VIEW_H))
        view.controller = self
        window.contentView = view
        window.orderFrontRegardless()

        bubble = BubbleWindow()
        buildStatusItem()
        startTimer()

        // 自检模式：build 后加参数，跑完自动退出
        if CommandLine.arguments.contains("--demo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.clickFeedback()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                NSApp.terminate(nil)
            }
        }
        if CommandLine.arguments.contains("--demo-combo") {
            for i in 1...9 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(i) * 0.3) { [weak self] in
                    self?.clickFeedback()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) {
                NSApp.terminate(nil)
            }
        }
        if CommandLine.arguments.contains("--demo-size") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setScale(5.5, persist: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: 主循环

    func startTimer() {
        lastTick = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func tick() {
        let now = CACurrentMediaTime()
        var dt = now - lastTick
        lastTick = now
        dt = min(dt, 0.05)
        t += dt

        if t >= nextBlink {
            blinkEnd = t + 0.14
            nextBlink = t + Double.random(in: 2.2...5.5)
        }

        if t >= nextIdle && t > happyEnd + 0.6 && !isDragging {
            idleStart = t
            idleKind = Int.random(in: 0...2)
            nextIdle = t + Double.random(in: 7...15)
        }

        view.pose = makePose()
        updateParticles(dt)
        view.needsDisplay = true
        updateClickThrough()
    }

    func makePose() -> Pose {
        var p = Pose()

        let breath = CGFloat(sin(t * 1.9))
        p.bob = breath * 0.9
        p.scaleY = 1 + breath * 0.012

        if t < blinkEnd { p.eyeOpen = 0.08 }

        if t < happyEnd {
            switch reactionLevel {
            case 2:
                p.eyeStyle = .dizzy
                p.tilt = CGFloat(sin(t * 38)) * 0.035
            case 1:
                p.eyeWide = 1.3
            default:
                p.eyeStyle = .happy
            }
        }

        let dur: TimeInterval
        switch idleKind {
        case 0: dur = 0.55
        case 1: dur = 1.1
        default: dur = 0.75
        }
        let ip = (t - idleStart) / dur
        if ip >= 0 && ip <= 1 {
            switch idleKind {
            case 0:
                p.bob += CGFloat(sin(ip * .pi)) * 22
                let tuck = CGFloat(sin(ip * .pi)) * 2.0
                p.legLift = [tuck, tuck, tuck, tuck]
            case 1:
                p.eyeOffsetX = CGFloat(sin(ip * .pi * 2)) * CELL * 0.45
            default:
                let k = CGFloat(sin(ip * .pi))
                p.scaleY *= 1 + k * 0.07
                p.scaleX *= 1 - k * 0.03
                p.tilt = CGFloat(sin(ip * .pi * 2)) * 0.03
            }
        }

        let sp = (t - squashStart) / 0.55
        if sp >= 0 && sp <= 1 {
            let s = squashCurve(sp)
            p.scaleY *= s
            p.scaleX *= 1 + (1 - s) * 0.85
        }

        let wp = (t - waveStart) / 0.95
        if wp >= 0 && wp <= 1 {
            p.armRight = CGFloat(sin(wp * .pi * 3)) * 0.75
        }

        if isDragging {
            p.scaleY *= 1.07
            p.scaleX *= 0.96
            p.legLift = [1.2, 0.4, 1.0, 0.2]
            p.eyeWide = 1.15
        }

        return p
    }

    func squashCurve(_ x: Double) -> CGFloat {
        let k = CGFloat(x)
        func easeOut(_ u: CGFloat) -> CGFloat { 1 - (1 - u) * (1 - u) }
        if k < 0.25 {
            return 1 - 0.18 * easeOut(k / 0.25)
        } else if k < 0.6 {
            return 0.82 + 0.26 * easeOut((k - 0.25) / 0.35)
        } else {
            return 1.08 - 0.08 * ((k - 0.6) / 0.4)
        }
    }

    // MARK: 交互

    func mouseDown(_ event: NSEvent) {
        window.ignoresMouseEvents = false
        dragStartScreen = NSEvent.mouseLocation
        dragStartOrigin = window.frame.origin
        didMove = false
    }

    func mouseDragged(_ event: NSEvent) {
        let cur = NSEvent.mouseLocation
        let dx = cur.x - dragStartScreen.x
        let dy = cur.y - dragStartScreen.y
        if abs(dx) + abs(dy) > 3 {
            didMove = true
            isDragging = true
        }
        guard didMove else { return }
        window.setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy))
        bubble.follow(window)
    }

    func mouseUp(_ event: NSEvent) {
        if !didMove {
            clickFeedback()
        } else {
            isDragging = false
            clampToScreen()
            squashStart = t
        }
        dragStartScreen = .zero
    }

    func clickFeedback() {
        if t - lastClickTime > 2.2 { clickCount = 0 }
        clickCount += 1
        lastClickTime = t
        reactionLevel = clickCount >= 7 ? 2 : (clickCount >= 4 ? 1 : 0)

        happyEnd = t + 1.5
        squashStart = t
        waveStart = t + 0.05
        speak(phrase(for: clickCount),
              subtitle: clickCount >= 2 ? "连击 ×\(clickCount)" : "")
        spawnHearts()
    }

    func phrase(for n: Int) -> String {
        let pool: [String]
        switch n {
        case 1: pool = Self.lines
        case 2...3: pool = Self.comboLines
        case 4...6: pool = Self.comboLines2
        case 7...9: pool = Self.comboLines3
        default: pool = Self.comboLines4
        }
        return pool.randomElement() ?? "嗨！"
    }

    func clampToScreen() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        var f = window.frame
        f.origin.x = max(vf.minX - 20, min(f.origin.x, vf.maxX - f.width + 20))
        f.origin.y = max(vf.minY, min(f.origin.y, vf.maxY - f.height))
        window.setFrame(f, display: true)
    }

    func updateClickThrough() {
        let mouse = NSEvent.mouseLocation
        let inWindow = window.convertPoint(fromScreen: mouse)
        let inView = view.convert(inWindow, from: nil)
        let over = view.hitAreaContains(inView)
        let ignore = !(over || isDragging)
        if window.ignoresMouseEvents != ignore {
            window.ignoresMouseEvents = ignore
        }
    }

    // MARK: 气泡与粒子

    func speak(_ text: String, subtitle: String = "") {
        bubble.show(text, subtitle: subtitle, above: window)
    }

    func spawnHearts() {
        let centerX = PAD + 16 * CELL
        let startY = PAD + 20 * CELL
        for i in 0..<4 {
            let angle = Double(i) / 4.0 * .pi + .pi * 0.15
            let speed = CGFloat.random(in: 26...50)
            view.particles.append(Particle(
                x: centerX + CGFloat.random(in: -8...8),
                y: startY,
                vx: CGFloat(cos(angle)) * speed * 0.7,
                vy: 46 + CGFloat.random(in: 0...24),
                life: 0.9,
                maxLife: 0.9))
        }
    }

    func updateParticles(_ dt: TimeInterval) {
        var ps = view.particles
        for i in ps.indices {
            ps[i].x += ps[i].vx * CGFloat(dt)
            ps[i].y += ps[i].vy * CGFloat(dt)
            ps[i].vy -= 60 * CGFloat(dt)
            ps[i].life -= CGFloat(dt)
        }
        view.particles = ps.filter { $0.life > 0 }
    }

    // MARK: 菜单

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let speakItem = NSMenuItem(title: "让它说句话", action: #selector(speakRandom), keyEquivalent: "")
        speakItem.target = self
        menu.addItem(speakItem)

        let hopItem = NSMenuItem(title: "让它跳一下", action: #selector(hopNow), keyEquivalent: "")
        hopItem.target = self
        menu.addItem(hopItem)

        let sizeMenu = NSMenu()
        let presets: [(String, CGFloat)] = [("小", 3), ("中", 4), ("大", 5.5), ("超大", 7)]
        for (title, cell) in presets {
            let item = NSMenuItem(title: title, action: #selector(changeSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: Double(cell))
            if abs(cell - CELL) < 0.01 { item.state = .on }
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "大小", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let resetItem = NSMenuItem(title: "回到默认位置", action: #selector(resetPosition), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 Claude Pet", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🟠"
        statusItem.button?.toolTip = "小 Claude"
        statusItem.menu = makeContextMenu()
    }

    @objc func speakRandom() {
        clickFeedback()
    }

    @objc func hopNow() {
        idleStart = t
        idleKind = 0
        nextIdle = t + 8
    }

    @objc func changeSize(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? NSNumber else { return }
        setScale(CGFloat(n.doubleValue))
    }

    func setScale(_ newCell: CGFloat, persist: Bool = true) {
        guard abs(newCell - CELL) > 0.01 else { return }
        let old = window.frame
        let anchor = NSPoint(x: old.midX, y: old.minY)

        CELL = newCell
        PAD = max(6, newCell * 2)
        let size = NSSize(width: VIEW_W, height: VIEW_H)
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: anchor.x - size.width / 2, y: anchor.y))
        view.frame = NSRect(origin: .zero, size: size)
        clampToScreen()
        view.needsDisplay = true
        bubble.follow(window)

        if persist {
            UserDefaults.standard.set(Double(newCell), forKey: "petCell")
        }
        statusItem?.menu = makeContextMenu()
    }

    @objc func resetPosition() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: vf.midX - window.frame.width / 2,
                                      y: vf.minY + 24))
        bubble.follow(window)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - 启动

let app = NSApplication.shared
let controller = PetController()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
