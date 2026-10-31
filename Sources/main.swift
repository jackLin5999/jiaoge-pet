import AppKit
import QuartzCore
import Network
import ServiceManagement
import IOKit.ps

// MARK: - 尺寸与配色

var CELL: CGFloat = 4
var PAD: CGFloat = 8
/// 造型直接按参考图（560×750）的像素坐标来画，原点在左上、y 向下；这是取景范围
let ART = CGRect(x: 40, y: 20, width: 460, height: 700)
/// 参考图 1 像素对应几个点，CELL = 4 时整根香蕉约 130 点高
var ART_SCALE: CGFloat { CELL / 20 }
/// 顶部留给跳跃的空白
let HOP_ROOM: CGFloat = 26
var PET_W: CGFloat { ART.width * ART_SCALE }
var PET_H: CGFloat { ART.height * ART_SCALE }
var VIEW_W: CGFloat { PET_W + PAD * 2 }
var VIEW_H: CGFloat { PET_H + PAD * 2 + HOP_ROOM }
/// 造型最高点（果柄顶端）在视图里的高度，气泡贴着它显示
var PET_TOP: CGFloat { PAD + (ART.maxY - 72) * ART_SCALE }

/// 参考图坐标 → 视图坐标（视图原点在左下角）
var artToView: CGAffineTransform {
    CGAffineTransform(a: ART_SCALE, b: 0, c: 0, d: -ART_SCALE,
                      tx: PAD - ART.minX * ART_SCALE, ty: PAD + ART.maxY * ART_SCALE)
}

/// 参考图是 Display P3 色彩空间，按 P3 标注才能在广色域屏上和原图一致，sRGB 屏上系统会自动转换
func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(displayP3Red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha)
}

// 配色都取自参考图
let peelYellow = rgb(0xF4DC75)
let peelOutline = rgb(0xCEAB4C)
let peelShade = rgb(0xE4C25E)
let peelSpot = rgb(0xC09D53)
let footYellow = rgb(0xF0CF67)
let stemBrown = rgb(0x987D48)
let stemOutline = rgb(0x6E572C)
let tipBrown = rgb(0x59461F)
let eyeDark = rgb(0x393941)
let eyeGlint = rgb(0xCBCBCC)
let mouthBrown = rgb(0x49392C)
let heartRed = rgb(0xE8675F)
let ink = NSColor(srgbRed: 0.28, green: 0.18, blue: 0.14, alpha: 1)

// MARK: - 香蕉造型（参考图坐标）

/// 过一串点画平滑曲线（Catmull-Rom 转三次贝塞尔）
func smoothPath(_ xy: [(CGFloat, CGFloat)], closed: Bool) -> CGPath {
    let pts = xy.map { CGPoint(x: $0.0, y: $0.1) }
    let n = pts.count
    func at(_ i: Int) -> CGPoint {
        closed ? pts[(i + n) % n] : pts[min(max(i, 0), n - 1)]
    }
    let path = CGMutablePath()
    path.move(to: pts[0])
    for i in 0..<(closed ? n : n - 1) {
        let p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2)
        path.addCurve(to: p2,
                      control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                      control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
    }
    if closed { path.closeSubpath() }
    return path
}

enum Banana {
    /// 身体轮廓（描边的中线），顶端藏在果柄下面
    static let body = smoothPath([
        (259, 124), (292, 127), (311, 136), (319, 150), (330, 180), (339, 215),
        (348, 260), (352.5, 300), (355, 345), (356, 395), (355.5, 432), (353.5, 460),
        (347, 500), (336, 540), (321, 580), (298, 620), (282, 640), (262, 650),
        (240, 654), (220, 652.5), (203, 646), (193, 640), (175, 620), (155.5, 580),
        (142, 540), (132, 500), (125, 450), (122.5, 400), (124.5, 345), (131, 300),
        (141, 260), (155, 220), (175, 180), (196, 150), (208, 136), (226, 127),
    ], closed: true)
    /// 左边的暗条、右边的高光
    static let shade = smoothPath([
        (161.5, 231.5), (147, 320), (141.5, 410), (146, 470), (161, 540), (181, 586),
    ], closed: false)
    static let spots = [
        CGRect(x: 186.5, y: 290.5, width: 14, height: 12),
        CGRect(x: 293.5, y: 288.5, width: 11, height: 8),
        CGRect(x: 319.5, y: 456.5, width: 12, height: 10),
        CGRect(x: 170.5, y: 508.25, width: 11, height: 7.5),
    ]
    static let stem: CGPath = {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 202.2, y: 146.5))
        p.addLine(to: CGPoint(x: 215.3, y: 86))
        p.addQuadCurve(to: CGPoint(x: 303.7, y: 86), control: CGPoint(x: 259.5, y: 71))
        p.addLine(to: CGPoint(x: 316.4, y: 146.5))
        p.closeSubpath()
        return p
    }()
    /// 左手垂着，右手举起来打招呼；肩膀是挥手时的转轴
    static let leftShoulder = CGPoint(x: 107, y: 462)
    static let leftArm: CGPath = {
        let p = CGMutablePath()
        p.move(to: leftShoulder)
        p.addQuadCurve(to: CGPoint(x: 74.5, y: 564), control: CGPoint(x: 70, y: 502))
        return p
    }()
    static let rightShoulder = CGPoint(x: 375, y: 460.5)
    static let rightArm: CGPath = {
        let p = CGMutablePath()
        p.move(to: rightShoulder)
        p.addCurve(to: CGPoint(x: 443, y: 342),
                   control1: CGPoint(x: 427.5, y: 431.5), control2: CGPoint(x: 448.5, y: 399))
        return p
    }()
    static let feet = [
        CGRect(x: 174, y: 651, width: 65, height: 32),
        CGRect(x: 254, y: 645.5, width: 64, height: 33),
    ]
    static let tip = CGRect(x: 212, y: 644.5, width: 25, height: 17)
    static let shadow = CGRect(x: 110, y: 678, width: 273, height: 37)
    static let eyeCenters: [CGFloat] = [200.5, 305.5]
    static let eyeY: CGFloat = 364.75
    /// 脚底中点，挤压、拉长、歪头都以这里为支点
    static let anchor = CGPoint(x: 246, y: 686)

    /// 可点击区域：各部件向外放宽一圈
    static let hitShapes: [CGPath] = {
        let margin: CGFloat = 32
        func fat(_ path: CGPath, _ width: CGFloat) -> CGPath {
            path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        }
        return [body, fat(body, margin), stem, fat(stem, margin),
                fat(leftArm, 30 + margin), fat(rightArm, 30 + margin)]
            + feet.map { CGPath(ellipseIn: $0.insetBy(dx: -margin / 2, dy: -margin / 2), transform: nil) }
    }()
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

enum MouthStyle {
    case smirk, oh, wavy
}

/// bob 以点为单位；eyeOffsetX、legLift 以参考图像素为单位；手臂角度向外甩为正
struct Pose {
    var bob: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var tilt: CGFloat = 0
    var eyeOpen: CGFloat = 1
    var eyeWide: CGFloat = 1
    var eyeOffsetX: CGFloat = 0
    var eyeOffsetY: CGFloat = 0
    var eyeStyle: EyeStyle = .normal
    var mouth: MouthStyle = .smirk
    var armLeft: CGFloat = 0
    var armRight: CGFloat = 0
    var legLift: [CGFloat] = [0, 0]
}

// MARK: - 视图

final class PetView: NSView {
    weak var controller: PetController?
    var pose = Pose()
    /// 当前段位对应的皇冠素材名
    var crownKey: String = "" {
        didSet {
            guard crownKey != oldValue else { return }
            crownImage = CrownAssets.image(for: crownKey)
            needsDisplay = true
        }
    }
    private var crownImage: CGImage?
    var particles: [Particle] = []

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawPet(ctx)
        drawParticles(ctx)
    }

    private func drawPet(_ ctx: CGContext) {
        let p = pose
        let toView = artToView

        // 影子留在地上，跳起来时变小变淡
        ctx.saveGState()
        ctx.concatenate(toView)
        let k = 1 - min(max(p.bob, 0), 30) / 60
        let s = Banana.shadow
        ctx.setFillColor(NSColor(white: 0, alpha: 0.06 * k).cgColor)
        ctx.fillEllipse(in: s.insetBy(dx: s.width * (1 - k) / 2, dy: s.height * (1 - k) / 2))
        ctx.restoreGState()

        ctx.saveGState()
        let a = Banana.anchor.applying(toView)
        ctx.translateBy(x: a.x, y: a.y + p.bob)
        ctx.rotate(by: p.tilt)
        ctx.scaleBy(x: p.scaleX, y: p.scaleY)
        ctx.translateBy(x: -a.x, y: -a.y)
        ctx.concatenate(toView)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // 手臂在身体后面
        drawArm(ctx, Banana.leftArm, shoulder: Banana.leftShoulder, angle: p.armLeft)
        drawArm(ctx, Banana.rightArm, shoulder: Banana.rightShoulder, angle: p.armRight)
        drawBody(ctx)

        // 脚压在身体前面，尾端的小黑点再压在脚上
        ctx.setFillColor(footYellow.cgColor)
        ctx.setStrokeColor(peelOutline.cgColor)
        ctx.setLineWidth(6)
        for (i, foot) in Banana.feet.enumerated() {
            ctx.addEllipse(in: foot.offsetBy(dx: 0, dy: -p.legLift[i]))
            ctx.drawPath(using: .fillStroke)
        }
        ctx.setFillColor(tipBrown.cgColor)
        ctx.fillEllipse(in: Banana.tip)

        ctx.addPath(Banana.stem)
        ctx.setFillColor(stemBrown.cgColor)
        ctx.setStrokeColor(stemOutline.cgColor)
        ctx.drawPath(using: .fillStroke)

        drawCrown(ctx)
        drawEyes(ctx)
        drawMouth(ctx)
        ctx.restoreGState()
    }

    /// 皇冠：底部压在果柄顶端，跟着宠物一起呼吸、歪头、跳动
    private func drawCrown(_ ctx: CGContext) {
        guard let crown = crownImage else { return }
        let width: CGFloat = 176
        let height = width * CGFloat(crown.height) / CGFloat(crown.width)
        let bottom: CGFloat = 130
        // 注意：头部中心线在 258 附近（脚底中心才是 246），按 246 摆会偏左
        let left = 258 - width / 2
        ctx.saveGState()
        ctx.translateBy(x: left, y: bottom)
        ctx.scaleBy(x: 1, y: -1)          // 素材是正立的，画在 y 向下的坐标系里要翻回来
        ctx.draw(crown, in: CGRect(x: 0, y: 0, width: width, height: height))
        ctx.restoreGState()
    }

    private func drawArm(_ ctx: CGContext, _ arm: CGPath, shoulder: CGPoint, angle: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: shoulder.x, y: shoulder.y)
        ctx.rotate(by: angle)
        ctx.translateBy(x: -shoulder.x, y: -shoulder.y)
        // 先描一道粗的描边色，再描一道细的黄色
        ctx.addPath(arm)
        ctx.setStrokeColor(peelOutline.cgColor)
        ctx.setLineWidth(30)
        ctx.strokePath()
        ctx.addPath(arm)
        ctx.setStrokeColor(peelYellow.cgColor)
        ctx.setLineWidth(18)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawBody(_ ctx: CGContext) {
        ctx.addPath(Banana.body)
        ctx.setFillColor(peelYellow.cgColor)
        ctx.fillPath()

        // 左边的暗条和斑点裁在身体里面
        ctx.saveGState()
        ctx.addPath(Banana.body)
        ctx.clip()
        ctx.addPath(Banana.shade)
        ctx.setStrokeColor(peelShade.cgColor)
        ctx.setLineWidth(6.5)
        ctx.strokePath()
        ctx.setFillColor(peelSpot.cgColor)
        for spot in Banana.spots {
            ctx.fillEllipse(in: spot)
        }
        ctx.restoreGState()

        ctx.addPath(Banana.body)
        ctx.setStrokeColor(peelOutline.cgColor)
        ctx.setLineWidth(6)
        ctx.strokePath()
    }

    private func drawEyes(_ ctx: CGContext) {
        let p = pose
        let cy = Banana.eyeY
        ctx.setStrokeColor(eyeDark.cgColor)

        switch p.eyeStyle {
        case .happy:
            ctx.setLineWidth(9)
            for cx in Banana.eyeCenters {
                ctx.move(to: CGPoint(x: cx - 26, y: cy + 6))
                ctx.addQuadCurve(to: CGPoint(x: cx + 26, y: cy + 6), control: CGPoint(x: cx, y: cy - 34))
            }
            ctx.strokePath()

        case .dizzy:
            ctx.setLineWidth(8)
            let s: CGFloat = 15
            for cx in Banana.eyeCenters {
                ctx.move(to: CGPoint(x: cx - s, y: cy - s))
                ctx.addLine(to: CGPoint(x: cx + s, y: cy + s))
                ctx.move(to: CGPoint(x: cx + s, y: cy - s))
                ctx.addLine(to: CGPoint(x: cx - s, y: cy + s))
            }
            ctx.strokePath()

        case .normal:
            let w = 74 * (1 + (p.eyeWide - 1) * 0.35)
            let h = max(5, 47.5 * p.eyeOpen * p.eyeWide)
            let radius = min(11, h / 2)
            for cx in Banana.eyeCenters {
                let r = CGRect(x: cx + p.eyeOffsetX - w / 2, y: cy + p.eyeOffsetY - h / 2,
                               width: w, height: h)
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
                ctx.setFillColor(eyeDark.cgColor)
                ctx.fillPath()
                // 左上角一道反光，眨眼时不画
                if h > 24 {
                    ctx.move(to: CGPoint(x: r.minX + 13.5, y: r.minY + 12.5))
                    ctx.addLine(to: CGPoint(x: r.minX + 28.5, y: r.minY + 12.5))
                    ctx.setStrokeColor(eyeGlint.cgColor)
                    ctx.setLineWidth(4)
                    ctx.strokePath()
                }
            }
        }
    }

    private func drawMouth(_ ctx: CGContext) {
        ctx.setStrokeColor(mouthBrown.cgColor)
        ctx.setLineWidth(6)

        switch pose.mouth {
        case .smirk:
            ctx.move(to: CGPoint(x: 217.5, y: 437))
            ctx.addQuadCurve(to: CGPoint(x: 286, y: 425), control: CGPoint(x: 245, y: 449))
            ctx.strokePath()

        case .oh:
            ctx.setFillColor(mouthBrown.cgColor)
            ctx.fillEllipse(in: CGRect(x: 241, y: 422, width: 18, height: 22))

        case .wavy:
            ctx.move(to: CGPoint(x: 218, y: 436))
            for i in 0..<3 {
                let x0 = 218 + CGFloat(i) * 22
                ctx.addQuadCurve(to: CGPoint(x: x0 + 22, y: 436),
                                 control: CGPoint(x: x0 + 11, y: i % 2 == 0 ? 426 : 446))
            }
            ctx.strokePath()
        }
    }

    /// 单位方块里的心形，原点在左上、y 向下
    private static let heart: CGPath = {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0.5, y: 0.92))
        p.addCurve(to: CGPoint(x: 0, y: 0.3), control1: CGPoint(x: 0.15, y: 0.68), control2: CGPoint(x: 0, y: 0.5))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.16), control1: CGPoint(x: 0, y: 0.02), control2: CGPoint(x: 0.4, y: -0.04))
        p.addCurve(to: CGPoint(x: 1, y: 0.3), control1: CGPoint(x: 0.6, y: -0.04), control2: CGPoint(x: 1, y: 0.02))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.92), control1: CGPoint(x: 1, y: 0.5), control2: CGPoint(x: 0.85, y: 0.68))
        p.closeSubpath()
        return p
    }()

    private func drawParticles(_ ctx: CGContext) {
        let size = 2.8 * CELL
        for pt in particles {
            let alpha = max(0, pt.life / pt.maxLife)
            ctx.saveGState()
            ctx.translateBy(x: pt.x - size / 2, y: pt.y + size / 2)
            ctx.scaleBy(x: size, y: -size)
            ctx.addPath(Self.heart)
            ctx.setFillColor(heartRed.withAlphaComponent(alpha).cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }
    }

    /// 命中区域：身体、果柄、手臂、脚，各放宽一圈。
    func hitAreaContains(_ p: NSPoint) -> Bool {
        let q = p.applying(artToView.inverted())
        return Banana.hitShapes.contains { $0.contains(q) }
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
        // 按住 Option 右键 = 打开完整菜单（菜单栏图标被挡住时的备用入口）
        if event.modifierFlags.contains(.option), let menu = controller?.contextMenu() {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        controller?.toggleClipboardPanel()
    }
}

// MARK: - 气泡

final class BubbleView: NSView {
    /// 气泡可点时的回调（长结果点一下展开）
    var onTap: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onTap?()
    }

    var text: String = "" {
        didSet { needsDisplay = true }
    }
    var subtitle: String = "" {
        didSet { needsDisplay = true }
    }

    private let mainFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    private let subFont = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
    private let hPad: CGFloat = 14
    private let vPad: CGFloat = 10

    private var mainAttrs: [NSAttributedString.Key: Any] { [.font: mainFont, .foregroundColor: ink] }
    private var subAttrs: [NSAttributedString.Key: Any] { [.font: subFont, .foregroundColor: stemOutline] }

    private func wrapped(_ s: String, _ attrs: [NSAttributedString.Key: Any], width: CGFloat) -> NSRect {
        guard !s.isEmpty else { return .zero }
        return (s as NSString).boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude),
                                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                                            attributes: attrs)
    }

    /// 算气泡该多大
    func measuredSize(maxWidth: CGFloat, maxHeight: CGFloat = 280) -> NSSize {
        let inner = maxWidth - hPad * 2
        let main = wrapped(text, mainAttrs, width: inner)
        let sub = wrapped(subtitle, subAttrs, width: inner)
        let subH = subtitle.isEmpty ? 0 : ceil(sub.height) + 3
        let w = max(72, min(maxWidth, ceil(max(main.width, sub.width)) + hPad * 2))
        let h = max(44, min(maxHeight, ceil(main.height) + subH + vPad * 2 + 10))
        return NSSize(width: w, height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        let body = NSRect(x: 1, y: 10, width: b.width - 2, height: b.height - 11)

        let shape = NSBezierPath(roundedRect: body, xRadius: 10, yRadius: 10)
        let cx = b.midX
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: cx - 6, y: 11))
        tail.line(to: NSPoint(x: cx, y: 1))
        tail.line(to: NSPoint(x: cx + 6, y: 11))
        tail.close()

        let border = rgb(0xE3D3A1)

        // 先画气泡底和边，再用尾巴的填充盖住两者交界处
        NSColor.white.setFill()
        shape.fill()
        border.setStroke()
        shape.lineWidth = 1.5
        shape.stroke()

        NSColor.white.setFill()
        tail.fill()

        let sides = NSBezierPath()
        sides.move(to: NSPoint(x: cx - 6, y: 12))
        sides.line(to: NSPoint(x: cx, y: 1.5))
        sides.line(to: NSPoint(x: cx + 6, y: 12))
        sides.lineWidth = 1.5
        sides.lineCapStyle = .round
        border.setStroke()
        sides.stroke()

        // 正文
        let inner = b.width - hPad * 2
        let mainRect = wrapped(text, mainAttrs, width: inner)
        let subRect = wrapped(subtitle, subAttrs, width: inner)
        let mainH = ceil(mainRect.height)
        let subH = subtitle.isEmpty ? 0 : ceil(subRect.height) + 3
        let blockH = mainH + subH

        var attrs = mainAttrs
        var subAttrs = self.subAttrs
        // 一行以内居中，多行左对齐，读起来舒服
        let centered = mainH <= mainFont.boundingRectForFont.height + 2
        let para = NSMutableParagraphStyle()
        para.alignment = centered ? .center : .left
        para.lineBreakMode = .byWordWrapping
        attrs[.paragraphStyle] = para
        let subPara = NSMutableParagraphStyle()
        subPara.alignment = .center
        subAttrs[.paragraphStyle] = subPara

        // 太长时从顶部开始排，并且裁掉溢出的部分
        let usable = body.height - vPad * 2
        var top = blockH > usable ? body.maxY - vPad : body.midY + blockH / 2

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: body.insetBy(dx: 2, dy: 4)).addClip()

        if !text.isEmpty {
            let rect = NSRect(x: hPad, y: top - mainH, width: inner, height: mainH)
            (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
                                    attributes: attrs)
        }
        if !subtitle.isEmpty {
            top -= mainH + 3
            let rect = NSRect(x: hPad, y: top - (subH - 3), width: inner, height: subH - 3)
            (subtitle as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
                                        attributes: subAttrs)
        }
        NSGraphicsContext.restoreGraphicsState()
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

    private(set) var isSticky = false

    func show(_ text: String, subtitle: String = "", duration: TimeInterval = 2.0,
              maxWidth: CGFloat = 240, sticky: Bool = false,
              onTap: (() -> Void)? = nil, above petWindow: NSWindow) {
        if hideItem != nil && alphaValue > 0 {
            // 换内容时不要闪一下
            alphaValue = 1
        }
        hideItem?.cancel()
        bubbleView.text = text
        bubbleView.subtitle = subtitle
        bubbleView.onTap = onTap
        ignoresMouseEvents = (onTap == nil)      // 可展开的气泡要能接收点击
        setContentSize(bubbleView.measuredSize(maxWidth: maxWidth))
        follow(petWindow)
        alphaValue = 1
        orderFrontRegardless()

        isSticky = sticky
        guard !sticky else { return }        // 常驻模式不自动消失，等点击

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
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    /// 常驻的气泡只有点击时才收起来
    func hideIfSticky() {
        if isSticky { hideNow() }
    }

    func hideNow() {
        isSticky = false
        bubbleView.onTap = nil
        ignoresMouseEvents = true
        hideItem?.cancel()
        alphaValue = 0
        orderOut(nil)
    }

    func follow(_ petWindow: NSWindow) {
        placeAbovePet(self, petWindow: petWindow)
    }
}

/// 贴着宠物头顶摆窗口（气泡和番茄钟卡片共用）
func placeAbovePet(_ w: NSWindow, petWindow: NSWindow) {
    let width = w.frame.width
    var x = petWindow.frame.midX - width / 2
    var y = petWindow.frame.minY + PET_TOP + 2
    if let screen = petWindow.screen ?? NSScreen.main {
        let vf = screen.visibleFrame
        x = max(vf.minX + 4, min(x, vf.maxX - width - 4))
        y = min(y, vf.maxY - w.frame.height - 4)
    }
    w.setFrameOrigin(NSPoint(x: x, y: y))
}

/// 番茄钟到点后的选择卡片：问一句要不要开始下一段，不自动计时。
/// 用非激活面板，弹出来不会抢走当前 App 的键盘焦点。
final class PomoPromptPanel: NSPanel {
    private let card = NSView()
    private let messageLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton()
    private let laterButton = NSButton()
    private var onAction: (() -> Void)?
    private var autoClose: DispatchWorkItem?

    private static let cardWidth: CGFloat = 320
    private static let cardHeight: CGFloat = 104
    private static let margin: CGFloat = 12

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0,
                                       width: Self.cardWidth + Self.margin * 2,
                                       height: Self.cardHeight + Self.margin * 2),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false

        card.frame = NSRect(x: Self.margin, y: Self.margin,
                            width: Self.cardWidth, height: Self.cardHeight)
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.white.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1.5
        card.layer?.borderColor = rgb(0xE3D3A1).cgColor
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.16
        card.layer?.shadowRadius = 12
        card.layer?.shadowOffset = CGSize(width: 0, height: -3)
        contentView = card

        messageLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        messageLabel.textColor = ink
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.frame = NSRect(x: 16, y: 63, width: Self.cardWidth - 32, height: 18)
        card.addSubview(messageLabel)

        detailLabel.font = NSFont.systemFont(ofSize: 11)
        detailLabel.textColor = stemOutline
        detailLabel.frame = NSRect(x: 16, y: 43, width: Self.cardWidth - 32, height: 16)
        card.addSubview(detailLabel)

        actionButton.bezelStyle = .rounded
        actionButton.target = self
        actionButton.action = #selector(act)
        actionButton.frame = NSRect(x: 16, y: 10, width: 196, height: 28)
        card.addSubview(actionButton)

        laterButton.title = "稍后"
        laterButton.bezelStyle = .rounded
        laterButton.target = self
        laterButton.action = #selector(later)
        laterButton.frame = NSRect(x: 220, y: 10, width: 84, height: 28)
        card.addSubview(laterButton)
    }

    func present(message: String, detail: String, actionTitle: String,
                 above petWindow: NSWindow, seconds: TimeInterval = 120,
                 onAction: @escaping () -> Void) {
        self.onAction = onAction
        messageLabel.stringValue = message
        detailLabel.stringValue = detail
        actionButton.title = actionTitle
        autoClose?.cancel()
        placeAbovePet(self, petWindow: petWindow)
        orderFrontRegardless()

        let item = DispatchWorkItem { [weak self] in self?.dismiss() }
        autoClose = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    /// 直接收起，不触发按钮动作
    func dismiss() {
        autoClose?.cancel()
        autoClose = nil
        onAction = nil
        orderOut(nil)
    }

    @objc private func act() {
        let action = onAction
        dismiss()
        action?()
    }

    @objc private func later() {
        dismiss()
    }
}

// MARK: - 窗口

final class PetWindow: NSWindow {
    // 宠物本身不需要键盘焦点，能成为 key window 的话会把输入框的焦点抢走
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - 控制器

enum PomoMode {
    case none, focus, rest
}

/// 安静时攒下来、之后再说的一句提醒
struct HeldNudge {
    let key: String
    let text: String
    let hasSound: Bool
    let time: TimeInterval
}

final class PetController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let lines = [
        "嗨！", "在呢～", "戳我干嘛", "要不要写点代码？",
        "今天也一起加油", "我在摸鱼", "蕉哥在此", "摸摸头",
        "再戳就熟了", "你很闲哦", "有 bug 吗？", "想我了？",
    ]
    /// 戳不同部位说不同的话
    enum BodyPart {
        case stem, eye, mouth, arm, foot, belly
    }

    static let stemLines = [
        "别揪我头发", "那是我的把儿", "头顶不能戳", "再揪就秃了", "别薅我", "头顶痒痒的",
    ]
    static let eyeLines = [
        "别戳眼睛！", "哎哟，眼睛", "看不见了看不见了", "戳瞎了算谁的", "眼睛很脆弱的", "再戳要戴眼镜了",
    ]
    static let mouthLines = [
        "别捅嘴", "唔……", "说不出话了", "嘴巴不是给你点的", "别摸嘴啦", "再戳就咬你",
    ]
    static let armLines = [
        "别扯我手", "手要断了", "我还要挥手的", "松手松手", "胳膊肘疼", "别拽，我在打招呼",
    ]
    static let footLines = [
        "痒！", "踩我脚干嘛", "别挠脚心", "脚趾都缩起来了", "走不动了", "脚很敏感的好吗",
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
    /// 真实流逝的秒数。t 会被每帧限幅，系统限流时走得比现实慢，计时类逻辑必须用这个
    var clockOrigin: TimeInterval = 0
    var clock: TimeInterval { CACurrentMediaTime() - clockOrigin }

    var nextBlink: TimeInterval = 1.5
    var blinkEnd: TimeInterval = 0
    var nextIdle: TimeInterval = 4
    var idleStart: TimeInterval = -10
    var idleKind: Int = 0
    var idleSign: CGFloat = 1

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

    // 聊天
    var config = ChatConfig()
    var chatHistory: [[String: String]] = []
    var chatInput: ChatInputWindow?
    var settingsWindow: SettingsWindow?

    // 番茄钟
    var pomoMode: PomoMode = .none
    var pomoEnd: TimeInterval = 0
    var pomoPrompt: PomoPromptPanel?
    var focusMinutes = 25
    var restMinutes = 5
    var lastStatusUpdate: TimeInterval = -10
    var lastStatusTitle = ""

    // 久坐提醒
    var stretchMinutes = 45
    var nextStretch: TimeInterval = .infinity

    // 主动提醒：专注和全屏时先攒着
    var heldNudges: [HeldNudge] = []
    var quietInFullScreen = true
    var fullScreenNow = false
    var fullScreenLastSeen = false
    var sawDesktop = false
    var lastFullScreenCheck: TimeInterval = -10

    // 剪贴板
    var clipboardEnabled = true
    var clipExcludedApps: [String: String] = [:]      // bundle ID → 显示名
    var lastOtherApp: (id: String, name: String)?
    var clipItems: [ClipEntry] = []
    var clipChangeCount = -1
    var lastClipPoll: TimeInterval = -10
    var clipPanel: ClipboardPanel?
    var hotKey: GlobalHotKey?
    var ocrHotKey: GlobalHotKey?
    var translateHotKey: GlobalHotKey?
    var lastPetFrame: NSRect = .zero
    var lastMouseLeft = false
    var lastMouseRight = false

    // 每天被戳的次数
    var lastSpokenLine = ""
    var resultWindow: ResultWindow?
    var lastResultText = ""
    var soundEnabled = true
    var soundCache: [String: NSSound] = [:]
    var lastSummaryDay = ""
    var clipDay = ""
    var clipToday = 0
    var chatDay = ""
    var chatToday = 0
    var clickDay = ""
    var clickToday = 0

    // 番茄统计
    var pomoDay = ""
    var pomoCount = 0
    var pomoMinutes = 0

    // 好感度
    var xp = 0
    var firstDay = ""
    var lastActiveDay = ""
    var streakDays = 0

    // 时间相关
    var lastLunchDay = ""
    var lastWaterHour = ""
    var activeSeconds: TimeInterval = 0
    var lastActivityCheck: TimeInterval = 0
    var lastTimeCheck: TimeInterval = -100
    var lastBreakAt: TimeInterval = -1000

    // 系统状态
    var lastBatteryCheck: TimeInterval = -100
    var batteryLowWarned = false
    var lastCPUSample: TimeInterval = -100
    var cpuBusyStreak = 0
    var lastCPUTicks: (UInt32, UInt32, UInt32, UInt32)?
    var lastSweatAt: TimeInterval = -1000
    var networkWasUp = true
    var networkMonitor: NWPathMonitor?

    static let stretchLines = [
        "起来走两步吧", "喝口水，伸个懒腰", "坐久了腰会疼", "让眼睛歇一会儿",
        "站起来扭扭脖子", "别坐成一根香蕉",
    ]

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
        loadPrefs()
        setupHotKey()

        startNetworkMonitor()
        startTrackingFrontApp()

        // 临时诊断：记录本进程真实的屏幕录制权限（区分终端启动 / open 启动）
        let permLog = "/tmp/jiaoge-perm.log"
        let line = "启动权限=\(CGPreflightScreenCaptureAccess()) 路径=\(Bundle.main.bundlePath)\n"
        if let h = FileHandle(forWritingAtPath: permLog) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile()
        } else {
            try? line.write(toFile: permLog, atomically: true, encoding: .utf8)
        }

        // 命令行问一句就走：--ask "今天天气"（可用 JIAOGE_API_URL / JIAOGE_MODEL / JIAOGE_API_KEY 覆盖配置）
        if let i = CommandLine.arguments.firstIndex(of: "--ask"), i + 1 < CommandLine.arguments.count {
            runAsk(CommandLine.arguments[i + 1])
        }

        if CommandLine.arguments.contains("--self-test") {
            // 等菜单栏布局完成再测，否则读到的坐标还是 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.runSelfTest()
                NSApp.terminate(nil)
            }
        }

        if CommandLine.arguments.contains("--check-capture") {
            print("屏幕录制权限预检: \(CGPreflightScreenCaptureAccess() ? "有" : "没有")")
            let path = "/tmp/jiaoge-capture-test.png"
            try? FileManager.default.removeItem(atPath: path)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-x", path]
            let pipe = Pipe(); task.standardError = pipe
            try? task.run(); task.waitUntilExit()
            let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let size = (try? Data(contentsOf: URL(fileURLWithPath: path)))?.count ?? 0
            print("截图测试: 文件 \(size) 字节, 退出码 \(task.terminationStatus), stderr: \(err.isEmpty ? "(空)" : err)")
            let opts = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
            let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] ?? []
            let named = list.compactMap { $0[kCGWindowName as String] as? String }.filter { !$0.isEmpty }
            let owners = Set(list.compactMap { $0[kCGWindowOwnerName as String] as? String })
            print("能看到 \(list.count) 个窗口，其中带标题的 \(named.count) 个")
            print("窗口标题样本: \(named.prefix(3).joined(separator: " / "))")
            print("归谁所有: \(owners.sorted().prefix(5).joined(separator: ", "))")
            NSApp.terminate(nil)
        }

        // 自检模式：build 后加参数，跑完自动退出
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.greetByTime()
        }

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

    /// 一键自检：别人反馈问题时让他跑这个
    func runSelfTest() {
        func line(_ ok: Bool, _ text: String) {
            print("  \(ok ? "✅" : "❌") \(text)")
        }
        print("蕉哥自检")
        print("  路径: \(Bundle.main.bundlePath)")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        print("  版本: \(version)  系统: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("  架构: \(Self.architecture())")
        print("")

        // 1. 皇冠素材
        var loaded = 0
        for key in ["iron_1", "brass_4", "bronze_2", "silver_3", "gold_1", "platinum_4",
                    "emerald_2", "diamond_3", "master", "grandmaster", "challenger", "god"] {
            if CrownAssets.image(for: key) != nil { loaded += 1 }
        }
        line(loaded == 12, "皇冠素材: \(loaded)/12 可加载")

        // 2. 配置目录可写
        let probe = Store.dir.appendingPathComponent(".selftest")
        let writable = (try? "ok".write(to: probe, atomically: true, encoding: .utf8)) != nil
        try? FileManager.default.removeItem(at: probe)
        line(writable, "配置目录可写: \(Store.dir.path)")

        // 3. 大模型配置
        let cfg = Store.read("config.json", as: ChatConfig.self)
        line(cfg?.configured ?? false,
             "大模型配置: " + (cfg.map { "\($0.model) @ \($0.baseURL)" } ?? "未配置（聊天和翻译不可用，识字不受影响）"))

        // 4. 屏幕录制权限
        line(CGPreflightScreenCaptureAccess(), "屏幕录制权限: \(CGPreflightScreenCaptureAccess() ? "已授权" : "未授权（截图功能不可用）")")

        // 5. 全局快捷键能否注册
        var registered: [String] = []
        for (name, code) in [("⌃⌥V", ClipboardHotKey.keyCode), ("⌃⌥O", ScreenHotKey.ocrCode),
                             ("⌃⌥T", ScreenHotKey.translateCode)] {
            if GlobalHotKey(keyCode: code, modifiers: ClipboardHotKey.modifiers) != nil {
                registered.append(name)
            }
        }
        let others = NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }.count
        let hotKeyNote = registered.count == 3
            ? ""
            : (others > 0 ? "（蕉哥已经在运行，这项必然失败，属正常）" : "（可能被别的 app 占用了）")
        line(registered.count == 3, "全局快捷键: "
             + (registered.isEmpty ? "注册失败" : registered.joined(separator: " ")) + hotKeyNote)

        // 6. 菜单栏图标：看按钮窗口实际落在屏幕的什么位置
        if let win = statusItem?.button?.window {
            let frame = win.frame
            let screenWidth = NSScreen.main?.frame.width ?? 0
            let onScreen = frame.width > 0 && frame.maxX > 0 && frame.minX < screenWidth
            let hint = onScreen ? "已显示" : "被挤到屏幕外（菜单栏没空间，按住 ⌥ 右键宠物仍可打开菜单）"
            line(onScreen, String(format: "菜单栏图标: %@  位置 x=%.0f 宽 %.0f / 屏幕 %.0f",
                                  hint, frame.minX, frame.width, screenWidth))
        } else {
            line(false, "菜单栏图标: 没有创建（异常，请反馈）")
        }

        // 7. 剪贴板可读
        line(NSPasteboard.general.types != nil, "剪贴板可访问")
        print("")
    }

    static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    // MARK: 主循环

    func startTimer() {
        lastTick = CACurrentMediaTime()
        clockOrigin = lastTick
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func tick() {
        let now = CACurrentMediaTime()
        let elapsed = now - lastTick
        lastTick = now
        let dt = min(elapsed, 0.05)
        t += dt

        // 睡眠或长时间挂起后把截止点整体后移：合上盖子的时间不算久坐，也不该把番茄直接跳过
        if elapsed > 120 {
            if pomoMode != .none { pomoEnd += elapsed }
            if nextStretch.isFinite { nextStretch += elapsed }
        }

        if t >= nextBlink {
            blinkEnd = t + 0.14
            nextBlink = t + Double.random(in: 2.2...5.5)
        }

        if t >= nextIdle && t > happyEnd + 0.6 && !isDragging {
            idleStart = t
            var kind = Int.random(in: 0...6)
            if isLateNight() && Double.random(in: 0...1) < 0.45 { kind = 6 }   // 深夜更容易打瞌睡
            if kind == idleKind { kind = (kind + 1) % 7 }
            idleKind = kind
            idleSign = Bool.random() ? 1 : -1
            nextIdle = t + Double.random(in: 6...13)
            if kind == 3 || kind == 6, Double.random(in: 0...1) < 0.5 {
                nudge(kind == 3 ? "哈啊～" : "zZ…", duration: 1.5)
            }
        }

        // 番茄钟
        if pomoMode != .none && clock >= pomoEnd { finishPomodoro() }

        // 久坐提醒
        if stretchMinutes > 0 && clock >= nextStretch { sedentaryReminder() }

        // 剪贴板（不用每帧读）
        if clipboardEnabled && t - lastClipPoll >= 0.5 {
            lastClipPoll = t
            pollClipboard()
        }

        updateStatusTitle()

        periodicChecks()

        // 点在自己窗口以外的地方就把浮层收起来（不依赖键盘焦点，焦点在别的 app 手上时也管用）
        let buttons = NSEvent.pressedMouseButtons
        let leftDown = buttons & 1 != 0
        let rightDown = buttons & 2 != 0
        let leftEdge = leftDown && !lastMouseLeft
        let rightEdge = rightDown && !lastMouseRight
        lastMouseLeft = leftDown
        lastMouseRight = rightDown
        if leftEdge || rightEdge {
            let p = NSEvent.mouseLocation
            let onPet = window.frame.contains(p)
            let onBubble = bubble.isVisible && bubble.frame.contains(p)
            // 按在自己身上多半是要拖它；按在气泡上是想展开；这两种都不收
            if !onPet && !onBubble { bubble.hideIfSticky() }
            if let panel = clipPanel, panel.isVisible, !panel.frame.contains(p) {
                // 右键点宠物是「开关面板」，交给宠物自己处理，否则会关了又开
                if leftEdge || !onPet { panel.hide() }
            }
            if let input = chatInput, input.isVisible, !input.frame.contains(p) {
                input.hide()
            }
        }

        // 对话框 / 剪贴板面板跟着宠物走
        if window.frame != lastPetFrame {
            lastPetFrame = window.frame
            if let input = chatInput, input.isVisible { input.follow(window) }
            if let panel = clipPanel, panel.isVisible { panel.follow(window) }
        }

        view.crownKey = crownKey
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
                p.mouth = .wavy
                p.tilt = CGFloat(sin(t * 38)) * 0.035
            case 1:
                p.eyeWide = 1.3
                p.mouth = .oh
            default:
                p.eyeStyle = .happy
            }
        }

        let dur: TimeInterval
        switch idleKind {
        case 0: dur = 0.55
        case 1: dur = 1.1
        case 3: dur = 1.7
        case 4: dur = 1.5
        case 5: dur = 0.6
        case 6: dur = 2.4
        default: dur = 0.75
        }
        let ip = (t - idleStart) / dur
        if ip >= 0 && ip <= 1 {
            switch idleKind {
            case 0:
                p.bob += CGFloat(sin(ip * .pi)) * 22
                let tuck = CGFloat(sin(ip * .pi)) * 14
                p.legLift = [tuck, tuck]
            case 1:
                p.eyeOffsetX = CGFloat(sin(ip * .pi * 2)) * 10
            case 3:   // 打哈欠
                let k = CGFloat(sin(ip * .pi))
                p.mouth = .oh
                p.scaleY *= 1 + k * 0.05
                p.bob += k * 3
                p.armRight = k * 0.3
                if ip > 0.3 && ip < 0.8 { p.eyeOpen = 0.06 }
            case 4:   // 歪着头卖萌
                p.tilt = CGFloat(sin(ip * .pi)) * 0.14 * idleSign
                p.eyeOffsetX = 3 * idleSign
            case 5:   // 抖一抖
                let k = CGFloat(sin(ip * .pi))
                p.tilt = CGFloat(sin(ip * .pi * 16)) * 0.07 * k
                p.scaleX *= 1 + CGFloat(sin(ip * .pi * 12)) * 0.03 * k
            case 6:   // 打瞌睡：慢慢合眼 → 闭一会儿 → 睁开
                if ip < 0.25 {
                    p.eyeOpen = 1 - CGFloat(ip) * 3.6
                } else if ip < 0.85 {
                    p.eyeOpen = 0.06
                } else {
                    p.eyeOpen = min(1, (CGFloat(ip) - 0.85) * 6)
                }
                p.bob += CGFloat(sin(ip * .pi * 2)) * 1.4
                p.scaleY *= 1 + CGFloat(sin(ip * .pi)) * 0.02
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
            p.armRight = CGFloat(sin(wp * .pi * 3)) * 0.32
        }

        if isDragging {
            p.scaleY *= 1.07
            p.scaleX *= 0.96
            p.legLift = [12, 4]
            p.eyeWide = 1.15
            p.mouth = .oh
        }

        // 闲着的时候眼睛跟着鼠标转
        let busy = t < happyEnd || isDragging || (ip >= 0 && ip <= 1)
        if !busy, window != nil {
            let mouse = NSEvent.mouseLocation
            let f = window.frame
            let dx = mouse.x - f.midX
            let dy = mouse.y - (f.minY + PET_TOP * 0.62)
            let ptsToArt = 1 / max(ART_SCALE, 0.05)
            p.eyeOffsetX = max(-3.2, min(3.2, dx / 60)) * ptsToArt
            // 屏幕坐标向上为正，参考图坐标向下为正，所以这里要取反
            p.eyeOffsetY = -max(-2.4, min(2.4, dy / 60)) * ptsToArt
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
            let inView = view.convert(event.locationInWindow, from: nil)
            clickFeedback(at: inView.applying(artToView.inverted()))
        } else {
            isDragging = false
            clampToScreen()
            squashStart = t
        }
        dragStartScreen = .zero
    }

    /// 参考图坐标 → 身体部位
    func bodyPart(at p: CGPoint) -> BodyPart {
        for cx in Banana.eyeCenters where hypot(p.x - cx, p.y - Banana.eyeY) < 52 {
            return .eye
        }
        if p.x > 205, p.x < 295, p.y > 408, p.y < 468 { return .mouth }
        if p.y < 152, p.x > 190, p.x < 325 { return .stem }
        if p.y > 636 { return .foot }
        if (p.x < 150 && p.y > 330 && p.y < 610) || (p.x > 345 && p.y > 300 && p.y < 500) {
            return .arm
        }
        return .belly
    }

    func clickFeedback(countsAsClick: Bool = true, at artPoint: CGPoint? = nil) {
        if countsAsClick {
            bumpClickStats()
            addXP(1)
        }
        if t - lastClickTime > 2.2 { clickCount = 0 }
        clickCount += 1
        lastClickTime = t
        reactionLevel = clickCount >= 7 ? 2 : (clickCount >= 4 ? 1 : 0)

        let part = artPoint.map { bodyPart(at: $0) } ?? .belly
        if part == .eye { blinkEnd = t + 0.3 }        // 戳眼睛会本能地闭一下

        playSound("Tink", volume: 0.25)
        happyEnd = t + 1.5
        squashStart = t
        waveStart = t + 0.05
        // 正显示着常驻译文时，戳它只做动作，不拿新台词盖掉译文
        if !bubble.isSticky {
            speak(phrase(for: clickCount, part: part),
                  subtitle: clickCount >= 2 ? "连击 ×\(clickCount)" : "")
        }
        spawnHearts()
    }

    func phrase(for n: Int, part: BodyPart) -> String {
        // 连击到 4 下以后，一半概率变成通用抱怨，一半还是按部位说
        if n >= 4, Bool.random() {
            let pool: [String]
            switch n {
            case 4...6: pool = Self.comboLines2
            case 7...9: pool = Self.comboLines3
            default: pool = Self.comboLines4
            }
            return pool.randomElement() ?? "喂！"
        }
        let pool: [String]
        switch part {
        case .stem: pool = Self.stemLines
        case .eye: pool = Self.eyeLines
        case .mouth: pool = Self.mouthLines
        case .arm: pool = Self.armLines
        case .foot: pool = Self.footLines
        case .belly: pool = Self.lines
        }

        // 别连着说同一句
        var pick = pool.randomElement() ?? "嗨！"
        if pool.count > 1 {
            var tries = 0
            while pick == lastSpokenLine && tries < 4 {
                pick = pool.randomElement() ?? pick
                tries += 1
            }
        }
        lastSpokenLine = pick
        return pick
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

    func speak(_ text: String, subtitle: String = "", duration: TimeInterval = 2.0,
               maxWidth: CGFloat = 240, sticky: Bool = false, onTap: (() -> Void)? = nil) {
        bubble.show(text, subtitle: subtitle, duration: duration, maxWidth: maxWidth,
                    sticky: sticky, onTap: onTap, above: window)
    }

    func spawnHearts() {
        let head = CGPoint(x: 246, y: 240).applying(artToView)
        for i in 0..<4 {
            let angle = Double(i) / 4.0 * .pi + .pi * 0.15
            let speed = CGFloat.random(in: 26...50)
            view.particles.append(Particle(
                x: head.x + CGFloat.random(in: -8...8),
                y: head.y,
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

    func contextMenu() -> NSMenu {
        let menu = NSMenu()
        fillMenu(menu)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        fillMenu(menu)
    }

    /// 剪贴板条目在菜单里显示成一行
    static func preview(_ s: String) -> String {
        let one = s.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ").joined(separator: " ")
        if one.isEmpty { return "（空白内容）" }
        return one.count > 34 ? String(one.prefix(34)) + "…" : one
    }

    func fillMenu(_ menu: NSMenu) {
        // 自己管灰显：默认的自动启用会把 isEnabled = false 顶掉
        menu.autoenablesItems = false

        func action(_ title: String, _ selector: Selector, on: Bool = false, enabled: Bool = true) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            item.state = on ? .on : .off
            item.isEnabled = enabled
            return item
        }
        func note(_ title: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        }
        func folder(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let sub = NSMenu()
            sub.autoenablesItems = false
            items.forEach { sub.addItem($0) }
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = sub
            return item
        }
        func tagged(_ title: String, _ selector: Selector, tag: Int, on: Bool) -> NSMenuItem {
            let item = action(title, selector, on: on)
            item.tag = tag
            return item
        }

        // 常用：直接点
        menu.addItem(action(chatInput?.isVisible == true ? "关闭对话框" : "打开对话框", #selector(toggleChatAction)))
        menu.addItem(action("截图识字（\(ScreenHotKey.ocrLabel)）", #selector(captureOCRAction)))
        menu.addItem(action(config.configured
                                ? "截图翻译（\(ScreenHotKey.translateLabel)）"
                                : "截图翻译（\(ScreenHotKey.translateLabel)）· 需先连接大模型",
                            #selector(captureTranslateAction)))
        menu.addItem(action("查看上次识别结果", #selector(showLastResult), enabled: !lastResultText.isEmpty))
        menu.addItem(.separator())

        // 剪贴板
        var clipItemsMenu = [note("\(ClipboardHotKey.label) 快速呼出"), .separator()]
        if clipItems.isEmpty {
            clipItemsMenu.append(note("（还没有记录）"))
        } else {
            for entry in clipItems.prefix(10) {
                let item = action(entry.title, #selector(copyClipItem(_:)))
                item.representedObject = entry
                if !entry.isImage { item.toolTip = String(entry.text.prefix(300)) }
                clipItemsMenu.append(item)
            }
        }
        clipItemsMenu += [.separator(), action("记录剪贴板", #selector(toggleClipboard), on: clipboardEnabled)]
        if let app = lastOtherApp {
            let builtIn = ClipPrivacy.builtInApps.contains(app.id)
            clipItemsMenu.append(action("不记录「\(app.name)」", #selector(toggleClipExclusion),
                                        on: builtIn || clipExcludedApps[app.id] != nil, enabled: !builtIn))
        }
        if !clipExcludedApps.isEmpty {
            clipItemsMenu.append(folder("已排除的 App", clipExcludedApps.sorted { $0.value < $1.value }.map {
                let item = action($0.value, #selector(removeClipExclusion(_:)))
                item.representedObject = $0.key
                return item
            }))
        }
        clipItemsMenu.append(action("清空历史", #selector(clearClipboard), enabled: !clipItems.isEmpty))
        menu.addItem(folder("剪贴板", clipItemsMenu))

        // 番茄钟
        var pomoItems: [NSMenuItem] = []
        if pomoMode != .none {
            let remain = max(0, Int((pomoEnd - clock).rounded(.up)))
            pomoItems += [note((pomoMode == .focus ? "专注中" : "休息中")
                                   + String(format: " %d:%02d", remain / 60, remain % 60)),
                          .separator()]
        }
        pomoItems += [
            action("开始专注（\(focusMinutes) 分钟）", #selector(startFocus)),
            action("开始休息（\(restMinutes) 分钟）", #selector(startRest)),
            action("停止", #selector(stopPomodoro), enabled: pomoMode != .none || pomoPrompt?.isVisible == true),
            .separator(),
            folder("专注时长", [15, 25, 50].map {
                tagged("\($0) 分钟", #selector(setFocusMinutes(_:)), tag: $0, on: $0 == focusMinutes)
            }),
            folder("休息时长", [5, 10].map {
                tagged("\($0) 分钟", #selector(setRestMinutes(_:)), tag: $0, on: $0 == restMinutes)
            }),
        ]
        menu.addItem(folder("番茄钟", pomoItems))

        // 久坐提醒
        menu.addItem(folder("久坐提醒", [(0, "关闭"), (30, "每 30 分钟"), (45, "每 45 分钟"), (60, "每 60 分钟")].map {
            tagged($0.1, #selector(setStretch(_:)), tag: $0.0, on: $0.0 == stretchMinutes)
        }))
        menu.addItem(.separator())

        // 跟宠物有关的：今天的数据和逗它玩
        rollOverPomodoroStats()
        let streakText = streakDays >= 2 ? "连续 \(streakDays) 天 · " : ""
        menu.addItem(folder("好感度 \(levelSummary)", [
            action("\(streakText)认识第 \(daysKnown()) 天", #selector(showAffinity)),
            note("今天被戳了 \(clickToday) 次"),
            note("今天专注 \(pomoCount) 个番茄 · \(pomoMinutes) 分钟"),
            .separator(),
            action("看看今天的小结", #selector(showSummary)),
            action("让它说句话", #selector(speakRandom)),
            action("让它跳一下", #selector(hopNow)),
        ]))
        menu.addItem(.separator())

        // 设置
        let targetItems = SettingsWindow.targetLanguages.enumerated().map { index, name -> NSMenuItem in
            let value = index == 0 ? "" : name
            let item = action(name, #selector(setTargetLanguage(_:)), on: value == config.targetLanguage)
            item.representedObject = value
            return item
        }
        let presets: [(String, CGFloat)] = [("小", 3), ("中", 4), ("大", 5.5), ("超大", 7)]
        let sizeItems = presets.map { title, cell -> NSMenuItem in
            let item = action(title, #selector(changeSize(_:)), on: abs(cell - CELL) < 0.01)
            item.representedObject = NSNumber(value: Double(cell))
            return item
        }
        menu.addItem(folder("设置", [
            folder("翻译目标语言", targetItems),
            folder("大小", sizeItems),
            action("回到默认位置", #selector(resetPosition)),
            .separator(),
            action("音效", #selector(toggleSound), on: soundEnabled),
            action("开机自动启动", #selector(toggleLaunchAtLogin), on: launchAtLoginEnabled()),
            action("全屏时暂停提醒", #selector(toggleQuietInFullScreen), on: quietInFullScreen),
            .separator(),
            action("清空聊天记忆", #selector(clearChatHistory)),
        ]))
        // 首次配置的说明都指向这一项，留在第一层
        menu.addItem(action("大模型设置…", #selector(openSettingsAction)))

        let quitItem = NSMenuItem(title: "退出蕉哥", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🍌"
        statusItem.button?.toolTip = "蕉哥"
        lastStatusTitle = "🍌"
        let menu = NSMenu()
        fillMenu(menu)          // 先填一份兜底，每次打开时 delegate 还会再刷
        menu.delegate = self
        statusItem.menu = menu

        // 菜单栏如果放不下（刘海屏 + 图标很多），图标会被系统藏掉，这里做个兜底提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, !self.statusItem.isVisible else { return }
            self.speak("菜单栏放不下我…按住 ⌥ 右键我，能打开菜单",
                       subtitle: "备用入口", duration: 8, maxWidth: 300)
        }
    }

    // MARK: 偏好与统计

    func loadPrefs() {
        let d = UserDefaults.standard
        if let v = d.object(forKey: "focusMinutes") as? Int, v > 0 { focusMinutes = v }
        if let v = d.object(forKey: "restMinutes") as? Int, v > 0 { restMinutes = v }
        if let v = d.object(forKey: "stretchMinutes") as? Int, v >= 0 { stretchMinutes = v }
        if d.object(forKey: "clipboardEnabled") != nil { clipboardEnabled = d.bool(forKey: "clipboardEnabled") }
        if d.object(forKey: "quietInFullScreen") != nil { quietInFullScreen = d.bool(forKey: "quietInFullScreen") }
        clipExcludedApps = d.dictionary(forKey: "clipExcludedApps") as? [String: String] ?? [:]
        config = Store.read("config.json", as: ChatConfig.self) ?? ChatConfig()
        if let entries = Store.read("clipboard.json", as: [ClipEntry].self) {
            clipItems = entries
        } else if let old = Store.read("clipboard.json", as: [String].self) {
            clipItems = old.map { ClipEntry(kind: "text", text: $0) }   // 旧版本存的是纯字符串数组
        }
        sortClips()
        clipChangeCount = NSPasteboard.general.changeCount
        resetStretchTimer()
        loadClickStats()

        pomoDay = d.string(forKey: "pomoDay") ?? ""
        pomoCount = d.integer(forKey: "pomoCount")
        pomoMinutes = d.integer(forKey: "pomoMinutes")
        rollOverPomodoroStats()
        xp = d.integer(forKey: "petXP")
        lastActiveDay = d.string(forKey: "lastActiveDay") ?? ""
        streakDays = d.integer(forKey: "streakDays")
        firstDay = d.string(forKey: "petFirstDay") ?? ""
        if firstDay.isEmpty {
            firstDay = dayKey()
            d.set(firstDay, forKey: "petFirstDay")
        }
        lastLunchDay = d.string(forKey: "lastLunchDay") ?? ""
        lastWaterHour = d.string(forKey: "lastWaterHour") ?? ""
        if d.object(forKey: "soundEnabled") != nil { soundEnabled = d.bool(forKey: "soundEnabled") }
        lastSummaryDay = d.string(forKey: "lastSummaryDay") ?? ""
        clipDay = d.string(forKey: "clipDay") ?? ""
        clipToday = d.integer(forKey: "clipToday")
        chatDay = d.string(forKey: "chatDay") ?? ""
        chatToday = d.integer(forKey: "chatToday")
        rollOverChatDays()
        chatHistory = Store.read("chat.json", as: [[String: String]].self) ?? []
        if chatHistory.count > 50 { chatHistory.removeFirst(chatHistory.count - 50) }
    }

    func resetStretchTimer() {
        nextStretch = stretchMinutes > 0 ? clock + Double(stretchMinutes) * 60 : .infinity
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func dayKey() -> String { Self.dayFormatter.string(from: Date()) }

    func loadClickStats() {
        let d = UserDefaults.standard
        clickDay = d.string(forKey: "clickDay") ?? ""
        clickToday = d.integer(forKey: "clickToday")
        let today = dayKey()
        if clickDay != today {
            clickDay = today
            clickToday = 0
            saveClickStats()
        }
    }

    func saveClickStats() {
        let d = UserDefaults.standard
        d.set(clickDay, forKey: "clickDay")
        d.set(clickToday, forKey: "clickToday")
    }

    func bumpClickStats() {
        let today = dayKey()
        if clickDay != today {
            clickDay = today
            clickToday = 0
        }
        clickToday += 1
        saveClickStats()
    }

    // MARK: 番茄钟

    func startPomodoro(_ mode: PomoMode) {
        let minutes = mode == .focus ? focusMinutes : restMinutes
        pomoPrompt?.dismiss()
        pomoMode = mode
        pomoEnd = clock + Double(minutes) * 60
        happyEnd = t + 1.4
        waveStart = t + 0.05
        speak(mode == .focus ? "专注 \(minutes) 分钟，开始！" : "休息 \(minutes) 分钟～",
              subtitle: "🍅 番茄钟", duration: 3)
        updateStatusTitle(force: true)
    }

    func finishPomodoro() {
        let finished = pomoMode
        pomoMode = .none
        pomoEnd = 0
        updateStatusTitle(force: true)

        if finished == .focus {
            idleStart = t
            idleKind = 0
            nextIdle = t + 8
            rollOverPomodoroStats()
            pomoCount += 1
            pomoMinutes += focusMinutes
            savePomodoroStats()
            playSound("Glass", volume: 0.5)
            showPomodoroPrompt(for: .rest)      // 先弹卡片再加经验，升级提示要等卡片收起才说
            addXP(20)
        } else {
            happyEnd = t + 1.4
            playSound("Ping", volume: 0.4)
            showPomodoroPrompt(for: .focus)
        }
    }

    /// 一段计时结束后不自动接着走，先问一句：开始下一段，还是先算了
    func showPomodoroPrompt(for next: PomoMode) {
        let panel = pomoPrompt ?? PomoPromptPanel()
        pomoPrompt = panel
        let minutes = next == .focus ? focusMinutes : restMinutes
        let message = next == .rest ? "专注结束，休息一下？" : "休息结束，继续专注吗？"
        let detail = next == .rest
            ? "🍅 今天第 \(pomoCount) 个番茄"
            : "🍅 已完成 \(pomoCount) 个番茄"
        panel.present(message: message, detail: detail,
                      actionTitle: next == .rest ? "开始休息（\(minutes) 分钟）" : "开始专注（\(minutes) 分钟）",
                      above: window) { [weak self] in
            self?.startPomodoro(next)
        }
    }

    func updateStatusTitle(force: Bool = false) {
        if !force && t - lastStatusUpdate < 0.3 { return }
        lastStatusUpdate = t
        let title: String
        if pomoMode == .none {
            title = "🍌"
        } else {
            let remain = max(0, Int((pomoEnd - clock).rounded(.up)))
            title = String(format: "🍌 %d:%02d", remain / 60, remain % 60)
        }
        if title != lastStatusTitle {
            lastStatusTitle = title
            statusItem?.button?.title = title
        }
    }

    // MARK: 久坐提醒

    func sedentaryReminder() {
        idleStart = t
        idleKind = 2
        nextIdle = t + 8
        nudge(Self.stretchLines.randomElement() ?? "起来动动",
              subtitle: "坐了 \(stretchMinutes) 分钟了", duration: 8,
              sound: "Ping", holdAs: "stretch")
        nextStretch = clock + Double(stretchMinutes) * 60
    }

    // MARK: 主动提醒

    /// 这会儿别主动开口：专注中、全屏中、番茄卡片正等你选，或者气泡上留着译文
    var isQuiet: Bool {
        pomoMode == .focus
            || (quietInFullScreen && fullScreenNow)
            || pomoPrompt?.isVisible == true
            || bubble.isSticky
    }

    /// 蕉哥主动找你说的话都走这里（戳它、菜单反馈这类你先动手的还是直接 speak）。
    /// 安静时给了 holdAs 的攒到之后合并着说，同类只留最新；没给的过时就没意义，直接算了
    func nudge(_ text: String, subtitle: String = "", duration: TimeInterval = 2.0, maxWidth: CGFloat = 240,
               sound: String? = nil, volume: Float = 0.4, holdAs key: String? = nil) {
        guard isQuiet else {
            if let sound = sound { playSound(sound, volume: volume) }
            speak(text, subtitle: subtitle, duration: duration, maxWidth: maxWidth)
            return
        }
        guard let key = key else { return }
        heldNudges.removeAll { $0.key == key }
        heldNudges.append(HeldNudge(key: key, text: text, hasSound: sound != nil, time: clock))
    }

    /// 安静结束、气泡也空出来了，把攒的话合成一个气泡说掉。放太久的（比如全屏看了一下午）就不提了
    func flushHeldNudges() {
        guard !heldNudges.isEmpty, !isQuiet, !bubble.isVisible else { return }
        let fresh = heldNudges.filter { clock - $0.time < 3600 }
        heldNudges.removeAll()
        guard !fresh.isEmpty else { return }
        if fresh.contains(where: { $0.hasSound }) { playSound("Ping", volume: 0.4) }
        speak(fresh.map { $0.text }.joined(separator: "\n"), subtitle: "刚才没打扰你",
              duration: min(20, 6 + Double(fresh.count) * 2), maxWidth: 300)
    }

    func checkFullScreen() {
        // 前台是自己（开着面板或对话框）时看不出别人的状态，沿用上一次
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let seen = FullScreenDetector.isFullScreen(windows: windows,
                                                   displays: FullScreenDetector.activeDisplays(),
                                                   frontPID: front.processIdentifier,
                                                   sawDesktop: &sawDesktop)
        // 连续两次一样才算数，切 Space 和调度中心的动画不算
        if seen == fullScreenLastSeen { fullScreenNow = seen }
        fullScreenLastSeen = seen
    }

    // MARK: 剪贴板

    /// 单行的 token 之类不记，免得把密钥存进历史
    static func looksSecret(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 20, t.count <= 200, !t.contains(" ") else { return false }
        return ["sk-", "sk_", "AKIA", "ghp_", "gho_", "xoxb-", "xoxp-"].contains { t.hasPrefix($0) }
    }

    /// 记住最近一个不是自己的前台 app：点开宠物菜单或面板时，蕉哥自己会变成前台
    func startTrackingFrontApp() {
        noteFrontApp(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            self?.noteFrontApp(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

    func noteFrontApp(_ app: NSRunningApplication?) {
        guard let app = app, app != NSRunningApplication.current, let id = app.bundleIdentifier else { return }
        lastOtherApp = (id, app.localizedName ?? id)
    }

    func pollClipboard(_ pb: NSPasteboard = .general) {
        guard pb.changeCount != clipChangeCount else { return }
        clipChangeCount = pb.changeCount

        // 密码之类的内容连读都不读，文字和图片一起拦
        guard !ClipPrivacy.shouldSkip(types: (pb.types ?? []).map { $0.rawValue },
                                      appID: lastOtherApp?.id,
                                      excluded: Set(clipExcludedApps.keys)) else { return }

        // 在访达里复制图片文件：优先当图片
        let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
        let imageExts = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp", "bmp"]
        if let file = urls.first(where: { $0.isFileURL && imageExts.contains($0.pathExtension.lowercased()) }),
           let image = NSImage(contentsOf: file),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]),
           let entry = ClipStore.saveImage(png) {
            insertClip(entry)
            return
        }

        // 截图 / 网页里复制的图：通常没有文本
        let text = pb.string(forType: .string) ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let entry = readClipboardImage(pb) {
            insertClip(entry)
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, text.count < 200_000,
              !Self.looksSecret(text),
              !(clipItems.first?.kind == "text" && clipItems.first?.text == text) else { return }
        rollOverChatDays()
        clipToday += 1
        saveDayCounters()
        insertClip(ClipEntry(kind: "text", text: text, time: Date().timeIntervalSince1970))
    }

    func readClipboardImage(_ pb: NSPasteboard) -> ClipEntry? {
        var data: Data?
        if let png = pb.data(forType: .png) {
            data = png
        } else if let tiff = pb.data(forType: .tiff),
                  let rep = NSBitmapImageRep(data: tiff) {
            data = rep.representation(using: .png, properties: [:])
        }
        guard let png = data else { return nil }
        return ClipStore.saveImage(png)
    }

    func insertClip(_ entry: ClipEntry) {
        clipItems.removeAll { $0 == entry }
        clipItems.insert(entry, at: 0)
        sortClips()
        while clipItems.count > 20 {
            // 先淘汰没置顶的最旧一条
            let index = clipItems.lastIndex(where: { !$0.pinned }) ?? clipItems.count - 1
            let dropped = clipItems.remove(at: index)
            if dropped.isImage { ClipStore.deleteImage(of: dropped) }
        }
        Store.write(clipItems, to: "clipboard.json")
    }

    /// 置顶的排前面，其余按时间倒序
    func sortClips() {
        clipItems.sort { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.time > b.time
        }
    }

    func togglePin(_ entry: ClipEntry) {
        guard let index = clipItems.firstIndex(where: { $0 == entry }) else { return }
        clipItems[index].pinned.toggle()
        sortClips()
        Store.write(clipItems, to: "clipboard.json")
        clipPanel?.update(items: Array(clipItems.prefix(20)))
    }

    // MARK: 聊天

    func openChat() {
        guard config.configured else {
            speak("先设置一下要用的模型", subtitle: "大模型设置", duration: 3)
            openSettings()
            return
        }
        if chatInput == nil {
            chatInput = ChatInputWindow()
            chatInput?.onSubmit = { [weak self] text in self?.sendChat(text) }
        }
        bubble.hideNow()
        chatInput?.present(above: window)
    }

    /// 右键（或菜单）开关对话框
    func toggleChat() {
        if let input = chatInput, input.isVisible {
            input.hide()
        } else {
            openChat()
        }
    }

    func sendChat(_ text: String) {
        rollOverChatDays()
        chatHistory.append(["role": "user", "content": text])
        if chatHistory.count > 50 { chatHistory.removeFirst(chatHistory.count - 50) }
        saveChatHistory()

        speak("…", duration: 60, maxWidth: 120)

        var messages: [[String: String]] = [[
            "role": "system",
            "content": "你是一只叫蕉哥的香蕉桌宠，性格活泼、说话口语化。用户正坐在电脑前工作，你是陪着他的小助手。回答简短，尽量两三句话讲完，不要用 Markdown。",
        ]]
        messages += chatHistory

        llmChat(config: config, messages: messages) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let reply):
                let clean = Self.plainish(reply.text.isEmpty ? "……" : reply.text)
                self.chatHistory.append(["role": "assistant", "content": clean])
                if self.chatHistory.count > 50 {
                    self.chatHistory.removeFirst(self.chatHistory.count - 50)
                }
                self.saveChatHistory()
                self.chatToday += 1
                self.saveDayCounters()
                self.playSound("Pop", volume: 0.3)
                self.happyEnd = self.t + 1.4
                self.addXP(5)
                self.speak(clean, duration: 15, maxWidth: 300)
            case .failure(let error):
                self.playSound("Basso", volume: 0.35)
                self.speak("聊不下去了：\(error.localizedDescription)", duration: 6, maxWidth: 300)
            }
        }
    }

    /// 去掉简单的 Markdown 记号
    static func plainish(_ s: String) -> String {
        var text = s
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        text = text.replacingOccurrences(of: #"^[#>\-\*]+\s*"#, with: "", options: .regularExpression)
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func runAsk(_ text: String) {
        var cfg = config
        let env = ProcessInfo.processInfo.environment
        if let v = env["JIAOGE_API_URL"] { cfg.baseURL = v }
        if let v = env["JIAOGE_MODEL"] { cfg.model = v }
        if let v = env["JIAOGE_API_KEY"] { cfg.apiKey = v }
        llmChat(config: cfg, messages: [["role": "user", "content": text]]) { result in
            switch result {
            case .success(let reply): print("REPLY: \(reply.text)")
            case .failure(let error): print("ERROR: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { NSApp.terminate(nil) }
    }

    // MARK: 设置

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.onSave = { [weak self] newConfig in
                guard let self = self else { return }
                let wasConfigured = self.config.configured
                self.config = newConfig
                self.speak(wasConfigured ? "设置已更新" : "连上了，现在可以聊天和翻译了",
                           subtitle: newConfig.model, duration: 3)
            }
        }
        settingsWindow?.present(config: config)
    }

    // MARK: 音效

    func playSound(_ name: String, volume: Float = 0.35) {
        guard soundEnabled else { return }
        let sound: NSSound
        if let cached = soundCache[name] {
            sound = cached
        } else if let loaded = NSSound(named: NSSound.Name(name)) {
            soundCache[name] = loaded
            sound = loaded
        } else {
            return
        }
        sound.volume = volume
        if sound.isPlaying { sound.stop() }
        sound.play()
    }

    @objc func toggleQuietInFullScreen() {
        quietInFullScreen.toggle()
        UserDefaults.standard.set(quietInFullScreen, forKey: "quietInFullScreen")
        if !quietInFullScreen { fullScreenNow = false }
        speak(quietInFullScreen ? "全屏时我先不打扰你" : "全屏时也照常提醒")
    }

    @objc func toggleSound() {
        soundEnabled.toggle()
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        if soundEnabled { playSound("Tink", volume: 0.3) }
    }

    // MARK: 聊天记忆

    func saveChatHistory() {
        Store.write(chatHistory, to: "chat.json")
    }

    @objc func clearChatHistory() {
        chatHistory.removeAll()
        saveChatHistory()
        speak("聊天记录清空了", duration: 2.5)
    }

    // MARK: 每日小结

    func rollOverChatDays() {
        let today = dayKey()
        var changed = false
        if clipDay != today { clipDay = today; clipToday = 0; changed = true }
        if chatDay != today { chatDay = today; chatToday = 0; changed = true }
        if changed {
            let d = UserDefaults.standard
            d.set(clipDay, forKey: "clipDay")
            d.set(clipToday, forKey: "clipToday")
            d.set(chatDay, forKey: "chatDay")
            d.set(chatToday, forKey: "chatToday")
        }
    }

    func saveDayCounters() {
        let d = UserDefaults.standard
        d.set(clipDay, forKey: "clipDay")
        d.set(clipToday, forKey: "clipToday")
        d.set(chatDay, forKey: "chatDay")
        d.set(chatToday, forKey: "chatToday")
    }

    func summaryText() -> String {
        var parts: [String] = []
        if clickToday > 0 { parts.append("被戳了 \(clickToday) 次") }
        if pomoCount > 0 { parts.append("专注 \(pomoCount) 个番茄共 \(pomoMinutes) 分钟") }
        if clipToday > 0 { parts.append("复制了 \(clipToday) 段内容") }
        if chatToday > 0 { parts.append("跟我聊了 \(chatToday) 次") }
        guard !parts.isEmpty else { return "今天都没怎么理我……明天多陪陪我呗" }
        return "今天" + parts.joined(separator: "，") + "。辛苦啦，早点休息"
    }

    @objc func showSummary() {
        playSound("Glass", volume: 0.4)
        speak(summaryText(), subtitle: "今日小结", duration: 9, maxWidth: 300)
    }

    // MARK: 时间与主动提醒

    func hourNow() -> Int { Calendar.current.component(.hour, from: Date()) }
    func isLateNight() -> Bool {
        let h = hourNow()
        return h >= 22 || h < 6
    }

    func greetByTime() {
        // 还没配置模型：多半是刚装好。直接弹设置窗口，不依赖菜单栏图标
        if !config.configured {
            speak("第一次用？先把模型配上就能聊天了", subtitle: "设置窗口这就打开", duration: 5, maxWidth: 300)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.openSettings()
            }
            return
        }
        let h = hourNow()
        if h >= 5 && h < 11 {
            nudge("早上好！今天也一起加油", subtitle: "🌤 早上好", duration: 3)
        } else if h >= 11 && h < 14 {
            nudge("中午好，记得吃饭", subtitle: "🍚", duration: 3)
        } else if h >= 18 && h < 22 {
            nudge("晚上好，今天辛苦了", subtitle: "🌆", duration: 3)
        } else if h >= 22 || h < 5 {
            nudge("这么晚还不睡？", subtitle: "🌙 晚安", duration: 3)
        }
    }

    func periodicChecks() {
        // 每 5 秒：统计连续用电脑的时长
        if clock - lastActivityCheck >= 5 {
            let step = clock - lastActivityCheck
            lastActivityCheck = clock
            if secondsSinceUserInput() < 120 {
                activeSeconds += step
            } else {
                activeSeconds = 0
            }
            if activeSeconds > 90 * 60, clock - lastBreakAt > 1800 {
                activeSeconds = 0
                lastBreakAt = clock
                idleStart = t
                idleKind = 2
                nudge("连续忙了一个半小时，起来动动", subtitle: "☕️", duration: 5, holdAs: "break")
            }
        }
        if clock - lastTimeCheck >= 30 {
            lastTimeCheck = clock
            timeChecks()
        }
        if clock - lastBatteryCheck >= 300 {
            lastBatteryCheck = clock
            batteryCheck()
        }
        if clock - lastCPUSample >= 10 {
            lastCPUSample = clock
            cpuCheck()
        }
        if quietInFullScreen, clock - lastFullScreenCheck >= 2 {
            lastFullScreenCheck = clock
            checkFullScreen()
        }
        flushHeldNudges()
    }

    func timeChecks() {
        guard t > 300 else { return }        // 刚启动先别急着提醒
        let h = hourNow()
        let today = dayKey()

        if h == 12, lastLunchDay != today {
            lastLunchDay = today
            UserDefaults.standard.set(today, forKey: "lastLunchDay")
            nudge("到饭点了，先去吃饭吧", subtitle: "🍚 午饭", duration: 4, holdAs: "lunch")
        }
        let minutes = Calendar.current.component(.minute, from: Date())
        if h * 60 + minutes >= 21 * 60 + 30, lastSummaryDay != today {
            lastSummaryDay = today
            UserDefaults.standard.set(today, forKey: "lastSummaryDay")
            nudge(summaryText(), subtitle: "今日小结", duration: 9, maxWidth: 300,
                  sound: "Glass", holdAs: "summary")
        }

        if h >= 9, h <= 21 {
            let key = "\(today)-\(h)"
            if lastWaterHour != key {
                lastWaterHour = key
                UserDefaults.standard.set(key, forKey: "lastWaterHour")
                nudge("喝口水吧", subtitle: "💧", duration: 3, holdAs: "water")
            }
        }
    }

    func secondsSinceUserInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                eventType: CGEventType(rawValue: UInt32.max)!)
    }

    func batteryCheck() {
        guard let state = batteryState() else { return }
        if state.charging {
            batteryLowWarned = false
            heldNudges.removeAll { $0.key == "battery" }
            return
        }
        if state.percent <= 20, !batteryLowWarned {
            batteryLowWarned = true
            nudge("电量只剩 \(state.percent)% 了", subtitle: "🔋 记得充电", duration: 5, holdAs: "battery")
        }
    }

    func batteryState() -> (percent: Int, charging: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let maxCapacity = info[kIOPSMaxCapacityKey] as? Int, maxCapacity > 0 else { continue }
            let onAC = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (current * 100 / maxCapacity, onAC)
        }
        return nil
    }

    func cpuCheck() {
        let busy = cpuBusyPercent()
        if busy > 0.85 {
            cpuBusyStreak += 1
        } else {
            cpuBusyStreak = max(0, cpuBusyStreak - 1)
        }
        if cpuBusyStreak >= 3, t - lastSweatAt > 600 {
            cpuBusyStreak = 0
            lastSweatAt = t
            idleStart = t
            idleKind = 5
            nudge("好热，电脑在拼命了", subtitle: "🔥 CPU", duration: 4)
        }
    }

    func cpuBusyPercent() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let ticks = (info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3)
        defer { lastCPUTicks = ticks }
        guard let previous = lastCPUTicks else { return 0 }
        let user = Double(ticks.0 &- previous.0)
        let system = Double(ticks.1 &- previous.1)
        let idle = Double(ticks.2 &- previous.2)
        let nice = Double(ticks.3 &- previous.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return (user + system + nice) / total
    }

    func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let up = path.status == .satisfied
            DispatchQueue.main.async { self?.networkChanged(up) }
        }
        monitor.start(queue: DispatchQueue(label: "jiaoge.network"))
        networkMonitor = monitor
    }

    func networkChanged(_ up: Bool) {
        defer { networkWasUp = up }
        guard up != networkWasUp else { return }
        nudge(up ? "网回来了" : "网好像断了", subtitle: up ? "🌐" : "⚠️", duration: 3)
    }

    // MARK: 好感度

    /// 升到某一级需要的累计经验 = 13 × N × (N-1) / 2
    /// 也就是每级要 13、26、39、52… 经验
    static func xpToReach(_ level: Int) -> Int {
        13 * level * (level - 1) / 2
    }

    /// 到这一级进入大师，之后改按分数算
    static let masterLevel = 33
    /// 大师以后：每 2 点经验 = 1 分
    static let xpPerPoint = 2
    /// 分数对应的段位
    static let grandmasterPoints = 800
    static let challengerPoints = 1200
    static let godPoints = 2000

    var level: Int {
        var current = 1
        while xp >= Self.xpToReach(current + 1) { current += 1 }
        return current
    }

    /// 大师之后的积分
    var rankPoints: Int {
        max(0, (xp - Self.xpToReach(Self.masterLevel)) / Self.xpPerPoint)
    }

    /// 段位：黑铁／黄铜／青铜／白银／黄金／铂金／翡翠／钻石 各 IV–I 共 32 级，
    /// 之后按分数：大师 → 宗师（800）→ 王者（1200）→ 神（2000，隐藏段位）
    static func title(for level: Int) -> String {
        let tiers = ["黑铁", "黄铜", "青铜", "白银", "黄金", "铂金", "翡翠", "钻石"]
        let divisions = ["IV", "III", "II", "I"]
        if level <= 32 {
            let index = level - 1
            return "\(tiers[index / 4]) \(divisions[index % 4])"
        }
        return "大师"
    }

    var rankTitle: String {
        if level < Self.masterLevel { return Self.title(for: level) }
        let points = rankPoints
        if points >= Self.godPoints { return "神" }
        if points >= Self.challengerPoints { return "王者" }
        if points >= Self.grandmasterPoints { return "宗师" }
        return "大师"
    }

    /// 当前段位对应的皇冠素材（大段位 + 小段位，如 iron_3）
    var crownKey: String {
        if level < Self.masterLevel {
            let keys = ["iron", "brass", "bronze", "silver", "gold", "platinum", "emerald", "diamond"]
            let tier = keys[min((level - 1) / 4, keys.count - 1)]
            let division = (level - 1) % 4 + 1        // 1 = IV（最低）… 4 = I（最高）
            return "\(tier)_\(division)"
        }
        let points = rankPoints
        if points >= Self.godPoints { return "god" }
        if points >= Self.challengerPoints { return "challenger" }
        if points >= Self.grandmasterPoints { return "grandmaster" }
        return "master"
    }

    var levelTitle: String {
        level < Self.masterLevel ? Self.title(for: level) : "\(rankTitle) \(rankPoints) 分"
    }

    var levelProgress: (current: Int, needed: Int) {
        let base = Self.xpToReach(level)
        let next = Self.xpToReach(level + 1)
        return (xp - base, max(1, next - base))
    }

    var levelSummary: String {
        if level >= Self.masterLevel { return levelTitle }
        let progress = levelProgress
        return "Lv.\(level) \(levelTitle) · \(progress.current)/\(progress.needed)"
    }

    // 逢这些等级说一句特别的话（大师之后改用段位变化来触发）
    static let milestones: [Int: String] = [
        5: "我们算是朋友了吧？",
        10: "十级了，谢谢你一直带着我",
        20: "二十级！这可不是谁都能到的",
        30: "三十级，老朋友了",
    ]

    func addXP(_ amount: Int) {
        applyXP(amount)
        awardDailyBonusIfNeeded()
    }

    func applyXP(_ amount: Int) {
        let beforeLevel = level
        let beforeRank = rankTitle
        xp += amount
        UserDefaults.standard.set(xp, forKey: "petXP")
        guard level > beforeLevel || rankTitle != beforeRank else { return }

        happyEnd = t + 2
        spawnHearts()
        let line: String
        if rankTitle != beforeRank {
            line = rankTitle == "神" ? "……你走到这里了" : "上分到\(rankTitle)了！"
        } else {
            line = Self.milestones[level] ?? "我们更熟了！"
        }
        nudge(line, subtitle: "好感度 \(levelSummary)", duration: 4, sound: "Glass", volume: 0.45, holdAs: "levelup")
    }

    /// 每天第一次互动给一点奖励，连续的天数越多给得越多
    func awardDailyBonusIfNeeded() {
        let today = dayKey()
        guard lastActiveDay != today else { return }
        let yesterday = Self.dayFormatter.string(from: Date().addingTimeInterval(-86400))
        streakDays = (lastActiveDay == yesterday) ? streakDays + 1 : 1
        lastActiveDay = today
        let d = UserDefaults.standard
        d.set(lastActiveDay, forKey: "lastActiveDay")
        d.set(streakDays, forKey: "streakDays")

        let bonus = min(50, 5 + streakDays * 5)
        applyXP(bonus)
        if streakDays >= 2 {
            nudge("连续第 \(streakDays) 天", subtitle: "陪伴奖励", duration: 3, holdAs: "streak")
        }
    }

    func daysKnown() -> Int {
        guard let start = Self.dayFormatter.date(from: firstDay) else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(1, days + 1)
    }

    // MARK: 番茄统计

    func rollOverPomodoroStats() {
        let today = dayKey()
        if pomoDay != today {
            pomoDay = today
            pomoCount = 0
            pomoMinutes = 0
            savePomodoroStats()
        }
    }

    func savePomodoroStats() {
        let d = UserDefaults.standard
        d.set(pomoDay, forKey: "pomoDay")
        d.set(pomoCount, forKey: "pomoCount")
        d.set(pomoMinutes, forKey: "pomoMinutes")
    }

    // MARK: 开机自启

    func launchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLoginEnabled() {
                    try SMAppService.mainApp.unregister()
                    speak("以后不自动开了")
                } else {
                    try SMAppService.mainApp.register()
                    speak("没问题，下次开机我就在", subtitle: "开机自启", duration: 3)
                }
            } catch {
                speak("设置失败：\(error.localizedDescription)", duration: 5, maxWidth: 300)
            }
        } else {
            speak("这个要 macOS 13 以上", duration: 3)
        }
    }

    // MARK: 菜单动作

    @objc func toggleChatAction() { toggleChat() }
    @objc func captureOCRAction() { captureAndRecognize(translate: false) }

    @objc func showAffinity() {
        happyEnd = t + 1.6
        spawnHearts()
        let subtitle = "好感度 \(levelSummary) · 累计 \(xp) 经验"
        let days = daysKnown()
        speak(days <= 1 ? "今天我们刚认识" : "我们已经认识 \(days) 天了",
              subtitle: subtitle, duration: 4)
    }
    @objc func captureTranslateAction() { captureAndRecognize(translate: true) }

    @objc func setTargetLanguage(_ sender: NSMenuItem) {
        config.targetLanguage = sender.representedObject as? String ?? ""
        Store.write(config, to: "config.json")
        speak(config.targetLanguage.isEmpty ? "翻译目标改回自动" : "以后翻译成\(config.targetLanguage)",
              subtitle: "截图翻译", duration: 2.5)
    }
    @objc func openSettingsAction() { openSettings() }
    @objc func startFocus() { startPomodoro(.focus) }
    @objc func startRest() { startPomodoro(.rest) }

    @objc func stopPomodoro() {
        pomoMode = .none
        pomoPrompt?.dismiss()
        updateStatusTitle(force: true)
        speak("番茄钟停了")
    }

    @objc func setFocusMinutes(_ sender: NSMenuItem) {
        focusMinutes = sender.tag
        UserDefaults.standard.set(focusMinutes, forKey: "focusMinutes")
        if pomoMode == .focus { startPomodoro(.focus) }
    }

    @objc func setRestMinutes(_ sender: NSMenuItem) {
        restMinutes = sender.tag
        UserDefaults.standard.set(restMinutes, forKey: "restMinutes")
    }

    @objc func setStretch(_ sender: NSMenuItem) {
        stretchMinutes = sender.tag
        UserDefaults.standard.set(stretchMinutes, forKey: "stretchMinutes")
        resetStretchTimer()
        speak(stretchMinutes == 0 ? "久坐提醒关掉了" : "每 \(stretchMinutes) 分钟提醒你起来动动")
    }

    @objc func copyClipItem(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? ClipEntry else { return }
        copyClipboard(entry)
        speak("回到剪贴板了", subtitle: entry.title, duration: 3)
    }

    func copyClipboard(_ entry: ClipEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if entry.isImage, let image = entry.loadImage() {
            pb.writeObjects([image])
        } else {
            pb.setString(entry.text, forType: .string)
        }
        clipChangeCount = pb.changeCount
        insertClip(entry)
    }

    func setupHotKey() {
        hotKey = GlobalHotKey(keyCode: ClipboardHotKey.keyCode,
                              modifiers: ClipboardHotKey.modifiers)
        hotKey?.onPress = { [weak self] in self?.showClipboardPanel() }
        if hotKey == nil {
            FileHandle.standardError.write("全局快捷键 \(ClipboardHotKey.label) 注册失败\n".data(using: .utf8)!)
        }

        ocrHotKey = GlobalHotKey(keyCode: ScreenHotKey.ocrCode, modifiers: ScreenHotKey.modifiers)
        ocrHotKey?.onPress = { [weak self] in
            self?.captureAndRecognize(translate: false)
        }
        translateHotKey = GlobalHotKey(keyCode: ScreenHotKey.translateCode, modifiers: ScreenHotKey.modifiers)
        translateHotKey?.onPress = { [weak self] in
            self?.captureAndRecognize(translate: true)
        }
        if ocrHotKey == nil {
        }
        if translateHotKey == nil {
        }
    }

    // MARK: 截图识字 / 翻译

    func captureAndRecognize(translate: Bool) {
        if translate && !config.configured {
            playSound("Basso", volume: 0.35)
            speak("翻译要先连接大模型", subtitle: "这就帮你打开设置 →", duration: 5, maxWidth: 280)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.openSettings()
            }
            return
        }
        bubble.hideNow()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (url, error) = ScreenText.captureRegion()
            guard let url = url else {
                let hint = error.isEmpty ? "" : String(error.prefix(80))
                DispatchQueue.main.async {
                    guard !hint.isEmpty else { return }   // 用户按了 Esc
                    self?.speak("截不到图：\(hint)", subtitle: "看看屏幕录制权限", duration: 6, maxWidth: 300)
                }
                return
            }

            // 模型能看图的话，翻译直接发原图，不做本地识别
            if translate, self?.config.vision == true {
                let data = (try? Data(contentsOf: url)) ?? Data()
                try? FileManager.default.removeItem(at: url)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if data.isEmpty {
                        self.speak("截图读不出来", duration: 3)
                    } else {
                        self.translateImage(data)
                    }
                }
                return
            }

            let text = ScreenText.recognize(url)
            try? FileManager.default.removeItem(at: url)
            DispatchQueue.main.async {
                guard let self = self else { return }
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else {
                    self.speak("这块没认出文字", duration: 2.5)
                    return
                }
                if translate {
                    self.translateText(clean)
                } else {
                    self.putOnPasteboard(clean)
                    self.lastResultText = clean
                    let preview = clean.count > 120 ? String(clean.prefix(120)) + "…" : clean
                    self.speak(preview,
                               subtitle: "已复制 \(clean.count) 字 · 点气泡看全文",
                               duration: 10, maxWidth: 320,
                               onTap: { [weak self] in self?.showResult(clean, title: "识别结果") })
                }
            }
        }
    }

    /// 按设置生成翻译指令
    func translationInstruction() -> String {
        if config.targetLanguage.isEmpty {
            return "把下面的文字翻译成中文；如果原文本来就是中文，就翻译成英文。只输出译文，不要解释，不要加引号。"
        }
        return "把下面的文字翻译成\(config.targetLanguage)。只输出译文，不要解释，不要加引号。"
    }

    func visionInstruction() -> String {
        let target = config.targetLanguage.isEmpty ? "中文（如果原文是中文就翻译成英文）" : config.targetLanguage
        return "把这张图片里的文字翻译成\(target)。"
            + "保留原来的换行和表格结构（表格用 | 分隔单元格）。只输出译文，不要解释。"
    }

    /// 直接把截图发给多模态模型翻译
    /// 长结果用独立窗口展示（可滚动、可选中）
    func showResult(_ text: String, title: String) {
        lastResultText = text
        if resultWindow == nil { resultWindow = ResultWindow() }
        resultWindow?.present(text: text, title: title)
    }

    @objc func showLastResult() {
        guard !lastResultText.isEmpty else {
            speak("还没有识别过东西", duration: 2.5)
            return
        }
        showResult(lastResultText, title: "识别结果")
    }

    func translateImage(_ png: Data) {
        speak("翻译中…", duration: 60, maxWidth: 160)
        llmVision(config: config, prompt: visionInstruction(), imagePNG: png) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let reply):
                let clean = Self.plainish(reply.text.isEmpty ? "……" : reply.text)
                self.putOnPasteboard(clean)
                self.happyEnd = self.t + 1.2
                self.playSound("Pop", volume: 0.3)
                self.lastResultText = clean
                self.speak(clean, subtitle: "译文已复制 · 点气泡看全文", maxWidth: 320, sticky: true,
                           onTap: { [weak self] in self?.showResult(clean, title: "译文") })
            case .failure(let error):
                let hint = self.config.vision ? "（这个模型可能不支持看图）" : ""
                self.speak("翻译失败：\(error.localizedDescription)\(hint)", duration: 6, maxWidth: 300)
            }
        }
    }

    func translateText(_ text: String) {
        var queue = Self.splitForTranslation(text)
        var pieces: [String] = []
        speak("翻译中…", duration: 60, maxWidth: 160)

        func finish() {
            let out = pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !out.isEmpty else {
                speak("没翻出东西", duration: 3)
                return
            }
            putOnPasteboard(out)
            happyEnd = t + 1.2
            lastResultText = out
            speak(out, subtitle: "译文已复制 · 点气泡看全文", maxWidth: 320, sticky: true,
                  onTap: { [weak self] in self?.showResult(out, title: "译文") })
        }

        func step() {
            guard !queue.isEmpty else {
                finish()
                return
            }
            let chunk = queue.removeFirst()
            if !pieces.isEmpty {
                speak("翻译中… 已译 \(pieces.count) 段", duration: 60, maxWidth: 200)
            }
            let prompt = translationInstruction() + "\n\n" + chunk
            llmChat(config: config, messages: [["role": "user", "content": prompt]], maxTokens: 2400) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let reply):
                    if reply.truncated, chunk.count > 160 {
                        // 被 max_tokens 截断了：对半拆开重来
                        queue.insert(contentsOf: Self.splitInHalf(chunk), at: 0)
                        step()
                        return
                    }
                    let clean = Self.plainish(reply.text)
                    if !clean.isEmpty { pieces.append(clean) }
                    step()
                case .failure(let error):
                    if pieces.isEmpty {
                        self.speak("翻译失败：\(error.localizedDescription)", duration: 6, maxWidth: 300)
                    } else {
                        self.putOnPasteboard(pieces.joined(separator: "\n"))
                        self.speak("只翻到一半：\(error.localizedDescription)", duration: 6, maxWidth: 300)
                    }
                }
            }
        }
        step()
    }

    /// 按行切成适合一次请求的小段，尽量不切断句子
    static func splitForTranslation(_ text: String, limit: Int = 900) -> [String] {
        var chunks: [String] = []
        var current = ""
        for line in text.components(separatedBy: "\n") {
            if !current.isEmpty, current.count + line.count + 1 > limit {
                chunks.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : "\n") + line
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(current)
        }
        return chunks.isEmpty ? [text] : chunks
    }

    static func splitInHalf(_ text: String) -> [String] {
        let lines = text.components(separatedBy: "\n")
        if lines.count >= 2 {
            let mid = lines.count / 2
            return [lines[..<mid].joined(separator: "\n"), lines[mid...].joined(separator: "\n")]
        }
        let chars = Array(text)
        let mid = max(1, chars.count / 2)
        return [String(chars[..<mid]), String(chars[mid...])]
    }

    /// 放到剪贴板；不更新 clipChangeCount，让它顺便进剪贴板历史
    func putOnPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// 右键（或 ⌃⌥V）开关剪贴板面板
    func toggleClipboardPanel() {
        if let panel = clipPanel, panel.isVisible {
            panel.hide()
        } else {
            showClipboardPanel()
        }
    }

    func showClipboardPanel() {
        guard !clipItems.isEmpty else {
            speak("剪贴板还没有记录")
            return
        }
        if clipPanel == nil {
            let panel = ClipboardPanel()
            panel.onPick = { [weak self] entry in
                self?.copyClipboard(entry)
                self?.clipPanel?.hide()
                self?.speak("复制好了", subtitle: entry.title, duration: 2.5)
            }
            panel.onCancel = { [weak self] in self?.clipPanel?.hide() }
            panel.onTogglePin = { [weak self] entry in self?.togglePin(entry) }
            clipPanel = panel
        }
        clipPanel?.present(items: Array(clipItems.prefix(20)), above: window)
    }

    @objc func toggleClipboard() {
        clipboardEnabled.toggle()
        UserDefaults.standard.set(clipboardEnabled, forKey: "clipboardEnabled")
        if clipboardEnabled { clipChangeCount = NSPasteboard.general.changeCount }
    }

    @objc func toggleClipExclusion() {
        guard let app = lastOtherApp else { return }
        if clipExcludedApps.removeValue(forKey: app.id) != nil {
            speak("「\(app.name)」里复制的又会记了", maxWidth: 300)
        } else {
            clipExcludedApps[app.id] = app.name
            speak("「\(app.name)」里复制的不记了", subtitle: "以前记下的要手动清", duration: 3, maxWidth: 300)
        }
        UserDefaults.standard.set(clipExcludedApps, forKey: "clipExcludedApps")
    }

    @objc func removeClipExclusion(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let name = clipExcludedApps.removeValue(forKey: id) else { return }
        UserDefaults.standard.set(clipExcludedApps, forKey: "clipExcludedApps")
        speak("「\(name)」里复制的又会记了", maxWidth: 300)
    }

    @objc func clearClipboard() {
        for entry in clipItems where entry.isImage { ClipStore.deleteImage(of: entry) }
        clipItems.removeAll()
        Store.write(clipItems, to: "clipboard.json")
        speak("记录清空了")
    }

    @objc func speakRandom() {
        clickFeedback(countsAsClick: false)
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

/// 纯代码建的 app 默认没有菜单栏，而 ⌘C / ⌘V / ⌘A 这些快捷键是挂在「编辑」菜单项上的，
/// 少了它输入框里按 ⌘V 会毫无反应。这里补一份最小可用菜单。
/// 只用来生成标准编辑动作的 selector，不实际遵循
@objc private protocol EditMenuActions {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
    func cut(_ sender: Any?)
    func copy(_ sender: Any?)
    func paste(_ sender: Any?)
    func selectAll(_ sender: Any?)
}

func makeMainMenu() -> NSMenu {
    let main = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "关于蕉哥", action: nil, keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "退出蕉哥", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu
    main.addItem(appItem)

    let editItem = NSMenuItem()
    let edit = NSMenu(title: "编辑")
    edit.addItem(withTitle: "撤销", action: #selector(EditMenuActions.undo(_:)), keyEquivalent: "z")
    edit.addItem(withTitle: "重做", action: #selector(EditMenuActions.redo(_:)), keyEquivalent: "Z")
    edit.addItem(.separator())
    edit.addItem(withTitle: "剪切", action: #selector(EditMenuActions.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "拷贝", action: #selector(EditMenuActions.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "粘贴", action: #selector(EditMenuActions.paste(_:)), keyEquivalent: "v")
    edit.addItem(withTitle: "全选", action: #selector(EditMenuActions.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = edit
    main.addItem(editItem)

    return main
}

let app = NSApplication.shared
let controller = PetController()
app.delegate = controller
app.mainMenu = makeMainMenu()
app.setActivationPolicy(.accessory)
app.run()
