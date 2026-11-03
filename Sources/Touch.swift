import AppKit

// MARK: - 摸摸与抓痒
//
// 鼠标停在宠物身上：轻轻挺一下；蕉哥原样还会稍微睁大眼，停久了眯眼笑。不说话。
// 在宠物身上快速来回滑：抓痒。笑、扭、冒爱心、+1 经验；挠着每秒换一句台词，越挠越激动，最后笑瘫。
// 只看鼠标位置和当前造型的点击范围，所以蕉哥原样和导入的宠物都能用。

final class TouchTracker {
    static let shared = TouchTracker()

    enum Event: Equatable {
        /// tickleEnded 带着这次挠到了第几级；按着鼠标打断的算 0
        case hoverBegan, tickleBegan, tickleLevelUp(Int), tickleEnded(Int)
    }

    /// 停多久算「放在身上」，免得鼠标路过就有反应
    static let hoverDelay: TimeInterval = 0.4
    /// 抓痒：这段时间里来回换方向至少这么多次，每一段至少走这么远（点）
    static let flipWindow: TimeInterval = 1.2
    static let flipsNeeded = 4
    static let minStroke: CGFloat = 6
    /// 多久没再来回就算停手
    static let tickleIdle: TimeInterval = 0.6
    /// 挠多久升到第 2、3 级；挠着的时候隔多久换一句台词
    static let level2At: TimeInterval = 1.2
    static let level3At: TimeInterval = 2.8
    static let lineGap: TimeInterval = 1.0

    private struct Axis {
        var dir = 0
        var travel: CGFloat = 0
        var flips: [TimeInterval] = []
    }

    // 下面的时间都是真实秒数（clock），只有 hoverT / perkT 是动画时间轴 t，算动作用
    private(set) var hovering = false
    private(set) var hoverT: TimeInterval = -100
    private(set) var perkT: TimeInterval = -100
    private var overSince: TimeInterval?
    private var lastOver: TimeInterval = -100
    private var lastPerk: TimeInterval = -100

    private var lastPoint: NSPoint?
    private var axes = [Axis(), Axis()]
    private var tickleStart: TimeInterval?
    private var tickleLast: TimeInterval = -100
    /// 0 = 没在挠；1～3 越挠越久越厉害
    private(set) var tickleLevel = 0
    /// 挠的时候上次冒爱心、上次说话的时间，以及最近说过的几句（别老重复）
    var lastHeart: TimeInterval = -100
    var lastLine: TimeInterval = -100
    var recentLines: [String] = []

    /// 每帧调一次。blocked：按着鼠标或正在拖，这时什么都不算
    func update(now: TimeInterval, t: TimeInterval, mouse: NSPoint, over: Bool, blocked: Bool) -> [Event] {
        var events: [Event] = []
        if blocked {
            if tickleStart != nil { events.append(.tickleEnded(0)) }
            reset()
            return events
        }

        // 放在身上
        if over {
            if overSince == nil { overSince = now }
            lastOver = now
        } else {
            overSince = nil
        }
        let wasHovering = hovering
        hovering = overSince.map { now - $0 >= Self.hoverDelay } ?? false
        if hovering && !wasHovering {
            hoverT = t
            // 在边上进进出出时别一直挺
            if now - lastPerk > 1.5 {
                lastPerk = now
                perkT = t
                events.append(.hoverBegan)
            }
        }

        // 抓痒：鼠标在身上，或者刚滑出去一点点（挠得快难免出界）时记来回
        let near = over || now - lastOver < 0.3
        if near, let last = lastPoint {
            let moves = [mouse.x - last.x, mouse.y - last.y]
            for i in 0..<2 where abs(moves[i]) >= 0.5 {
                let dir = moves[i] > 0 ? 1 : -1
                if dir == axes[i].dir {
                    axes[i].travel += abs(moves[i])
                } else {
                    if axes[i].dir != 0 && axes[i].travel >= Self.minStroke { axes[i].flips.append(now) }
                    axes[i].dir = dir
                    axes[i].travel = abs(moves[i])
                }
            }
        } else if !near {
            axes = [Axis(), Axis()]
        }
        for i in 0..<2 { axes[i].flips.removeAll { now - $0 > Self.flipWindow } }
        lastPoint = mouse

        let flips = max(axes[0].flips.count, axes[1].flips.count)
        let latest = max(axes[0].flips.last ?? -100, axes[1].flips.last ?? -100)
        if let start = tickleStart {
            tickleLast = max(tickleLast, latest)
            if now - tickleLast > Self.tickleIdle {
                events.append(.tickleEnded(tickleLevel))
                tickleStart = nil
                tickleLevel = 0
                axes = [Axis(), Axis()]
            } else {
                let level = now - start < Self.level2At ? 1 : (now - start < Self.level3At ? 2 : 3)
                if level > tickleLevel {
                    tickleLevel = level
                    events.append(.tickleLevelUp(level))
                }
            }
        } else if flips >= Self.flipsNeeded {
            tickleStart = now
            tickleLast = now
            tickleLevel = 1
            events.append(.tickleBegan)
        }
        return events
    }

    func reset() {
        hovering = false
        overSince = nil
        lastPoint = nil
        axes = [Axis(), Axis()]
        tickleStart = nil
        tickleLevel = 0
    }
}

extension PetController {
    static let tickleLines = [
        // 刚开始挠
        ["哈哈哈别挠了", "好痒好痒", "嘿嘿嘿", "痒！", "别挠啦哈哈", "那里不行哈哈",
         "咯咯咯", "痒痒痒痒", "你偷袭！", "哈哈住手", "怕痒怕痒", "这是犯规的", "嘻嘻别闹", "哪学的这招"],
        // 挠了一会儿
        ["哈哈哈哈停一下", "笑得肚子疼", "我要笑岔气了", "饶了我吧哈哈", "你故意的吧哈哈",
         "喘、喘不过气了", "我错了我错了哈哈", "等、等一下哈哈", "腹肌要笑出来了", "求放过哈哈哈",
         "这招太狠了", "笑得停不下来", "你给我等着哈哈"],
        // 挠太久，笑瘫了
        ["痒死了！", "我投降！我投降！", "救命哈哈哈哈", "笑不动了……", "眼泪都笑出来了",
         "举白旗了！", "啊哈哈哈哈哈哈", "笑到缺氧", "我、我不行了", "来人啊哈哈哈",
         "笑得满地打滚", "你是挠痒痒大师", "蕉哥已经笑没电了"],
    ]
    /// 挠了好一阵、停手以后缓过来说的
    static let tickleAfterLines = [
        "呼……终于停了", "我缓缓", "你给我等着", "笑得脸都酸了", "下次换我挠你",
        "刚才的事不许说出去", "还、还要吗……", "差点笑岔气", "形象全没了",
    ]

    /// 每帧调一次：看鼠标是不是放在身上、是不是在来回挠
    func touchStep() {
        let mouse = NSEvent.mouseLocation
        let inView = view.convert(window.convertPoint(fromScreen: mouse), from: nil)
        let blocked = isDragging || NSEvent.pressedMouseButtons & 1 != 0
        let tracker = TouchTracker.shared
        handleTouch(tracker.update(now: clock, t: t, mouse: mouse, over: view.hitAreaContains(inView), blocked: blocked))
        if tracker.tickleLevel > 0 {
            nextIdle = max(nextIdle, t + 3)         // 挠着的时候别去打哈欠
            if clock - tracker.lastLine > TouchTracker.lineGap { sayTickle(level: tracker.tickleLevel) }   // 挠着就一直换着说
            if clock - tracker.lastHeart > 0.9 {
                spawnHearts()
                tracker.lastHeart = clock
            }
        }
    }

    func handleTouch(_ events: [TouchTracker.Event]) {
        for event in events {
            switch event {
            case .hoverBegan:
                break           // 动作在 applyTouchPose 里，不说话
            case .tickleBegan:
                bumpTickleStats()
                addXP(1)
                if pomoMode != .focus { playSound("Pop", volume: 0.25) }
                sayTickle(level: 1)
                spawnHearts()
                TouchTracker.shared.lastHeart = clock
            case .tickleLevelUp(let level):
                sayTickle(level: level)
            case .tickleEnded(let level):
                if level >= 2 { sayTickle(Self.tickleAfterLines, duration: 2) }
            }
        }
    }

    func sayTickle(level: Int) {
        sayTickle(Self.tickleLines[min(max(level, 1), 3) - 1], duration: 1.2)
    }

    func sayTickle(_ pool: [String], duration: TimeInterval) {
        TouchTracker.shared.lastLine = clock
        // 和戳一下一样：正显示译文、正在翻译时不拿台词盖掉；也别打断正在说的聊天回复
        guard !bubble.isSticky, translation == nil, !chatInFlight else { return }
        // 最近说过的 5 句先不说
        let tracker = TouchTracker.shared
        let fresh = pool.filter { !tracker.recentLines.contains($0) }
        let pick = (fresh.isEmpty ? pool : fresh).randomElement() ?? "好痒"
        tracker.recentLines = Array((tracker.recentLines + [pick]).suffix(5))
        lastSpokenLine = pick
        speak(petLine(pick), duration: duration)
    }

    /// makePose 最后调：在原来的姿势上叠加摸摸和抓痒的动作
    func applyTouchPose(_ p: inout Pose) {
        let tracker = TouchTracker.shared
        let level = tracker.tickleLevel
        if level > 0 {
            p.eyeStyle = .happy
            p.mouth = level >= 3 ? .wavy : .oh
            p.tilt += CGFloat(sin(t * 28)) * (level >= 3 ? 0.08 : 0.05)
            p.scaleX *= 1 + CGFloat(sin(t * 31)) * 0.02
            if level >= 3 { p.scaleY *= 0.96 }             // 笑瘫了
            p.armLeft = CGFloat(sin(t * 22)) * 0.3
            p.armRight = CGFloat(sin(t * 22 + 1.3)) * 0.35
            let leg = CGFloat(sin(t * 20)) * 9
            p.legLift = [max(0, leg), max(0, -leg)]
            p.bob += abs(CGFloat(sin(t * 14))) * 3
            p.eyeOffsetX = 0
            p.eyeOffsetY = 0
            return
        }
        guard tracker.hovering else { return }
        // 刚放上来：轻轻往上挺一下
        let perk = t - tracker.perkT
        if perk >= 0 && perk <= 0.35 {
            let k = CGFloat(sin(perk / 0.35 * .pi))
            p.scaleY *= 1 + 0.04 * k
            p.scaleX *= 1 - 0.015 * k
            p.bob += 2 * k
        }
        // 蕉哥原样：稍微睁大眼；停久了眯眼笑（正在做别的表情时不抢）
        if p.eyeStyle == .normal && p.eyeOpen > 0.5 {
            p.eyeWide = max(p.eyeWide, 1.08)
            if t - tracker.hoverT > 1.2 && t >= happyEnd { p.eyeStyle = .happy }
        }
    }

    // MARK: 统计

    var tickleToday: Int {
        let d = UserDefaults.standard
        return d.string(forKey: "tickleDay") == dayKey() ? d.integer(forKey: "tickleToday") : 0
    }

    func bumpTickleStats() {
        let d = UserDefaults.standard
        let count = tickleToday + 1
        d.set(dayKey(), forKey: "tickleDay")
        d.set(count, forKey: "tickleToday")
    }
}
