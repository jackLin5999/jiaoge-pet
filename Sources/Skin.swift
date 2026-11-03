import AppKit
import UniformTypeIdentifiers

// MARK: - 外观：Petdex 宠物
//
// 换成从 petdex.dev 导入的宠物时，画香蕉的代码一行不动，只是换一种画法：
// 按蕉哥当下在做什么，从动画图里挑一行播放，再套上原来的呼吸、弹跳、歪头、压扁。
// 功能（聊天、翻译、番茄钟、剪贴板……）都不受影响。

/// Petdex 动画图的九行，顺序和 Petdex 桌面版一致
enum SkinRow: Int {
    case idle, runRight, runLeft, waving, jumping, failed, waiting, running, review

    /// 每帧停留的秒数，照抄 Petdex 桌面版（petdex-desktop-native/src/sprite.zig）
    func durations(count: Int) -> [Double] {
        if self == .idle && count == 6 { return [0.28, 0.11, 0.11, 0.14, 0.14, 0.32] }
        let spec: (each: Double, last: Double)
        switch self {
        case .idle: spec = (0.15, 0.32)
        case .runRight, .runLeft, .running: spec = (0.12, 0.22)
        case .waving, .jumping: spec = (0.14, 0.28)
        case .failed: spec = (0.14, 0.24)
        case .waiting: spec = (0.15, 0.26)
        case .review: spec = (0.15, 0.28)
        }
        return (0..<count).map { $0 == count - 1 ? spec.last : spec.each }
    }
}

struct SkinCell: Equatable {
    var row: SkinRow
    var index: Int
}

/// 头顶的小特效：原来靠眼睛和嘴表现的情绪，换了外观改用它们
enum SkinOverlay {
    case none, dizzy, surprised, sleepy
}

struct SkinFrame {
    let image: CGImage
    /// 不透明部分，单位是动画图像素，原点在格子左上
    let box: CGRect
    /// 头顶那一截的水平中心，戴皇冠用
    let headX: CGFloat
    /// 格子在整张图里的左上角
    let originX: Int
    let originY: Int
}

final class PetSkin {
    let id: String
    let name: String
    /// pet.json 里的简介，聊天时告诉模型自己长什么样
    let about: String
    let cellSize: CGSize
    private let rows: [[SkinFrame]]
    private let alpha: [UInt8]
    private let sheetWidth: Int

    /// 待机时的身体中线、头顶、脚底（格子内坐标），以及动画图像素 → 参考图坐标的倍数
    let center: CGFloat
    let top: CGFloat
    let foot: CGFloat
    let halfWidth: CGFloat
    let scale: CGFloat

    /// 换算到香蕉的参考图坐标：脚底对齐香蕉的脚底，头顶大约到果柄，左右以脚底中点为准
    static let artFoot: CGFloat = 683
    static let artTop: CGFloat = 100
    static var artCenterX: CGFloat { Banana.anchor.x }
    /// 左右最多伸出去多少，再宽就超出窗口了
    static let artHalfRoom: CGFloat = 206

    init?(id: String, name: String, about: String = "", sheet: CGImage) {
        let w = sheet.width, h = sheet.height
        // 标准是 8 列、每格 192×208；整张图可以等比放大缩小
        guard w >= 64, w % 8 == 0, w <= 4096, h <= 8192 else { return nil }
        let fw = w / 8
        let fh = Int((Double(fw) * 208 / 192).rounded())
        guard h / fh >= 9 else { return nil }

        // 先整张解码成位图：webp 是用到才解码的，直接从原图裁帧会每画一次就把整张图重新解一遍
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let space = sheet.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let decoded: CGImage? = rgba.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.draw(sheet, in: CGRect(x: 0, y: 0, width: w, height: h))
            return ctx.makeImage()
        }
        guard let decoded = decoded else { return nil }
        var alpha = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) { alpha[i] = rgba[i * 4 + 3] }

        // 逐格量出不透明的范围，空格子跳过（每行帧数不一样）
        var rows: [[SkinFrame]] = []
        for r in 0..<9 {
            var frames: [SkinFrame] = []
            for c in 0..<8 {
                let ox = c * fw, oy = r * fh
                var minX = fw, minY = fh, maxX = -1, maxY = -1, count = 0
                for y in 0..<fh {
                    let base = (oy + y) * w + ox
                    for x in 0..<fw where alpha[base + x] > 24 {
                        count += 1
                        if x < minX { minX = x }
                        if x > maxX { maxX = x }
                        if y < minY { minY = y }
                        if y > maxY { maxY = y }
                    }
                }
                guard count > 80,
                      let image = decoded.cropping(to: CGRect(x: ox, y: oy, width: fw, height: fh)) else { continue }
                let headBottom = minY + max(2, (maxY - minY) / 8)
                var sum = 0, n = 0
                for y in minY...headBottom {
                    let base = (oy + y) * w + ox
                    for x in minX...maxX where alpha[base + x] > 24 { sum += x; n += 1 }
                }
                frames.append(SkinFrame(
                    image: image,
                    box: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1),
                    headX: n > 0 ? CGFloat(sum) / CGFloat(n) + 0.5 : CGFloat(minX + maxX + 1) / 2,
                    originX: ox, originY: oy))
            }
            rows.append(frames)
        }
        guard let idle = rows.first, !idle.isEmpty else { return nil }

        let union = idle.dropFirst().reduce(idle[0].box) { $0.union($1.box) }
        let center = union.midX
        var maxHalf: CGFloat = 1
        for frame in rows.joined() {
            maxHalf = max(maxHalf, center - frame.box.minX, frame.box.maxX - center)
        }

        self.id = id
        self.name = name
        self.about = about
        self.cellSize = CGSize(width: fw, height: fh)
        self.rows = rows
        self.alpha = alpha
        self.sheetWidth = w
        self.center = center
        self.top = union.minY
        self.foot = union.maxY
        self.halfWidth = max(1, union.width / 2)
        self.scale = min((Self.artFoot - Self.artTop) / max(1, union.height), Self.artHalfRoom / maxHalf)
    }

    /// 这一行没画就退回待机
    func resolved(_ row: SkinRow) -> SkinRow {
        rows[row.rawValue].isEmpty ? .idle : row
    }

    func durations(_ row: SkinRow) -> [Double] {
        let row = resolved(row)
        return row.durations(count: rows[row.rawValue].count)
    }

    func frame(_ cell: SkinCell) -> SkinFrame? {
        let frames = rows[resolved(cell.row).rawValue]
        guard !frames.isEmpty else { return nil }
        return frames[min(max(cell.index, 0), frames.count - 1)]
    }

    /// 按屏幕上的实际像素先高质量缩放好存起来：每次画都高质量缩放很费电（闲着时 CPU 翻倍）。
    /// 只存用到的帧，换大小或换屏幕就清掉重来
    private var scaled: [Int: CGImage] = [:]
    private var scaledSize = CGSize.zero

    func image(_ frame: SkinFrame, pixelSize: CGSize) -> CGImage {
        let size = CGSize(width: pixelSize.width.rounded(), height: pixelSize.height.rounded())
        if size != scaledSize {
            scaled.removeAll()
            scaledSize = size
        }
        let key = frame.originY * 100_000 + frame.originX
        if let image = scaled[key] { return image }
        guard size.width >= 1, size.height >= 1, size.width <= 4096, size.height <= 4096,
              let space = frame.image.colorSpace,
              let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return frame.image }
        ctx.interpolationQuality = .high
        ctx.draw(frame.image, in: CGRect(origin: .zero, size: size))
        guard let image = ctx.makeImage() else { return frame.image }
        scaled[key] = image
        return image
    }

    /// 整个格子画在参考图坐标里的位置
    var artRect: CGRect {
        CGRect(x: Self.artCenterX - center * scale, y: Self.artFoot - foot * scale,
               width: cellSize.width * scale, height: cellSize.height * scale)
    }

    func toArt(x: CGFloat, y: CGFloat) -> CGPoint {
        let r = artRect
        return CGPoint(x: r.minX + x * scale, y: r.minY + y * scale)
    }

    func fromArt(_ p: CGPoint) -> CGPoint {
        let r = artRect
        return CGPoint(x: (p.x - r.minX) / scale, y: (p.y - r.minY) / scale)
    }

    /// 点在这一帧的不透明部分附近就算点中，和香蕉一样往外放宽一圈
    func hit(artPoint: CGPoint, cell: SkinCell) -> Bool {
        guard let frame = frame(cell) else { return false }
        let q = fromArt(artPoint)
        let m = 24 / scale
        let offsets: [(CGFloat, CGFloat)] = [(0, 0)] + (0..<8).flatMap { i -> [(CGFloat, CGFloat)] in
            let a = CGFloat(i) * .pi / 4
            return [(cos(a) * m, sin(a) * m), (cos(a) * m / 2, sin(a) * m / 2)]
        }
        for (dx, dy) in offsets {
            let x = Int((q.x + dx).rounded(.down)), y = Int((q.y + dy).rounded(.down))
            guard x >= 0, y >= 0, x < Int(cellSize.width), y < Int(cellSize.height) else { continue }
            if alpha[(frame.originY + y) * sheetWidth + frame.originX + x] > 24 { return true }
        }
        return false
    }

    // MARK: 存取

    struct Info: Decodable {
        var id: String?
        var displayName: String?
        var name: String?
        var description: String?
        var spritesheetPath: String?
    }

    enum ImportError: LocalizedError {
        case unzip, noSheet, badLayout

        var errorDescription: String? {
            switch self {
            case .unzip: return "压缩包解不开"
            case .noSheet: return "里面没找到 pet.json 和 spritesheet 图片"
            case .badLayout: return "动画图的格式不对（要 8 列 × 9 行）"
            }
        }
    }

    static var folder: URL { Store.dir.appendingPathComponent("skins", isDirectory: true) }

    static func load(id: String) -> PetSkin? {
        let dir = folder.appendingPathComponent(id, isDirectory: true)
        let info = readInfo(dir)
        guard let url = sheetURL(in: dir, info: info), let image = loadImage(url) else { return nil }
        // 简介是网上下载来的，会写进给模型的提示里：只取一行、限长
        let about = (info.description ?? "").components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return PetSkin(id: id, name: displayName(info, fallback: id), about: String(about.prefix(200)), sheet: image)
    }

    /// 已经导入的宠物：(id, 名字)
    static func installed() -> [(id: String, name: String)] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        return dirs.compactMap { dir -> (id: String, name: String)? in
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
            let info = readInfo(dir)
            guard sheetURL(in: dir, info: info) != nil else { return nil }
            return (dir.lastPathComponent, displayName(info, fallback: dir.lastPathComponent))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 从 Petdex 下载的 zip 或解压后的文件夹导入，复制一份到 Application Support 里
    static func install(from url: URL) throws -> PetSkin {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("jiaoge-skin-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        var root = url
        if url.pathExtension.lowercased() == "zip" {
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", url.path, work.path]
            try unzip.run()
            unzip.waitUntilExit()
            guard unzip.terminationStatus == 0 else { throw ImportError.unzip }
            root = work
        }
        guard let dir = petFolder(in: root) else { throw ImportError.noSheet }
        let info = readInfo(dir)
        guard let sheet = sheetURL(in: dir, info: info), let image = loadImage(sheet) else {
            throw ImportError.noSheet
        }
        guard PetSkin(id: "", name: "", sheet: image) != nil else { throw ImportError.badLayout }

        let id = safeID(info.id ?? (root == url ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent))
        let dest = folder.appendingPathComponent(id, isDirectory: true)
        try? fm.removeItem(at: dest)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        try fm.copyItem(at: sheet, to: dest.appendingPathComponent("spritesheet." + sheet.pathExtension.lowercased()))
        let json = dir.appendingPathComponent("pet.json")
        if isPlainFile(json) {
            try? fm.copyItem(at: json, to: dest.appendingPathComponent("pet.json"))
        }
        guard let skin = load(id: id) else { throw ImportError.badLayout }
        return skin
    }

    static func remove(id: String) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(id, isDirectory: true))
    }

    private static func displayName(_ info: Info, fallback: String) -> String {
        let name = (info.displayName ?? info.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : String(name.prefix(40))
    }

    private static func readInfo(_ dir: URL) -> Info {
        let url = dir.appendingPathComponent("pet.json")
        guard isPlainFile(url), let data = try? Data(contentsOf: url),
              let info = try? JSONDecoder().decode(Info.self, from: data) else { return Info() }
        return info
    }

    /// 只认同一文件夹里的普通文件，pet.json 里写的路径只取文件名
    private static func sheetURL(in dir: URL, info: Info) -> URL? {
        var names = ["spritesheet.webp", "spritesheet.png"]
        if let path = info.spritesheetPath {
            let name = (path as NSString).lastPathComponent
            if !name.isEmpty, name != "..", ["webp", "png"].contains((name as NSString).pathExtension.lowercased()) {
                names.insert(name, at: 0)
            }
        }
        return names.map { dir.appendingPathComponent($0) }.first(where: isPlainFile)
    }

    /// 压缩包里可能还套着一层文件夹
    private static func petFolder(in root: URL) -> URL? {
        if sheetURL(in: root, info: readInfo(root)) != nil { return root }
        let subs = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for sub in subs where sub.lastPathComponent != "__MACOSX" {
            guard (try? sub.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            if sheetURL(in: sub, info: readInfo(sub)) != nil { return sub }
        }
        return nil
    }

    private static func isPlainFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }

    private static func loadImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func safeID(_ raw: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-_")
        let id = String(raw.lowercased().filter { allowed.contains($0) }.prefix(40))
        return id.isEmpty ? "pet-" + UUID().uuidString.prefix(8).lowercased() : id
    }
}

// MARK: - 播放：按蕉哥在做什么挑一格

final class SkinPlayer {
    static let shared = SkinPlayer()
    static let defaultsKey = "petSkin"

    private(set) var skin: PetSkin?
    /// 现在该画哪一格，和上次真正画出来的是哪一格
    var cell = SkinCell(row: .idle, index: 0)
    var drawnCell: SkinCell?
    var overlay: SkinOverlay = .none

    private var lastHappyEnd: TimeInterval = 0
    private var happyStart: TimeInterval = -100
    private var lastBlinkEnd: TimeInterval = 0
    private var idlePassStart: TimeInterval = -100
    private var lastRow: SkinRow?
    private var rowSince: TimeInterval = 0
    private var lastWindowX: CGFloat?
    private var runRight = true

    init() {
        if let id = UserDefaults.standard.string(forKey: Self.defaultsKey), !id.isEmpty {
            skin = PetSkin.load(id: id)
        }
    }

    /// nil = 换回蕉哥原样
    func use(_ newSkin: PetSkin?) {
        skin = newSkin
        UserDefaults.standard.set(newSkin?.id ?? "", forKey: Self.defaultsKey)
        drawnCell = nil
        lastRow = nil
    }

    /// 平时站着不动；原来眨眼的时候把待机那行完整播一遍（很多宠物的待机行里自带眨眼）
    func pick(for c: PetController) {
        guard let skin = skin else { return }
        let t = c.t
        // 只认新设的、还没过期的：看不见的时候设的就不补演了
        if c.happyEnd != lastHappyEnd {
            lastHappyEnd = c.happyEnd
            if c.happyEnd > t { happyStart = t }
        }
        if c.blinkEnd != lastBlinkEnd {
            lastBlinkEnd = c.blinkEnd
            if c.blinkEnd > t { idlePassStart = t }
        }

        let x = c.window.frame.minX
        if c.isDragging, let last = lastWindowX {
            if x > last + 0.5 { runRight = true } else if x < last - 0.5 { runRight = false }
        }
        lastWindowX = x

        func total(_ row: SkinRow) -> Double { skin.durations(row).reduce(0, +) }
        // 只认刚戳出来的连击：别的开心事也会设 happyEnd，不能拿很久以前的连击数来演
        let combo = t - c.lastClickTime < 2.2
        let wave = t - c.waveStart
        let idleKind = c.idleKind
        let idleElapsed = t - c.idleStart
        // 闲时小动作里有对应动画的：跳一下、打哈欠、打瞌睡；其余几种靠整体歪、晃、伸展
        let idleRows: [Int: SkinRow] = [0: .jumping, 3: .review, 6: .failed]
        let idleRow = idleRows[idleKind]

        overlay = .none
        let tickle = TouchTracker.shared.tickleLevel
        if c.isDragging {
            show(runRight ? .runRight : .runLeft, t: t, loop: true)
        } else if tickle > 0 {
            show(tickle >= 3 ? .failed : .jumping, t: t, loop: true)     // 被挠得乱蹦，挠太久笑瘫
        } else if t < c.happyEnd && combo && c.reactionLevel == 2 {
            show(.failed, t: t, loop: true)
            overlay = .dizzy
        } else if t < c.happyEnd && combo && c.reactionLevel == 1 {
            show(.jumping, t: t, loop: true)
            overlay = .surprised
        } else if wave > -0.1 && wave <= max(0.95, total(.waving)) {
            // 挥手比开心晚 0.05 秒开始，这一小段也算挥手，免得先闪一帧跳
            show(.waving, t: t, elapsed: wave, span: 0.95)
        } else if t >= happyStart && t - happyStart < total(.jumping) {
            show(.jumping, t: t, elapsed: t - happyStart)
        } else if c.chatInFlight || c.translation != nil {
            show(.review, t: t, loop: true)            // 在想：等大模型回答、翻译中
        } else if c.pomoPrompt?.isVisible == true {
            show(.waiting, t: t, loop: true)           // 等你决定下一段番茄
        } else if let row = idleRow, idleElapsed >= 0,
                  idleElapsed <= max(c.idleDuration(idleKind), total(row)) {
            show(row, t: t, elapsed: idleElapsed, span: c.idleDuration(idleKind))
            if idleKind == 6 { overlay = .sleepy }
        } else if c.pomoMode == .focus {
            show(.running, t: t, loop: true)           // 陪你一起专注
        } else if t >= idlePassStart && t - idlePassStart < total(.idle) {
            show(.idle, t: t, elapsed: t - idlePassStart)
        } else {
            show(.idle, t: t, elapsed: 0)
        }
    }

    /// loop：从切到这一行起循环播；否则按 elapsed 播一遍停在最后一帧。
    /// span 比这一行本身长时把整行放慢，刚好铺满原来那个动作的时长
    private func show(_ row: SkinRow, t: TimeInterval, elapsed: Double? = nil, span: Double? = nil, loop: Bool = false) {
        guard let skin = skin else { return }
        let row = skin.resolved(row)
        if row != lastRow { lastRow = row; rowSince = t }
        let ds = skin.durations(row)
        let length = ds.reduce(0, +)
        var e = max(0, elapsed ?? (t - rowSince))
        if let span = span, span > length { e *= length / span }
        if loop { e = e.truncatingRemainder(dividingBy: length) }
        var index = ds.count - 1
        var acc = 0.0
        for (i, d) in ds.enumerated() {
            acc += d
            if e < acc { index = i; break }
        }
        cell = SkinCell(row: row, index: index)
    }
}

// MARK: - 皇冠

/// 段位皇冠素材是从戴在香蕉上的图里抠出来的，底下连着 3～4 行香蕉皮的黄色。
/// 戴在香蕉上看不出来，换了外观就成了头顶一道黄边，所以给外观用的皇冠先把这道黄边去掉
enum SkinCrown {
    private static var cache: [String: CGImage] = [:]

    static func image(for key: String) -> CGImage? {
        if let cached = cache[key] { return cached }
        guard let original = CrownAssets.image(for: key) else { return nil }
        let image = withoutPeel(original) ?? original
        cache[key] = image
        return image
    }

    private static func withoutPeel(_ image: CGImage) -> CGImage? {
        let w = image.width, h = image.height
        guard w > 0, h > 8, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)

        // 香蕉皮黄 #F1D980 附近；半透明的边先还原成不透明的颜色再比
        func isPeel(_ x: Int, _ y: Int) -> Bool {
            let i = (y * w + x) * 4
            let a = Double(px[i + 3])
            guard a > 24 else { return false }
            let r = Double(px[i]) * 255 / a, g = Double(px[i + 1]) * 255 / a, b = Double(px[i + 2]) * 255 / a
            return abs(r - 241) < 18 && abs(g - 217) < 18 && abs(b - 128) < 26
        }
        // 从最底下往上数，大半是香蕉黄的行就是那道黄边（缓冲区第 0 行是图的最上面）
        var strip = 0
        for y in stride(from: h - 1, through: 0, by: -1) {
            var opaque = 0, peel = 0
            for x in 0..<w where px[(y * w + x) * 4 + 3] > 128 {
                opaque += 1
                if isPeel(x, y) { peel += 1 }
            }
            guard opaque > 0, peel * 2 > opaque else { break }
            strip += 1
        }
        // 大师以上的皇冠本身就是金黄色，没有单独的黄边，不动
        guard (1...5).contains(strip) else { return nil }

        // 黄边上面紧挨着的一行是皇冠和黄边混出来的颜色，看着是一道细黄线，一起切掉
        let bottom = h - strip - 1
        // 黄边比皇冠宽，两头斜着沿皇冠两侧往上爬了几行。皇冠下半截两侧是竖直的，
        // 所以量出上面一点的左右边，下面伸出这个范围的都是黄边。只看位置不看颜色，金皇冠自己的金色不受影响
        let ref = max(0, bottom - 8)
        let edge = (0..<w).filter { px[(ref * w + $0) * 4 + 3] > 8 }
        if let left = edge.first, let right = edge.last {
            for y in (ref + 1)..<bottom {
                for x in 0..<w where x < left || x > right {
                    for k in 0..<4 { px[(y * w + x) * 4 + k] = 0 }
                }
            }
        }
        return ctx.makeImage()?.cropping(to: CGRect(x: 0, y: 0, width: w, height: bottom))
    }
}

// MARK: - 台词

extension PetController {
    /// 只有香蕉才说得通的几句，换了外观改说这些
    static let bananaOnlyLines = [
        "那是我的把儿": "头顶是禁区",
        "别坐成一根香蕉": "别坐成一块石头",
    ]

    /// 台词里的「蕉哥」换成当前宠物的名字，香蕉专属的换成别的；用蕉哥原样时原样返回
    func petLine(_ line: String) -> String {
        guard let skin = SkinPlayer.shared.skin else { return line }
        if let swap = Self.bananaOnlyLines[line] { return swap }
        return Self.insertName(skin.name, into: line)
    }

    /// 聊天提示的第一句：自己是谁。用蕉哥原样时和原来一字不差
    func chatPersona() -> String {
        guard let skin = SkinPlayer.shared.skin else { return "你是一只叫蕉哥的香蕉桌宠，" }
        let looks = skin.about.isEmpty ? "" : "（外形：\(skin.about)）"
        return Self.insertName(skin.name, into: "你是一只叫蕉哥的桌宠") + looks + "，"
    }

    /// 英文名夹在汉字中间时两边留个空格：「Yukina 在此」
    static func insertName(_ name: String, into text: String) -> String {
        let parts = text.components(separatedBy: "蕉哥")
        guard parts.count > 1 else { return text }
        func isHan(_ c: Character?) -> Bool {
            guard let v = c?.unicodeScalars.first?.value else { return false }
            return (0x3400...0x9FFF).contains(v) || (0xF900...0xFAFF).contains(v)
        }
        func isLatin(_ c: Character?) -> Bool {
            guard let c = c else { return false }
            return c.isASCII && (c.isLetter || c.isNumber)
        }
        var out = parts[0]
        for part in parts.dropFirst() {
            if isLatin(name.first) && isHan(out.last) { out += " " }
            out += name
            if isLatin(name.last) && isHan(part.first) { out += " " }
            out += part
        }
        return out
    }
}

// MARK: - 接到原来的代码上

extension PetController {
    /// 每帧调一次；换了外观且该换下一格了就返回 true
    func skinStep(_ pose: Pose) -> Bool {
        let player = SkinPlayer.shared
        guard player.skin != nil else { return false }
        player.pick(for: self)
        return player.cell != player.drawnCell
    }

    /// 动画图上没法分出眼睛、嘴，只按高低和左右粗分
    func skinBodyPart(at artPoint: CGPoint) -> BodyPart? {
        guard let skin = SkinPlayer.shared.skin else { return nil }
        let q = skin.fromArt(artPoint)
        let r = (q.y - skin.top) / max(1, skin.foot - skin.top)
        let side = abs(q.x - skin.center) / skin.halfWidth
        if r < 0.16 { return .stem }
        if r > 0.9 { return .foot }
        if r > 0.45 && r < 0.8 && side > 0.6 { return .arm }
        return .belly
    }

    func skinMenuItem() -> NSMenuItem {
        let menu = NSMenu()
        menu.autoenablesItems = false
        func item(_ title: String, _ selector: Selector, on: Bool = false, value: String? = nil) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            item.state = on ? .on : .off
            item.representedObject = value
            return item
        }
        let current = SkinPlayer.shared.skin
        menu.addItem(item("蕉哥（原版）", #selector(chooseSkin(_:)), on: current == nil, value: ""))
        for pet in PetSkin.installed() {
            menu.addItem(item(pet.name, #selector(chooseSkin(_:)), on: pet.id == current?.id, value: pet.id))
        }
        menu.addItem(.separator())
        menu.addItem(item("显示段位皇冠", #selector(toggleCrown), on: !crownHidden))
        menu.addItem(.separator())
        menu.addItem(item("导入 Petdex 宠物…", #selector(importSkinAction)))
        menu.addItem(item("去 petdex.dev 挑选", #selector(openPetdex)))
        if let skin = current {
            menu.addItem(.separator())
            menu.addItem(item("删除「\(skin.name)」", #selector(removeCurrentSkin)))
        }
        let top = NSMenuItem(title: "外观", action: nil, keyEquivalent: "")
        top.submenu = menu
        return top
    }

    /// 不喜欢皇冠可以不戴；香蕉和导入的宠物都管用。段位、经验照常算
    var crownHidden: Bool { UserDefaults.standard.bool(forKey: "crownHidden") }

    @objc func toggleCrown() {
        UserDefaults.standard.set(!crownHidden, forKey: "crownHidden")
        view.crownKey = crownHidden ? "" : crownKey
        lastDrawnPose = nil
        view.needsDisplay = true
    }

    func applySkin(_ skin: PetSkin?) {
        SkinPlayer.shared.use(skin)
        lastDrawnPose = nil
        view.needsDisplay = true
    }

    @objc func chooseSkin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        if id.isEmpty {
            applySkin(nil)
            return
        }
        guard let skin = PetSkin.load(id: id) else {
            speak("这个外观读不出来了", subtitle: "可以删掉重新导入")
            return
        }
        applySkin(skin)
        happyEnd = t + 1.2
    }

    @objc func importSkinAction() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "导入 Petdex 宠物"
        panel.message = "选从 petdex.dev 下载的 .zip，或者解压后的文件夹（里面有 pet.json 和 spritesheet）"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip, .folder]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let skin = try PetSkin.install(from: url)
            applySkin(skin)
            happyEnd = t + 1.2
            speak("换好啦", subtitle: "外观：\(skin.name)")
        } catch {
            speak("导入失败", subtitle: error.localizedDescription, duration: 4)
        }
    }

    @objc func openPetdex() {
        if let url = URL(string: "https://petdex.dev/") { NSWorkspace.shared.open(url) }
    }

    @objc func removeCurrentSkin() {
        guard let skin = SkinPlayer.shared.skin else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "删除外观「\(skin.name)」？"
        alert.informativeText = "只删蕉哥里导入的这一份，换回蕉哥原样。下载的原文件不受影响。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        applySkin(nil)
        PetSkin.remove(id: skin.id)
    }
}

extension PetView {
    /// 换了外观就按动画图画并返回 true；用蕉哥原样时返回 false，照原来的画
    func drawSkin(_ ctx: CGContext) -> Bool {
        let player = SkinPlayer.shared
        guard let skin = player.skin, let frame = skin.frame(player.cell) else { return false }
        player.drawnCell = player.cell
        var p = pose
        // 跳那一行自己会往上跳，不再叠加原来的弹跳
        if player.cell.row == .jumping { p.bob = 0 }
        let lift = max(0, skin.foot - frame.box.maxY) * skin.scale * ART_SCALE
        let toView = artToView

        // 影子留在地上，跳起来时变小变淡
        ctx.saveGState()
        ctx.concatenate(toView)
        let k = 1 - min(max(p.bob + lift, 0), 30) / 60
        let s = Banana.shadow
        ctx.setFillColor(NSColor(white: 0, alpha: 0.06 * k).cgColor)
        ctx.fillEllipse(in: s.insetBy(dx: s.width * (1 - k) / 2, dy: s.height * (1 - k) / 2))
        ctx.restoreGState()

        // 原来眼睛跟着鼠标转，现在改成整个身子往鼠标那边稍微侧一点
        let look = max(-1, min(1, p.eyeOffsetX * ART_SCALE / 3.2))
        ctx.saveGState()
        let a = Banana.anchor.applying(toView)
        ctx.translateBy(x: a.x, y: a.y + p.bob)
        ctx.rotate(by: p.tilt - look * 0.045)
        ctx.scaleBy(x: p.scaleX, y: p.scaleY)
        ctx.translateBy(x: -a.x, y: -a.y)
        ctx.concatenate(toView)

        let r = skin.artRect
        let device = ART_SCALE * (window?.backingScaleFactor ?? 2)
        let image = skin.image(frame, pixelSize: CGSize(width: r.width * device, height: r.height * device))
        ctx.interpolationQuality = .low     // 已经缩放好了，这里只剩呼吸、歪头那一点点变形
        ctx.saveGState()
        ctx.translateBy(x: r.minX, y: r.maxY)
        ctx.scaleBy(x: 1, y: -1)          // 素材是正立的，画在 y 向下的坐标系里要翻回来
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: r.width, height: r.height))
        ctx.restoreGState()

        let head = skin.toArt(x: frame.headX, y: frame.box.minY)
        drawSkinCrown(ctx, head: head, skin: skin)
        drawSkinOverlay(ctx, player.overlay, head: head, t: controller?.t ?? 0)
        ctx.restoreGState()
        return true
    }

    func skinHitTest(_ p: NSPoint) -> Bool? {
        let player = SkinPlayer.shared
        guard let skin = player.skin else { return nil }
        return skin.hit(artPoint: p.applying(artToView.inverted()), cell: player.cell)
    }

    /// 皇冠戴在这一帧的头顶，往头发里压一点
    private func drawSkinCrown(_ ctx: CGContext, head: CGPoint, skin: PetSkin) {
        guard let crown = SkinCrown.image(for: crownKey) else { return }
        let width: CGFloat = 176 * CrownAssets.scale(for: crownKey)
        let height = width * CGFloat(crown.height) / CGFloat(crown.width)
        let bottom = head.y + (PetSkin.artFoot - PetSkin.artTop) * 0.07
        ctx.saveGState()
        ctx.translateBy(x: head.x - width / 2, y: bottom)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(crown, in: CGRect(x: 0, y: 0, width: width, height: height))
        ctx.restoreGState()
    }

    /// 头顶的小特效，坐标是参考图坐标（y 向下）
    private func drawSkinOverlay(_ ctx: CGContext, _ overlay: SkinOverlay, head: CGPoint, t: TimeInterval) {
        let outline = NSColor(srgbRed: 0.43, green: 0.34, blue: 0.17, alpha: 1).cgColor
        switch overlay {
        case .none:
            return

        case .dizzy:        // 三颗星星绕着头转
            ctx.setLineWidth(5)
            ctx.setLineJoin(.round)
            for i in 0..<3 {
                let a = CGFloat(t) * 5 + CGFloat(i) * 2 * .pi / 3
                let c = CGPoint(x: head.x + cos(a) * 100, y: head.y - 6 + sin(a) * 24)
                let star = CGMutablePath()
                for j in 0..<10 {
                    let radius: CGFloat = j % 2 == 0 ? 24 : 10
                    let b = CGFloat(j) * .pi / 5 - .pi / 2
                    let pt = CGPoint(x: c.x + cos(b) * radius, y: c.y + sin(b) * radius)
                    if j == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                }
                star.closeSubpath()
                ctx.addPath(star)
                ctx.setFillColor(NSColor(srgbRed: 1, green: 0.83, blue: 0.3, alpha: 1).cgColor)
                ctx.setStrokeColor(outline)
                ctx.drawPath(using: .fillStroke)
            }

        case .surprised:    // 头顶右边冒个感叹号
            let x = head.x + 120, y = head.y + 10
            ctx.setFillColor(heartRed.cgColor)
            ctx.addPath(CGPath(roundedRect: CGRect(x: x - 9, y: y, width: 18, height: 52),
                               cornerWidth: 9, cornerHeight: 9, transform: nil))
            ctx.fillPath()
            ctx.fillEllipse(in: CGRect(x: x - 10, y: y + 60, width: 20, height: 20))

        case .sleepy:       // 一串 z 往右上飘
            ctx.setLineWidth(6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for i in 0..<3 {
                let phase = (CGFloat(t) * 0.7 + CGFloat(i) / 3).truncatingRemainder(dividingBy: 1)
                let size = 18 + phase * 18
                let x = head.x + 80 + phase * 60, y = head.y + 70 - phase * 140
                ctx.setStrokeColor(NSColor(srgbRed: 0.45, green: 0.5, blue: 0.75, alpha: sin(phase * .pi)).cgColor)
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addLine(to: CGPoint(x: x + size, y: y))
                ctx.addLine(to: CGPoint(x: x, y: y + size))
                ctx.addLine(to: CGPoint(x: x + size, y: y + size))
                ctx.strokePath()
            }
        }
    }
}
