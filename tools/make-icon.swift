func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func drawIcon(_ ctx: CGContext) {
    let S: CGFloat = 1024
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)

    // 圆角方形底 + 渐变
    let radius: CGFloat = 232
    let square = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(square)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [rgb(0x6E80F9), rgb(0x5A6CF0)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: S), options: [])
    // 后方浅色圆
    ctx.setFillColor(rgb(0x7989F8))
    ctx.fillEllipse(in: CGRect(x: 150, y: 200, width: 724, height: 724))
    ctx.restoreGState()

    // 香蕉身体
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 246, y: 1024))
    body.addCurve(to: CGPoint(x: 372, y: 470), control1: CGPoint(x: 262, y: 800), control2: CGPoint(x: 296, y: 600))
    body.addCurve(to: CGPoint(x: 512, y: 356), control1: CGPoint(x: 420, y: 396), control2: CGPoint(x: 462, y: 356))
    body.addCurve(to: CGPoint(x: 652, y: 470), control1: CGPoint(x: 562, y: 356), control2: CGPoint(x: 604, y: 396))
    body.addCurve(to: CGPoint(x: 778, y: 1024), control1: CGPoint(x: 728, y: 600), control2: CGPoint(x: 762, y: 800))
    body.closeSubpath()

    ctx.saveGState()
    ctx.addPath(square)
    ctx.clip()
    ctx.addPath(body)
    ctx.setFillColor(rgb(0xF4DC75))
    ctx.fillPath()
    ctx.addPath(body)
    ctx.setStrokeColor(rgb(0xD3B24C))
    ctx.setLineWidth(12)
    ctx.strokePath()

    // 眼睛
    ctx.setFillColor(rgb(0x49392C))
    for (cx, angle) in [(430.0, -0.10), (594.0, 0.10)] {
        ctx.saveGState()
        ctx.translateBy(x: cx, y: 452)
        ctx.rotate(by: CGFloat(angle))
        ctx.addPath(CGPath(roundedRect: CGRect(x: -46, y: -15, width: 92, height: 30),
                           cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
    }
    // 嘴
    ctx.addPath(CGPath(roundedRect: CGRect(x: 452, y: 512, width: 120, height: 22),
                       cornerWidth: 11, cornerHeight: 11, transform: nil))
    ctx.fillPath()

    // 皇冠
    let gold = rgb(0xDDBA4A), goldDark = rgb(0xBD9A3F)
    let purple = rgb(0x9777D8), purpleDark = rgb(0x7C5CB8)

    // 冠身（三峰）
    let crown = CGMutablePath()
    crown.move(to: CGPoint(x: 352, y: 304))
    crown.addLine(to: CGPoint(x: 392, y: 176))
    crown.addLine(to: CGPoint(x: 442, y: 250))
    crown.addLine(to: CGPoint(x: 512, y: 132))
    crown.addLine(to: CGPoint(x: 582, y: 250))
    crown.addLine(to: CGPoint(x: 632, y: 176))
    crown.addLine(to: CGPoint(x: 672, y: 304))
    crown.closeSubpath()
    ctx.addPath(crown)
    ctx.setFillColor(purple)
    ctx.fillPath()
    ctx.addPath(crown)
    ctx.setStrokeColor(purpleDark)
    ctx.setLineWidth(14)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // 冠顶金球
    for (x, y) in [(392.0, 170.0), (512.0, 126.0), (632.0, 170.0)] {
        ctx.setFillColor(gold)
        ctx.fillEllipse(in: CGRect(x: x - 34, y: y - 34, width: 68, height: 68))
        ctx.setStrokeColor(goldDark)
        ctx.setLineWidth(8)
        ctx.strokeEllipse(in: CGRect(x: x - 34, y: y - 34, width: 68, height: 68))
    }
    // 红宝石
    ctx.setFillColor(rgb(0xAE4540))
    ctx.fillEllipse(in: CGRect(x: 476, y: 224, width: 72, height: 72))

    // 冠带
    let band = CGRect(x: 352, y: 296, width: 320, height: 68)
    ctx.setFillColor(gold)
    ctx.fill(band)
    ctx.setStrokeColor(goldDark)
    ctx.setLineWidth(10)
    ctx.stroke(band)
    ctx.restoreGState()
}
func render(_ size: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(ctx)
    return ctx.makeImage()!
}
import AppKit
// 复用 render.swift 里的绘制，生成完整 iconset
let dir = CommandLine.arguments[1]
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (name, size) in sizes {
    let img = render(size)
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(dir)/\(name)"))
}
print("iconset 生成完成：\(sizes.count) 个尺寸")
