import AppKit
import CryptoKit
import Vision

// MARK: - 配置

struct ChatConfig: Codable {
    var baseURL = "https://api.deepseek.com/v1"
    var model = "deepseek-flash"
    var apiKey = ""
    /// 模型能不能看图：能的话截图翻译直接发图，不走 OCR
    var vision = false
    /// 翻译目标语言；空字符串表示「自动」＝原文是中文就翻英文，否则翻中文
    var targetLanguage = ""

    init(baseURL: String = "https://api.deepseek.com/v1", model: String = "deepseek-flash",
         apiKey: String = "", vision: Bool = false, targetLanguage: String = "") {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.vision = vision
        self.targetLanguage = targetLanguage
    }

    /// 旧配置文件里没有 vision 字段，缺了就按 false 处理
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.deepseek.com/v1"
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? "deepseek-flash"
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        vision = try c.decodeIfPresent(Bool.self, forKey: .vision) ?? false
        targetLanguage = try c.decodeIfPresent(String.self, forKey: .targetLanguage) ?? ""
    }

    var configured: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            && !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// 小的 JSON 文件存储，都放在 ~/Library/Application Support/JiaoGe
enum Store {
    static var dir: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/JiaoGe", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o700])
        }
        return dir
    }

    static func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func write<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let url = dir.appendingPathComponent(name)
        try? data.write(to: url, options: [.atomic])
        // 里面有 API Key，只给自己读
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

// MARK: - 大模型请求（OpenAI 兼容格式）

enum LLMError: LocalizedError {
    case notConfigured
    case http(Int, String)
    case badResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "还没设置 API"
        case .http(let code, let msg): return "接口返回 \(code)\(msg.isEmpty ? "" : "：\(msg)")"
        case .badResponse: return "看不懂接口返回的内容"
        case .transport(let s): return s
        }
    }
}

struct LLMReply {
    var text: String
    var truncated: Bool      // finish_reason == length，说明被 max_tokens 截断了
}

/// 按 OpenAI 的 /chat/completions 格式发一条请求，DeepSeek、通义、Kimi、智谱、硅基流动、Ollama 都吃这套
func llmChat(config: ChatConfig, messages: [[String: String]], maxTokens: Int = 600,
             completion: @escaping (Result<LLMReply, Error>) -> Void) {
    var base = config.baseURL.trimmingCharacters(in: .whitespaces)
    while base.hasSuffix("/") { base.removeLast() }
    guard config.configured, let url = URL(string: base + "/chat/completions") else {
        completion(.failure(LLMError.notConfigured))
        return
    }

    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.timeoutInterval = 40
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(config.apiKey.trimmingCharacters(in: .whitespaces))",
                 forHTTPHeaderField: "Authorization")
    req.httpBody = try? JSONSerialization.data(withJSONObject: [
        "model": config.model,
        "messages": messages,
        "temperature": 0.8,
        "max_tokens": maxTokens,
    ])

    URLSession.shared.dataTask(with: req) { data, response, error in
        let result = parseLLMResponse(data: data,
                                      status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                                      error: error)
        DispatchQueue.main.async { completion(result) }
    }.resume()
}

/// 直接发图片给多模态模型（OpenAI 兼容的 image_url 格式）
func llmVision(config: ChatConfig, prompt: String, imagePNG: Data, maxTokens: Int = 2000,
               completion: @escaping (Result<LLMReply, Error>) -> Void) {
    var base = config.baseURL.trimmingCharacters(in: .whitespaces)
    while base.hasSuffix("/") { base.removeLast() }
    guard config.configured, let url = URL(string: base + "/chat/completions") else {
        completion(.failure(LLMError.notConfigured))
        return
    }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.timeoutInterval = 60
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(config.apiKey.trimmingCharacters(in: .whitespaces))",
                 forHTTPHeaderField: "Authorization")
    let dataURL = "data:image/png;base64," + imagePNG.base64EncodedString()
    let body: [String: Any] = [
        "model": config.model,
        "max_tokens": maxTokens,
        "messages": [[
            "role": "user",
            "content": [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": dataURL]],
            ],
        ]],
    ]
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: req) { data, response, error in
        let result = parseLLMResponse(data: data,
                                      status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                                      error: error)
        DispatchQueue.main.async { completion(result) }
    }.resume()
}

private func parseLLMResponse(data: Data?, status: Int, error: Error?) -> Result<LLMReply, Error> {
    if let error = error { return .failure(LLMError.transport(error.localizedDescription)) }
    let data = data ?? Data()
    let raw = String(data: data, encoding: .utf8) ?? ""

    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return .failure(status == 200 ? LLMError.badResponse : LLMError.http(status, String(raw.prefix(120))))
    }
    if let err = obj["error"] as? [String: Any], let msg = err["message"] as? String {
        return .failure(LLMError.http(status, msg))
    }
    guard let choices = obj["choices"] as? [[String: Any]],
          let message = choices.first?["message"] as? [String: Any] else {
        return .failure(LLMError.http(status, String(raw.prefix(120))))
    }
    let truncated = (choices.first?["finish_reason"] as? String) == "length"
    if let s = message["content"] as? String {
        return .success(LLMReply(text: s.trimmingCharacters(in: .whitespacesAndNewlines), truncated: truncated))
    }
    // 少数服务把 content 返回成 [{type:"text", text:"…"}]
    if let parts = message["content"] as? [[String: Any]] {
        let s = parts.compactMap { $0["text"] as? String }.joined()
        return .success(LLMReply(text: s.trimmingCharacters(in: .whitespacesAndNewlines), truncated: truncated))
    }
    return .failure(LLMError.badResponse)
}

// MARK: - 聊天输入框

final class ChatInputView: NSView {
    let field = NSTextField()

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2)
        NSColor.white.setFill()
        path.fill()
        rgb(0xE3D3A1).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}

final class ChatInputWindow: NSPanel {
    var onSubmit: ((String) -> Void)?
    private let content = ChatInputView()
    private var focusTimer: Timer?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 360, height: 46),
                   styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        contentView = content

        let field = content.field
        field.frame = NSRect(x: 16, y: 12, width: 328, height: 22)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 14)
        // 气泡底永远是白的，文字和光标也固定按浅色画，否则深色外观下会变成白字白底
        field.textColor = ink
        field.appearance = NSAppearance(named: .aqua)
        field.placeholderString = "跟蕉哥说点什么…"
        field.target = self
        field.action = #selector(submit)
        content.addSubview(field)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 贴在宠物头顶；上面放不下就挪到脚下
    func follow(_ pet: NSWindow) {
        var x = pet.frame.midX - frame.width / 2
        var y = pet.frame.minY + PET_TOP + 2
        if let screen = pet.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            x = max(vf.minX + 6, min(x, vf.maxX - frame.width - 6))
            if y + frame.height > vf.maxY - 6 {
                y = pet.frame.minY - frame.height - 6
            }
            y = max(vf.minY + 6, min(y, vf.maxY - frame.height - 6))
        }
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func present(above pet: NSWindow) {
        follow(pet)
        content.field.stringValue = ""
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(content.field)
        startFocusLoop()
    }

    /// 激活是异步的，而且可能被别的 app 抢走；显示期间持续把焦点抢回来
    private func startFocusLoop() {
        focusTimer?.invalidate()
        var ticks = 0
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] timer in
            guard let self = self, self.isVisible else {
                timer.invalidate()
                return
            }
            ticks += 1
            if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
            if !self.isKeyWindow {
                self.makeKey()
                self.makeFirstResponder(self.content.field)
            }
            if ticks > 24 { timer.invalidate() }   // 撑 3 秒还抢不到就放弃
        }
        RunLoop.main.add(timer, forMode: .common)
        focusTimer = timer
    }

    func hide() {
        guard isVisible else { return }
        focusTimer?.invalidate()
        focusTimer = nil
        orderOut(nil)
        NSApp.deactivate()
    }

    /// 点到对话框以外的地方就收起
    override func resignKey() {
        super.resignKey()
        if isVisible { hide() }
    }

    @objc private func submit() {
        let text = content.field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        hide()
        if !text.isEmpty { onSubmit?(text) }
    }

    override func cancelOperation(_ sender: Any?) {
        hide()
    }
}

// MARK: - 设置窗口

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class SettingsWindow: NSPanel {
    /// 常用服务：名称、接口地址、模型
    /// 第一项是「自动」，其余是固定的目标语言
    static let targetLanguages = ["自动（中文↔英文）", "中文", "英文", "日文", "韩文",
                                  "法文", "德文", "西班牙文", "俄文"]

    static let presets: [(String, String, String)] = [
        ("DeepSeek", "https://api.deepseek.com/v1", "deepseek-flash"),
        ("通义千问", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus"),
        ("Kimi（月之暗面）", "https://api.moonshot.cn/v1", "moonshot-v1-8k"),
        ("智谱 GLM", "https://open.bigmodel.cn/api/paas/v4", "glm-4-flash"),
        ("硅基流动", "https://api.siliconflow.cn/v1", "deepseek-ai/DeepSeek-V3"),
        ("OpenAI", "https://api.openai.com/v1", "gpt-4o-mini"),
        ("Ollama 本地", "http://localhost:11434/v1", "qwen2.5"),
        ("自定义", "", ""),
    ]

    var onSave: ((ChatConfig) -> Void)?

    private let presetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let baseField = NSTextField()
    private let modelField = NSTextField()
    private let keyField = NSSecureTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    /// 目标语言在菜单里设，这里只负责保存时不要覆盖掉
    private var keepTargetLanguage = ""
    private let visionBox = NSButton(checkboxWithTitle: "这个模型能看图（截图翻译直接发图，不走本地识别）",
                                     target: nil, action: nil)

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 322),
                   styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "蕉哥的脑子"
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = FlippedView(frame: NSRect(x: 0, y: 0, width: 460, height: 322))
        contentView = root

        func label(_ text: String, _ y: CGFloat) {
            let l = NSTextField(labelWithString: text)
            l.frame = NSRect(x: 16, y: y + 3, width: 76, height: 18)
            l.font = NSFont.systemFont(ofSize: 13)
            l.textColor = .secondaryLabelColor
            root.addSubview(l)
        }

        label("服务", 18)
        presetPopup.frame = NSRect(x: 96, y: 15, width: 348, height: 26)
        presetPopup.addItems(withTitles: Self.presets.map { $0.0 })
        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
        root.addSubview(presetPopup)

        label("API 地址", 54)
        style(baseField, placeholder: "https://api.deepseek.com/v1")
        baseField.frame = NSRect(x: 96, y: 51, width: 348, height: 24)
        root.addSubview(baseField)

        label("模型", 90)
        style(modelField, placeholder: "deepseek-chat")
        modelField.frame = NSRect(x: 96, y: 87, width: 348, height: 24)
        root.addSubview(modelField)

        label("API Key", 126)
        style(keyField, placeholder: "sk-…")
        keyField.frame = NSRect(x: 96, y: 123, width: 348, height: 24)
        root.addSubview(keyField)

        let hint = NSTextField(labelWithString:
            "密钥存在 ~/Library/Application Support/JiaoGe/config.json\n"
            + "文件权限 600，只有本机这个账号能读。\n"
            + "接口按 OpenAI 的 /chat/completions 格式调用，其他服务选「自定义」。")
        hint.frame = NSRect(x: 16, y: 158, width: 428, height: 54)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.maximumNumberOfLines = 0
        hint.lineBreakMode = .byClipping
        root.addSubview(hint)

        visionBox.frame = NSRect(x: 16, y: 214, width: 428, height: 22)
        visionBox.font = NSFont.systemFont(ofSize: 12)
        root.addSubview(visionBox)

        statusLabel.frame = NSRect(x: 16, y: 240, width: 428, height: 32)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        root.addSubview(statusLabel)

        let test = NSButton(title: "测试连接", target: self, action: #selector(testConnection))
        test.frame = NSRect(x: 16, y: 280, width: 100, height: 30)
        test.bezelStyle = .rounded
        root.addSubview(test)

        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancel.frame = NSRect(x: 254, y: 280, width: 88, height: 30)
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        root.addSubview(cancel)

        let save = NSButton(title: "保存", target: self, action: #selector(save))
        save.frame = NSRect(x: 350, y: 280, width: 94, height: 30)
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        root.addSubview(save)
    }

    private func style(_ field: NSTextField, placeholder: String) {
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.font = NSFont.systemFont(ofSize: 13)
        field.placeholderString = placeholder
    }

    func present(config: ChatConfig) {
        visionBox.state = config.vision ? .on : .off
        keepTargetLanguage = config.targetLanguage
        baseField.stringValue = config.baseURL
        modelField.stringValue = config.model
        keyField.stringValue = config.apiKey
        statusLabel.stringValue = ""
        selectMatchingPreset()
        center()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(baseField)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isVisible else { return }
            self.makeKey()
            self.makeFirstResponder(self.baseField)
        }
    }

    private func selectMatchingPreset() {
        if let i = Self.presets.firstIndex(where: {
            $0.1 == baseField.stringValue && $0.2 == modelField.stringValue
        }) {
            presetPopup.selectItem(at: i)
        } else {
            presetPopup.selectItem(at: Self.presets.count - 1)
        }
    }

    private func currentConfig() -> ChatConfig {
        ChatConfig(baseURL: baseField.stringValue.trimmingCharacters(in: .whitespaces),
                   model: modelField.stringValue.trimmingCharacters(in: .whitespaces),
                   apiKey: keyField.stringValue.trimmingCharacters(in: .whitespaces),
                   vision: visionBox.state == .on,
                   targetLanguage: keepTargetLanguage)
    }

    @objc private func presetChanged() {
        let i = presetPopup.indexOfSelectedItem
        guard i >= 0, i < Self.presets.count - 1 else { return }
        let preset = Self.presets[i]
        baseField.stringValue = preset.1
        modelField.stringValue = preset.2
        statusLabel.stringValue = ""
    }

    @objc private func testConnection() {
        let config = currentConfig()
        guard config.configured else {
            statusLabel.stringValue = "地址、模型和 API Key 都要填"
            return
        }
        statusLabel.stringValue = "正在连接…"
        llmChat(config: config, messages: [["role": "user", "content": "只回复四个字：连接成功"]]) { [weak self] result in
            switch result {
            case .success(let reply):
                self?.statusLabel.stringValue = "连接成功：" + String(reply.text.prefix(60))
            case .failure(let error):
                self?.statusLabel.stringValue = "失败：" + error.localizedDescription
            }
        }
    }

    @objc private func save() {
        let config = currentConfig()
        Store.write(config, to: "config.json")
        onSave?(config)
        close()
        NSApp.deactivate()
    }

    @objc private func cancel() {
        close()
        NSApp.deactivate()
    }
}

// MARK: - 剪贴板条目

struct ClipEntry: Codable, Equatable {
    var kind: String = "text"      // "text" / "image"
    var text: String = ""
    var file: String = ""          // 图片在 clip/ 下的文件名
    var width: Int = 0
    var height: Int = 0
    var time: Double = 0
    var pinned: Bool = false

    init(kind: String = "text", text: String = "", file: String = "", width: Int = 0,
         height: Int = 0, time: Double = 0, pinned: Bool = false) {
        self.kind = kind
        self.text = text
        self.file = file
        self.width = width
        self.height = height
        self.time = time
        self.pinned = pinned
    }

    /// 手写解码：旧版本存的数据里没有 pinned 字段，缺了就按 false 处理
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "text"
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        file = try c.decodeIfPresent(String.self, forKey: .file) ?? ""
        width = try c.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? 0
        time = try c.decodeIfPresent(Double.self, forKey: .time) ?? 0
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }

    var isImage: Bool { kind == "image" }

    func matches(_ query: String) -> Bool {
        if isImage { return title.lowercased().contains(query) || "图片".contains(query) }
        return text.lowercased().contains(query)
    }

    /// 菜单和面板里显示的一行
    var title: String {
        if isImage { return "图片 \(width)×\(height)" }
        return ClipEntry.oneLine(text)
    }

    static func oneLine(_ s: String, limit: Int = 34) -> String {
        let one = s.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ").joined(separator: " ")
        if one.isEmpty { return "（空白内容）" }
        return one.count > limit ? String(one.prefix(limit)) + "…" : one
    }

    var imageURL: URL? {
        isImage ? ClipStore.folder.appendingPathComponent(file) : nil
    }

    func loadImage() -> NSImage? {
        guard let url = imageURL else { return nil }
        return NSImage(contentsOf: url)
    }
}

enum ClipStore {
    static var folder: URL {
        let dir = Store.dir.appendingPathComponent("clip", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o700])
        }
        return dir
    }

    /// 存成一页 PNG，用内容哈希命名，重复的图自动合并
    static func saveImage(_ data: Data) -> ClipEntry? {
        guard data.count < 40_000_000, let rep = NSBitmapImageRep(data: data) else { return nil }
        let name = sha256(data) + ".png"
        let url = folder.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        return ClipEntry(kind: "image", file: name,
                         width: rep.pixelsWide, height: rep.pixelsHigh,
                         time: Date().timeIntervalSince1970)
    }

    static func deleteImage(of entry: ClipEntry) {
        guard let url = entry.imageURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - 段位皇冠

enum CrownAssets {
    private static var cache: [String: CGImage] = [:]

    static func image(for key: String) -> CGImage? {
        if let cached = cache[key] { return cached }
        guard !key.isEmpty else { return nil }
        // 正常从 app 包里取；开发/测试时从工作目录的 Resources 取
        var url = Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "crowns")
        if url == nil {
            let local = URL(fileURLWithPath: "Resources/crowns/\(key).png")
            if FileManager.default.fileExists(atPath: local.path) { url = local }
        }
        guard let url = url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache[key] = image
        return image
    }
}

// MARK: - 截图识字

enum ScreenText {
    /// 调系统自带的框选截图（⌃⌥ 跟系统的一样，按 Esc 取消），返回临时文件路径和错误信息
    static func captureRegion() -> (url: URL?, error: String) {
        let path = NSTemporaryDirectory() + "jiaoge-shot-\(UUID().uuidString).png"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-x", path]
        let pipe = Pipe()
        task.standardError = pipe
        do {
            try task.run()
        } catch {
            return (nil, error.localizedDescription)
        }
        task.waitUntilExit()
        let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            let hint = err.trimmingCharacters(in: .whitespacesAndNewlines)
            return (nil, hint.isEmpty ? "" : hint)
        }
        return (url, "")
    }

    /// 每种文字需要单独一轮：语言列表一长，识别就会被带偏
    /// （比如列表里有中文，韩文就会被认成汉字；西里尔字母也一样）
    private static let passes: [[String]] = [
        ["zh-Hans", "zh-Hant", "ja-JP", "en-US"],   // 中日英
        ["ko-KR", "en-US"],                          // 韩
        ["ar-SA", "en-US"],                          // 阿拉伯
        ["th-TH", "en-US"],                          // 泰
        ["hi-IN", "en-US"],                          // 印地
    ]

    /// Vision 本地识别；识别后按坐标把排版拼回去。
    /// 第一轮（中日英）达标就直接用；否则把余下几轮和「自动」都跑一遍，取分数最高的
    static func recognize(_ url: URL) -> String {
        var best: (score: Double, items: [OCRItem]) = (0, [])
        for (index, languages) in (passes.map { Optional($0) } + [nil]).enumerated() {
            let result = run(url, languages: languages)
            let confidence = result.confidence
            let score = Double(result.chars) * confidence
            if index == 0, result.chars >= 8, confidence >= 0.7 {
                return layout(result.items)     // 常见情况只跑一轮，快
            }
            if score > best.score { best = (score, result.items) }
        }
        return layout(best.items)
    }

    private static func run(_ url: URL, languages: [String]?)
        -> (items: [OCRItem], chars: Int, confidence: Double) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if let languages = languages {
            if let supported = try? request.supportedRecognitionLanguages() {
                let usable = languages.filter { supported.contains($0) }
                if !usable.isEmpty { request.recognitionLanguages = usable }
            } else {
                request.recognitionLanguages = languages
            }
        }
        do {
            try VNImageRequestHandler(url: url, options: [:]).perform([request])
        } catch {
            return ([], 0, 0)
        }
        var items: [OCRItem] = []
        var chars = 0
        var confidenceSum = 0.0
        var count = 0.0
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            items.append(OCRItem(text: candidate.string, box: observation.boundingBox))
            chars += candidate.string.count
            confidenceSum += Double(candidate.confidence)
            count += 1
        }
        return (items, chars, count > 0 ? confidenceSum / count : 0)
    }

    struct OCRItem {
        var text: String
        var box: CGRect      // Vision 坐标：归一化，原点在左下角
    }

    /// 有分栏就按栏读，没分栏就按行读；同一行里的多块文字用 | 分开（表格）
    static func layout(_ items: [OCRItem]) -> String {
        guard !items.isEmpty else { return "" }
        return splitColumns(items)
            .map { render($0) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// 找一条贯穿上下的空白竖缝；两栏的正文都比较宽，表格的格子通常窄，用这个区分
    static func splitColumns(_ items: [OCRItem], depth: Int = 0) -> [[OCRItem]] {
        guard depth < 2, items.count >= 6 else { return [items] }
        let pageWidth = items.map { $0.box.maxX }.max() ?? 1
        var bestX: CGFloat?
        var bestBalance: CGFloat = 0

        var x: CGFloat = 0.25
        while x <= 0.75 {
            let crossing = items.contains { $0.box.minX < x - 0.004 && $0.box.maxX > x + 0.004 }
            if !crossing {
                let left = items.filter { $0.box.maxX <= x }
                let right = items.filter { $0.box.minX >= x }
                if left.count >= 3, right.count >= 3 {
                    let leftWide = left.map { $0.box.width }.reduce(0, +) / CGFloat(left.count) > pageWidth * 0.25
                    let rightWide = right.map { $0.box.width }.reduce(0, +) / CGFloat(right.count) > pageWidth * 0.25
                    let balance = min(CGFloat(left.count), CGFloat(right.count)) / CGFloat(items.count)
                    if leftWide, rightWide, balance > bestBalance, balance > 0.3 {
                        bestBalance = balance
                        bestX = x
                    }
                }
            }
            x += 0.01
        }
        guard let gutter = bestX else { return [items] }
        let left = items.filter { $0.box.maxX <= gutter }
        let right = items.filter { $0.box.minX >= gutter }
        return splitColumns(left, depth: depth + 1) + splitColumns(right, depth: depth + 1)
    }

    /// 按 y 坐标归并成行，行内按 x 排序
    static func render(_ items: [OCRItem]) -> String {
        guard !items.isEmpty else { return "" }
        let heights = items.map { $0.box.height }.sorted()
        let medianH = max(heights[heights.count / 2], 0.005)
        let sorted = items.sorted { $0.box.midY > $1.box.midY }

        var rows: [[OCRItem]] = []
        var current: [OCRItem] = []
        var currentY = sorted[0].box.midY
        for item in sorted {
            if abs(item.box.midY - currentY) <= medianH * 0.6 {
                current.append(item)
                currentY = current.reduce(0) { $0 + $1.box.midY } / CGFloat(current.count)
            } else {
                rows.append(current)
                current = [item]
                currentY = item.box.midY
            }
        }
        if !current.isEmpty { rows.append(current) }

        var lines: [String] = []
        var previousBottom: CGFloat?
        for row in rows {
            let cells = row.sorted { $0.box.minX < $1.box.minX }
            var line = ""
            var previousRight: CGFloat?
            for cell in cells {
                let text = cell.text.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { continue }
                if let right = previousRight {
                    let gap = cell.box.minX - right
                    if gap > medianH * 1.2 {
                        line += "  |  "      // 中间空出来一大块，多半是表格的单元格
                    } else if gap > medianH * 0.35 {
                        line += " "
                    }
                }
                line += text
                previousRight = cell.box.maxX
            }
            let rowTop = row.map { $0.box.maxY }.max() ?? 0
            let rowBottom = row.map { $0.box.minY }.min() ?? 0
            if let bottom = previousBottom, bottom - rowTop > medianH * 1.2 {
                lines.append("")        // 段间距
            }
            lines.append(line)
            previousBottom = rowBottom
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 全局快捷键

import Carbon

/// Carbon 的 RegisterEventHotKey：不需要辅助功能权限，app 不在前台也能收到。
/// 注意：Carbon 的事件 handler 是按「事件类型」挂的，同一个 app 只该挂一个，
/// 否则每挂一个都会收到所有热键事件。所以这里统一挂一个，再按热键 ID 分发。
final class GlobalHotKey {
    private static var callbacks: [UInt32: () -> Void] = [:]
    private static var handlerRef: EventHandlerRef?
    private static var nextID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private let id: UInt32

    var onPress: (() -> Void)? {
        didSet {
            if let onPress = onPress {
                GlobalHotKey.callbacks[id] = onPress
            } else {
                GlobalHotKey.callbacks[id] = nil
            }
        }
    }

    init?(keyCode: Int, modifiers: Int) {
        guard GlobalHotKey.installSharedHandler() else { return nil }

        let id = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
        self.id = id

        let hotKeyID = EventHotKeyID(signature: OSType(0x4A414F47), id: id)   // 'JAOG'
        let result = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        guard result == noErr else { return nil }
    }

    private static func installSharedHandler() -> Bool {
        if handlerRef != nil { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let ok = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID), nil,
                                       MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if ok == noErr {
                GlobalHotKey.callbacks[hotKeyID.id]?()
            }
            return noErr
        }, 1, &eventType, nil, &handlerRef)
        return status == noErr
    }

    deinit {
        if let hotKeyRef = hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        GlobalHotKey.callbacks[id] = nil
    }
}

/// 呼出剪贴板面板的全局快捷键：⌃⌥V/// 呼出剪贴板面板的全局快捷键：⌃⌥V
/// （没用 ⌥⌘V 是因为它在不少编辑器里是「粘贴并匹配样式」）
/// 截图识字的快捷键
enum ScreenHotKey {
    static let ocrCode = kVK_ANSI_O
    static let translateCode = kVK_ANSI_T
    static let modifiers = controlKey | optionKey
    static let ocrLabel = "⌃⌥O"
    static let translateLabel = "⌃⌥T"
}

enum ClipboardHotKey {
    static let keyCode = kVK_ANSI_V
    static let modifiers = controlKey | optionKey
    static let label = "⌃⌥V"
}

// MARK: - 剪贴板面板

final class ClipSearchField: NSSearchField {
    /// 搜索框为空时，数字键直接选条目；有内容时数字键正常输入
    var onDigit: ((Int) -> Void)?

    override func keyDown(with event: NSEvent) {
        if stringValue.isEmpty,
           let text = event.charactersIgnoringModifiers, let n = Int(text) {
            onDigit?(n == 0 ? 9 : n - 1)
            return
        }
        super.keyDown(with: event)
    }
}

final class ClipboardPanelView: NSView, NSSearchFieldDelegate {
    var allItems: [ClipEntry] = []
    private(set) var filtered: [ClipEntry] = []
    private var thumbs: [String: NSImage] = [:]
    var selected = 0 { didSet { needsDisplay = true } }

    var onPick: ((ClipEntry) -> Void)?
    var onCancel: (() -> Void)?
    var onTogglePin: ((ClipEntry) -> Void)?

    let search = ClipSearchField()

    static let rowHeight: CGFloat = 34
    static let width: CGFloat = 380
    static let searchHeight: CGFloat = 40

    override var acceptsFirstResponder: Bool { true }
    var focusTarget: NSResponder { search }

    init() {
        super.init(frame: .zero)
        search.font = NSFont.systemFont(ofSize: 12)
        search.focusRingType = .none
        search.isBordered = false
        search.drawsBackground = false
        search.placeholderString = "搜索…"
        search.delegate = self
        search.onDigit = { [weak self] index in self?.pick(index) }
        addSubview(search)
    }

    required init?(coder: NSCoder) { fatalError("不支持") }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutSearch()
    }

    private func layoutSearch() {
        search.frame = NSRect(x: 20, y: bounds.maxY - Self.searchHeight + 10,
                              width: bounds.width - 40, height: 18)
    }

    func setItems(_ items: [ClipEntry], keepingQuery: Bool = false) {
        allItems = items
        if !keepingQuery { search.stringValue = "" }
        applyFilter()
    }

    private func applyFilter() {
        let query = search.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        let matches = query.isEmpty ? allItems : allItems.filter { $0.matches(query) }
        filtered = Array(matches.prefix(10))
        selected = min(selected, max(0, filtered.count - 1))
        needsDisplay = true
    }

    private func rowRect(_ index: Int) -> NSRect {
        let top = bounds.maxY - Self.searchHeight - 4 - CGFloat(index) * Self.rowHeight
        return NSRect(x: 8, y: top - Self.rowHeight + 4, width: bounds.width - 16,
                      height: Self.rowHeight - 4)
    }

    private func pinRect(_ row: NSRect) -> NSRect {
        NSRect(x: row.maxX - 30, y: row.minY, width: 30, height: row.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let body = bounds.insetBy(dx: 1, dy: 1)
        let shape = NSBezierPath(roundedRect: body, xRadius: 12, yRadius: 12)
        NSColor.white.setFill()
        shape.fill()
        rgb(0xE3D3A1).setStroke()
        shape.lineWidth = 1.5
        shape.stroke()

        // 搜索框的底
        let searchRect = NSRect(x: 10, y: bounds.maxY - Self.searchHeight + 4,
                                width: bounds.width - 20, height: 30)
        let searchShape = NSBezierPath(roundedRect: searchRect, xRadius: 8, yRadius: 8)
        rgb(0xF7F3E7).setFill()
        searchShape.fill()

        if filtered.isEmpty {
            let message = allItems.isEmpty ? "（还没有记录）" : "没找到匹配的"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            let size = (message as NSString).size(withAttributes: attrs)
            (message as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2,
                                                   y: bounds.midY - 6), withAttributes: attrs)
        }

        for (i, entry) in filtered.enumerated() {
            let row = rowRect(i)
            if i == selected {
                let hi = NSBezierPath(roundedRect: row.insetBy(dx: 2, dy: 2), xRadius: 7, yRadius: 7)
                rgb(0xFBF3D6).setFill()
                hi.fill()
            }

            let num = "\(i + 1)"
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: stemOutline,
            ]
            (num as NSString).draw(at: NSPoint(x: 18, y: row.midY - 7), withAttributes: numAttrs)

            let para = NSMutableParagraphStyle()
            para.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: ink,
                .paragraphStyle: para,
            ]
            let contentWidth = row.width - 52 - 30
            if entry.isImage {
                if let thumb = thumbnail(for: entry) {
                    let box = NSRect(x: 44, y: row.midY - 12, width: 40, height: 24)
                    let scale = min(box.width / thumb.size.width, box.height / thumb.size.height)
                    let size = NSSize(width: thumb.size.width * scale, height: thumb.size.height * scale)
                    thumb.draw(in: NSRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2,
                                          width: size.width, height: size.height))
                }
                let labelRect = NSRect(x: 94, y: row.midY - 8, width: contentWidth - 50, height: 18)
                (entry.title as NSString).draw(in: labelRect, withAttributes: attrs)
            } else {
                let textRect = NSRect(x: 44, y: row.midY - 8, width: contentWidth, height: 18)
                (entry.title as NSString).draw(in: textRect, withAttributes: attrs)
            }

            // 右侧的小图钉，点一下就置顶 / 取消
            let pin = entry.pinned ? "📌" : "📍"
            let pinAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: entry.pinned ? ink : NSColor(white: 0.75, alpha: 1),
            ]
            (pin as NSString).draw(at: NSPoint(x: row.maxX - 26, y: row.midY - 8), withAttributes: pinAttrs)
        }

        let hint = "输入搜索 · ↑↓ 选择 · 回车复制 · 点 📌 置顶"
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let hintSize = (hint as NSString).size(withAttributes: hintAttrs)
        (hint as NSString).draw(at: NSPoint(x: bounds.midX - hintSize.width / 2, y: 8),
                                withAttributes: hintAttrs)
    }

    private func thumbnail(for entry: ClipEntry) -> NSImage? {
        if let cached = thumbs[entry.file] { return cached }
        guard let image = entry.loadImage() else { return nil }
        thumbs[entry.file] = image
        return image
    }

    private func move(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        selected = max(0, min(filtered.count - 1, selected + delta))
    }

    private func pick(_ index: Int) {
        guard index >= 0, index < filtered.count else { return }
        onPick?(filtered[index])
    }

    // MARK: 搜索框的键盘

    func controlTextDidChange(_ obj: Notification) {
        selected = 0
        applyFilter()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            move(1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            move(-1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            pick(selected)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            onCancel?()
            return true
        default:
            return false
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: move(1)
        case 126: move(-1)
        case 36, 76: pick(selected)
        case 53: onCancel?()
        default:
            if let s = event.charactersIgnoringModifiers, let n = Int(s) {
                pick(n == 0 ? 9 : n - 1)
            }
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for i in 0..<filtered.count where rowRect(i).contains(point) {
            if pinRect(rowRect(i)).contains(point) {
                onTogglePin?(filtered[i])
            } else {
                selected = i
                pick(i)
            }
            return
        }
    }
}

final class ClipboardPanel: NSPanel {
    private let view = ClipboardPanelView()
    private var focusTimer: Timer?
    private var clickMonitor: Any?
    var onPick: ((ClipEntry) -> Void)?
    var onCancel: (() -> Void)?
    var onTogglePin: ((ClipEntry) -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: ClipboardPanelView.width, height: 200),
                   styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        contentView = view
        view.onPick = { [weak self] entry in self?.onPick?(entry) }
        view.onCancel = { [weak self] in self?.onCancel?() }
        view.onTogglePin = { [weak self] entry in self?.onTogglePin?(entry) }
    }

    // 无边框窗口默认不能成为 key window，不写这个键就传不进来
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 置顶后刷新列表，但不打断正在输入的搜索词
    func update(items: [ClipEntry]) {
        view.setItems(items, keepingQuery: true)
    }

    func present(items: [ClipEntry], above pet: NSWindow) {
        view.setItems(items)
        view.selected = 0
        let rows = max(items.count, 1)
        let height = ClipboardPanelView.searchHeight + CGFloat(rows) * ClipboardPanelView.rowHeight + 30
        setContentSize(NSSize(width: ClipboardPanelView.width, height: height))

        var x = pet.frame.midX - frame.width / 2
        var y = pet.frame.minY + PET_TOP + 8          // 默认浮在宠物头顶
        if let screen = pet.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            x = max(vf.minX + 6, min(x, vf.maxX - frame.width - 6))
            if y + height > vf.maxY - 6 { y = vf.maxY - height - 6 }
            y = max(vf.minY + 6, y)
        }
        setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(view.focusTarget)
        startFocusLoop()
        startClickMonitor()
    }

    private func startFocusLoop() {
        focusTimer?.invalidate()
        var ticks = 0
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] timer in
            guard let self = self, self.isVisible else {
                timer.invalidate()
                return
            }
            ticks += 1
            if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
            if !self.isKeyWindow {
                self.makeKey()
                self.makeFirstResponder(self.view.focusTarget)
            }
            if ticks > 24 { timer.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        focusTimer = timer
    }

    /// 点到自己窗口以外的地方就关掉（点到宠物本身除外，那个由宠物自己处理开关）
    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            if event.window !== self, !(event.window is PetWindow) {
                self.hide()
            }
            return event
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    func follow(_ pet: NSWindow) {
        guard isVisible else { return }
        var x = pet.frame.midX - frame.width / 2
        var y = pet.frame.minY + PET_TOP + 8
        if let screen = pet.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            x = max(vf.minX + 6, min(x, vf.maxX - frame.width - 6))
            if y + frame.height > vf.maxY - 6 { y = vf.maxY - frame.height - 6 }
            y = max(vf.minY + 6, y)
        }
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func hide() {
        guard isVisible else { return }
        focusTimer?.invalidate()
        focusTimer = nil
        stopClickMonitor()
        orderOut(nil)
        NSApp.deactivate()
    }

    /// 点到别的窗口就收起来
    override func resignKey() {
        super.resignKey()
        if isVisible { hide() }
    }
}

// MARK: - 结果查看窗口

/// 长文本结果（识别全文、长译文）用这个窗口看，可滚动、可选中
final class ResultWindow: NSPanel {
    private let scroll = NSScrollView()
    private let textView = NSTextView()
    private var onCopy: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
                   styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        title = "识别结果"
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = FlippedView(frame: NSRect(x: 0, y: 0, width: 480, height: 400))

        scroll.frame = NSRect(x: 16, y: 16, width: 448, height: 324)
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        root.addSubview(scroll)

        let copy = NSButton(title: "复制全部", target: self, action: #selector(copyAll))
        copy.frame = NSRect(x: 16, y: 352, width: 100, height: 30)
        copy.bezelStyle = .rounded
        root.addSubview(copy)

        let close = NSButton(title: "关闭", target: self, action: #selector(closeSelf))
        close.frame = NSRect(x: 362, y: 352, width: 102, height: 30)
        close.bezelStyle = .rounded
        close.keyEquivalent = "\u{1b}"
        root.addSubview(close)

        contentView = root
    }

    func present(text: String, title: String, onCopy: (() -> Void)? = nil) {
        self.title = title
        self.onCopy = onCopy
        textView.string = text
        textView.scrollToBeginningOfDocument(nil)
        center()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textView)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isVisible else { return }
            self.makeKey()
            self.makeFirstResponder(self.textView)
        }
    }

    @objc private func copyAll() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(textView.string, forType: .string)
        onCopy?()
        NSSound(named: "Tink")?.play()
    }

    @objc private func closeSelf() {
        close()
        NSApp.deactivate()
    }
}
