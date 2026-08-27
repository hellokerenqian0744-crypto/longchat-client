import Foundation
import Combine
import SwiftUI
import SQLite3

/// 应用全局状态: 提供商(CCSwitch 式配置)、会话、流式生成。
///
/// 视图层只依赖这一个对象; 所有数据变更都会在这里触发防抖持久化。
@MainActor
final class AppState: ObservableObject {

    @Published var isAuthorized = false

    // MARK: - 发布状态

    /// 全部 API 提供商配置
    @Published var providers: [APIProvider]
    /// 当前生效的提供商 (CCSwitch 的"当前配置"概念)
    @Published var activeProviderID: UUID?
    /// 全部会话, 按更新时间倒序展示
    @Published var conversations: [Conversation]
    /// 当前选中会话
    @Published var activeConversationID: UUID?
    /// 输入框暂存的待发送附件 (文件选择器 / 拖拽均写入这里, 跨视图共享)
    @Published var pendingAttachments: [FileAttachment] = []
    /// 是否有文件正被拖拽进窗口 (未松手时; 驱动聊天区模糊与「松手发送」提示)
    @Published var isFileDragging = false
    /// 拖拽中鼠标在窗口中的位置 (用于在拖拽文件下方绘制主题色渐变阴影)
    @Published var dragLocation: CGPoint?
    /// 是否正在流式接收回复
    @Published private(set) var isStreaming = false
    /// 是否正处于思考阶段 (首个回复内容增量到达时结束, 独立于整个流式过程)
    @Published private(set) var isThinking = false
    /// 提供商管理面板 (sheet)
    @Published var showProviderSettings = false
    /// 侧边栏可见性 (照片应用式: 状态持久化, 下次启动保持)
    @Published var sidebarVisible: Bool = true {
        didSet {
            UserDefaults.standard.set(sidebarVisible, forKey: Self.sidebarVisibleKey)
        }
    }
    /// 启动时是否自动打开上一个对话 (关闭则打开主页)
    @Published var resumeLastConversation: Bool = false {
        didSet {
            UserDefaults.standard.set(resumeLastConversation, forKey: Self.resumeLastConversationKey)
        }
    }
    /// 用户名 (侧边栏底部显示, 设置 > 个性化 可自定义)
    @Published var username: String = "" {
        didSet {
            UserDefaults.standard.set(username, forKey: Self.usernameKey)
        }
    }
    /// 全wwwcvc局强调色 hex (按钮高亮 / 输入框高亮边框)
    @Published var accentHex: String = Theme.defaultAccentHex {
        didSet {
            UserDefaults.standard.set(accentHex, forKey: Self.accentHexKey)
            Theme.accentOverride = Color(hex: accentHex)
        }
    }
    /// 客户端主题 (设置 > 外观 > 主题); 空字符串 = 自定义颜色
    @Published var themeKey: String = ThemePreset.defaultKey {
        didSet {
            UserDefaults.standard.set(themeKey, forKey: Self.themeKeyKey)
            applyTheme()
        }
    }
    /// 主题 fade 速度 (1...10, 默认 7) — 驱动彩虹动画速度
    @Published var themeFadeSpeed: Int = 7 {
        didSet {
            UserDefaults.standard.set(themeFadeSpeed, forKey: Self.themeFadeSpeedKey)
            Theme.rainbowSpeed = Double(themeFadeSpeed)
        }
    }
    /// 主题 fade 方向 (false = 默认, true = 反转)
    @Published var themeUpdown: Bool = false {
        didSet {
            UserDefaults.standard.set(themeUpdown, forKey: Self.themeUpdownKey)
            Theme.rainbowReversed = themeUpdown
            Theme.fadeReversed = themeUpdown
        }
    }
    /// 是否启用全局 fade 呼吸 (关闭 = 单一静态主题色, 消除卡顿)
    @Published var fadeEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(fadeEnabled, forKey: Self.fadeEnabledKey)
            Theme.fadeEnabled = fadeEnabled
        }
    }
    /// 用户气泡背景样式 (设置 > 外观 > 气泡)
    @Published var bubbleStyle: String = BubbleStyle.themeGradient.rawValue {
        didSet {
            UserDefaults.standard.set(bubbleStyle, forKey: Self.bubbleStyleKey)
        }
    }
    /// 全局系统提示词 (设置 > 个性化)
    @Published var systemPrompt: String = "" {
        didSet {
            UserDefaults.standard.set(systemPrompt, forKey: Self.systemPromptKey)
        }
    }
    /// 全局输出强度温度 (设置 > 个性化)
    @Published var temperature: Double = 0.7 {
        didSet {
            UserDefaults.standard.set(temperature, forKey: Self.temperatureKey)
        }
    }
    /// 当前输出强度 = 推理强度 (reasoning_effort: none/low/medium/high)
    /// 跟随当前模型: 切换模型时载入该模型的记忆值, 调整时按模型保存。
    @Published var reasoningEffort: String = "medium" {
        didSet {
            let previous = oldValue
            UserDefaults.standard.set(reasoningEffort, forKey: Self.reasoningEffortKey)
            if reasoningEffort == "max", previous != "max" {
                MaxTierSound.play()
            }
            // 每个模型的强度独立记忆 (跟随模型, 不跟随 API)
            if let model = activeProvider?.model {
                modelEfforts[model] = reasoningEffort
            }
        }
    }
    /// 每个模型的推理强度记忆: [模型名: effort]
    @Published var modelEfforts: [String: String] = [:] {
        didSet {
            UserDefaults.standard.set(modelEfforts, forKey: Self.modelEffortsKey)
        }
    }

    private static let sidebarVisibleKey = "ui.sidebarVisible"
    private static let resumeLastConversationKey = "ui.resumeLastConversation"
    private static let usernameKey = "ui.username"
    private static let accentHexKey = "ui.accentHex"
    private static let themeKeyKey = "ui.themeKey"
    private static let themeFadeSpeedKey = "ui.themeFadeSpeed"
    private static let themeUpdownKey = "ui.themeUpdown"
    private static let fadeEnabledKey = "ui.fadeEnabled"
    private static let bubbleStyleKey = "ui.bubbleStyle"
    private static let systemPromptKey = "ui.systemPrompt"
    private static let temperatureKey = "ui.temperature"
    private static let reasoningEffortKey = "ui.reasoningEffort"
    private static let modelEffortsKey = "ui.modelEfforts"

    // MARK: - 私有

    private var streamingTask: Task<Void, Never>?
    private var saveSubscription: AnyCancellable?

    // MARK: - 初始化

    init() {
        let data = Storage.load()

        // 首次启动: 种入常用预设, 用户只需填 API Key
        var seededProviders = data.providers
        var seededActiveID = data.activeProviderID
        if seededProviders.isEmpty {
            let seeds = [
                APIProvider.presets[0],  // OpenAI
                APIProvider.presets[2],  // DeepSeek
                APIProvider.presets[5],  // Ollama 本地
            ]
            seededProviders = seeds.map(APIProvider.from)
            seededActiveID = seededProviders.first?.id
        }

        providers = seededProviders
        activeProviderID = seededActiveID
        conversations = data.conversations
        // 启动时是否恢复上一个对话 (默认关闭 → 打开主页)
        resumeLastConversation = UserDefaults.standard.object(forKey: Self.resumeLastConversationKey) as? Bool ?? false
        activeConversationID = resumeLastConversation ? data.activeConversationID : nil
        // 读取上次的侧边栏可见状态
        sidebarVisible = UserDefaults.standard.object(forKey: Self.sidebarVisibleKey) as? Bool ?? true
        // 个性化: 用户名 + 全局强调色
        username = UserDefaults.standard.string(forKey: Self.usernameKey) ?? ""
        accentHex = UserDefaults.standard.string(forKey: Self.accentHexKey) ?? Theme.defaultAccentHex
        Theme.accentOverride = Color(hex: accentHex)
        // 客户端主题 (设置 > 外观 > 主题)
        themeKey = UserDefaults.standard.string(forKey: Self.themeKeyKey) ?? ThemePreset.defaultKey
        themeFadeSpeed = UserDefaults.standard.object(forKey: Self.themeFadeSpeedKey) as? Int ?? 7
        themeUpdown = UserDefaults.standard.object(forKey: Self.themeUpdownKey) as? Bool ?? false
        fadeEnabled = UserDefaults.standard.object(forKey: Self.fadeEnabledKey) as? Bool ?? true
        bubbleStyle = UserDefaults.standard.string(forKey: Self.bubbleStyleKey) ?? BubbleStyle.themeGradient.rawValue
        // 若上次选中了命名主题, 以主题起始色覆盖强调色, 保证一致性
        applyTheme()
        systemPrompt = UserDefaults.standard.string(forKey: Self.systemPromptKey) ?? ""
        temperature = UserDefaults.standard.object(forKey: Self.temperatureKey) as? Double ?? 0.7
        reasoningEffort = UserDefaults.standard.string(forKey: Self.reasoningEffortKey) ?? "medium"
        modelEfforts = UserDefaults.standard.dictionary(forKey: Self.modelEffortsKey) as? [String: String] ?? [:]
        observeForAutoSave()
    }

    /// 将当前主题应用到全局强调色与彩虹状态。
    ///
    /// 命名主题 → 强调色 = 主题起始色; `rainbow`/`astolfo` → 启用动态彩虹。
    /// 空 key (自定义颜色) → 保持用户手动选择的强调色。
    private func applyTheme() {
        Theme.rainbowSpeed = Double(themeFadeSpeed)
        Theme.rainbowReversed = themeUpdown
        Theme.fadeSpeed = Double(themeFadeSpeed)
        Theme.fadeReversed = themeUpdown
        Theme.fadeEnabled = fadeEnabled
        if let preset = ThemePreset.byKey(themeKey) {
            Theme.rainbowThemeActive = preset.isRainbow
            Theme.themeRainbowSaturation = preset.rainbowSaturation
            Theme.themeRainbowBrightness = preset.rainbowBrightness
            Theme.fadeStart = preset.start
            Theme.fadeEnd = preset.end
            let hex = preset.start.hexString
            accentHex = hex
            Theme.accentOverride = Color(hex: hex)
        } else {
            Theme.rainbowThemeActive = false
            Theme.themeRainbowSaturation = 1.0
            Theme.themeRainbowBrightness = 1.0
            Theme.fadeStart = Theme.Palette.accentMaxSat
            Theme.fadeEnd = Theme.Palette.accentFadeEnd
        }
    }

    /// 选择某个主题预设。
    func selectTheme(_ key: String) {
        themeKey = key
    }

    /// 当前全局强调色
    var accentColor: Color {
        Color(hex: accentHex)
    }

    /// 监听关键状态, 防抖 0.4s 后落盘
    private func observeForAutoSave() {
        let p1 = $providers.map { _ in () }
        let p2 = $activeProviderID.map { _ in () }
        let p3 = $conversations.map { _ in () }
        let p4 = $activeConversationID.map { _ in () }
        saveSubscription = Publishers.Merge4(p1, p2, p3, p4)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistNow() }
    }

    private func persistNow() {
        let data = AppData(
            providers: providers,
            activeProviderID: activeProviderID,
            conversations: conversations,
            activeConversationID: activeConversationID
        )
        Storage.save(data)
    }

    // MARK: - 派生属性

    var activeProvider: APIProvider? {
        providers.first { $0.id == activeProviderID } ?? providers.first
    }

    var activeConversation: Conversation? {
        conversations.first { $0.id == activeConversationID }
    }

    var sortedConversations: [Conversation] {
        conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 推理强度跟随模型: 切换模型/API 后载入该模型记忆的强度档位,
    /// 无记忆则取该模型档位表的中档并落盘。
    func loadEffort(forModel model: String, providerName: String) {
        let saved = modelEfforts[model]
        reasoningEffort = saved ?? Reasoning.defaultEffort(name: providerName, model: model)
    }

    // MARK: - 提供商操作 (CCSwitch)

    func setActiveProvider(_ id: UUID) {
        activeProviderID = id
    }

    func upsertProvider(_ provider: APIProvider) {
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = provider
        } else {
            providers.append(provider)
            if activeProviderID == nil { activeProviderID = provider.id }
        }
    }

    func deleteProvider(_ id: UUID) {
        providers.removeAll { $0.id == id }
        if activeProviderID == id {
            activeProviderID = providers.first?.id
        }
    }

    func addProvider(from preset: APIProvider.Preset) {
        upsertProvider(APIProvider.from(preset))
    }

    // MARK: - 从 CC Switch 导入 (实验性)

    /// 从 CC Switch 的 SQLite 配置库 (~/.cc-switch/cc-switch.db) 导入提供商。
    /// 返回 (成功导入数, 失败数)。
    @discardableResult
    func importFromCCSwitch() -> (imported: Int, failed: Int) {
        let home = NSHomeDirectory()
        let dbPath = home + "/.cc-switch/cc-switch.db"
        guard FileManager.default.fileExists(atPath: dbPath) else { return (0, 0) }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { return (0, 0) }
        defer { sqlite3_close(db) }

        var imported = 0
        var failed = 0
        var stmt: OpaquePointer?
        let sql = "SELECT name, app_type, settings_config, is_current FROM providers"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return (0, 0) }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let nameC = sqlite3_column_text(stmt, 0),
                  let typeC = sqlite3_column_text(stmt, 1),
                  let cfgC = sqlite3_column_text(stmt, 2) else {
                failed += 1
                continue
            }
            let name = String(cString: nameC)
            let appType = String(cString: typeC)
            let settingsConfig = String(cString: cfgC)
            let isCurrent = sqlite3_column_int(stmt, 3) == 1

            guard let provider = Self.parseCCSwitchProvider(name: name,
                                                            appType: appType,
                                                            settingsConfig: settingsConfig) else {
                failed += 1
                continue
            }
            // 同名视为同一提供商, 覆盖更新 (补上 API Key / 地址); 否则追加
            if let index = providers.firstIndex(where: { $0.name == provider.name }) {
                providers[index] = provider
            } else {
                providers.append(provider)
            }
            if isCurrent {
                activeProviderID = provider.id
            }
            imported += 1
        }
        return (imported, failed)
    }

    /// 解析 CC Switch 的 settings_config (JSON): auth 密钥 + config TOML 里的 base_url/model
    private static func parseCCSwitchProvider(name: String,
                                              appType: String,
                                              settingsConfig: String) -> APIProvider? {
        guard let data = settingsConfig.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }

        var provider = APIProvider()
        provider.name = name
        // 类型: Claude 系 -> .anthropic, 其余走 OpenAI 兼容
        provider.kind = appType.contains("claude") ? .anthropic : .openAICompatible

        // API Key: auth.OPENAI_API_KEY / ANTHROPIC_API_KEY / GOOGLE_API_KEY / 其它
        if let auth = json["auth"] as? [String: Any] {
            let candidates = ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GOOGLE_API_KEY"]
            if let key = candidates.lazy.compactMap({ auth[$0] as? String })
                .first(where: { !$0.isEmpty }) {
                provider.apiKey = key
            } else if let first = auth.values.compactMap({ $0 as? String }).first {
                provider.apiKey = first
            }
        }

        // config (TOML): 提取 base_url 与 model
        if let config = json["config"] as? String {
            let parsed = Self.parseTOMLConfig(config)
            if let model = parsed.model { provider.model = model }
            if let base = parsed.baseURL {
                provider.baseURL = base
            } else if appType.contains("claude") {
                provider.baseURL = "https://api.anthropic.com"
            }
        }

        guard !provider.baseURL.isEmpty else { return nil }
        return provider
    }

    /// 极简 TOML 解析: 顶层 model, 以及 base_url (优先 [model_providers.*] 段内)
    private static func parseTOMLConfig(_ config: String) -> (baseURL: String?, model: String?) {
        var baseURL: String?
        var model: String?
        var inModelProviders = false

        for rawLine in config.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") && line.hasSuffix("]") {
                inModelProviders = line.contains("model_providers")
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
            if key == "model", model == nil {
                model = value
            }
            if key == "base_url" {
                if inModelProviders {
                    baseURL = value
                } else if baseURL == nil {
                    baseURL = value
                }
            }
        }
        return (baseURL, model)
    }

    // MARK: - 会话操作

    @discardableResult
    func newConversation() -> UUID {
        var conversation = Conversation()
        // 避免同一秒内连续新建时排序抖动
        conversation.updatedAt = Date()
        conversations.insert(conversation, at: 0)
        activeConversationID = conversation.id
        return conversation.id
    }

    func selectConversation(_ id: UUID) {
        activeConversationID = id
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if activeConversationID == id {
            activeConversationID = sortedConversations.first?.id
        }
    }

    func renameConversation(_ id: UUID, to title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        conversations[index].title = trimmed
    }

    private func updateConversation(_ conversation: Conversation) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index] = conversation
    }

    // MARK: - 附件暂存

    /// 从文件 URL 读取内容并追加到待发送附件。
    func addPendingAttachments(_ urls: [URL]) {
        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let kind = FileKind.detect(fileName: url.lastPathComponent, data: data)
            pendingAttachments.append(FileAttachment(name: url.lastPathComponent,
                                                     kind: kind,
                                                     sizeBytes: data.count,
                                                     data: data))
        }
    }

    func removePendingAttachment(_ id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func clearPendingAttachments() {
        pendingAttachments = []
    }

    // MARK: - 发送与流式生成

    /// 发送一条用户消息 (可附带文件) 并开始流式接收回复。
    func send(_ text: String, attachments: [FileAttachment] = []) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty || !attachments.isEmpty), !isStreaming else { return }

        guard let provider = activeProvider else {
            showProviderSettings = true
            return
        }

        // 没有会话则新建
        if activeConversation == nil { newConversation() }
        guard var conversation = activeConversation else { return }

        // 首个用户消息作为会话标题
        let isFirstMessage = conversation.messages.isEmpty
        conversation.messages.append(ChatMessage(role: .user, content: trimmed, attachments: attachments))
        if isFirstMessage {
            conversation.title = trimmed.isEmpty
                ? (attachments.first.map { String($0.name.prefix(28)) } ?? "新对话")
                : String(trimmed.prefix(28))
        }
        conversation.updatedAt = Date()
        conversation.lastProviderID = provider.id

        // 占位的助手消息, 流式增量会持续追加到这里
        let assistantMessage = ChatMessage(role: .assistant, content: "", modelName: provider.model)
        conversation.messages.append(assistantMessage)
        updateConversation(conversation)

        beginStreaming(
            conversationID: conversation.id,
            provider: provider,
            assistantMessageID: assistantMessage.id,
            history: conversation.messages.dropLast().map { $0 }
        )
    }

    /// 重新生成最后一条助手回复。
    func regenerate() {
        guard !isStreaming,
              let provider = activeProvider,
              var conversation = activeConversation,
              let last = conversation.messages.last,
              last.role == .assistant
        else { return }

        conversation.messages.removeLast()
        let assistantMessage = ChatMessage(role: .assistant, content: "", modelName: provider.model)
        conversation.messages.append(assistantMessage)
        conversation.updatedAt = Date()
        updateConversation(conversation)

        beginStreaming(
            conversationID: conversation.id,
            provider: provider,
            assistantMessageID: assistantMessage.id,
            history: conversation.messages.dropLast().map { $0 }
        )
    }

    /// 停止当前流式生成, 保留已接收的部分。
    func stopStreaming() {
        streamingTask?.cancel()
    }

    private func beginStreaming(
        conversationID: UUID,
        provider: APIProvider,
        assistantMessageID: UUID,
        history: [ChatMessage]
    ) {
        isStreaming = true
        isThinking = true

        streamingTask = Task { [weak self] in
            do {
                _ = try await ChatClient.stream(provider: provider,
                                                history: history,
                                                systemPrompt: self?.systemPrompt ?? "",
                                                temperature: self?.temperature ?? 0.7,
                                                reasoningEffort: self?.reasoningEffort ?? "medium") { delta in
                    Task { @MainActor [weak self] in
                        self?.appendDelta(delta,
                                          conversationID: conversationID,
                                          messageID: assistantMessageID)
                    }
                } onThinking: { thinking in
                    Task { @MainActor [weak self] in
                        self?.appendThinkingDelta(thinking,
                                                  conversationID: conversationID,
                                                  messageID: assistantMessageID)
                    }
                }
                self?.finishStreaming(conversationID: conversationID,
                                      messageID: assistantMessageID,
                                      errorMessage: nil)
            } catch is CancellationError {
                self?.finishStreaming(conversationID: conversationID,
                                      messageID: assistantMessageID,
                                      errorMessage: nil)
            } catch let urlError as URLError where urlError.code == .cancelled {
                self?.finishStreaming(conversationID: conversationID,
                                      messageID: assistantMessageID,
                                      errorMessage: nil)
            } catch {
                self?.finishStreaming(conversationID: conversationID,
                                      messageID: assistantMessageID,
                                      errorMessage: error.localizedDescription)
            }
        }
    }

    private func appendDelta(_ delta: String, conversationID: UUID, messageID: UUID) {
        guard isStreaming,
              var conversation = conversations.first(where: { $0.id == conversationID }),
              let index = conversation.messages.firstIndex(where: { $0.id == messageID })
        else { return }
        // 首个回复内容增量到达 → 思考结束
        if isThinking { isThinking = false }
        conversation.messages[index].content += delta
        updateConversation(conversation)
    }

    /// 累积思考过程增量 (reasoning/thinking)
    private func appendThinkingDelta(_ delta: String, conversationID: UUID, messageID: UUID) {
        guard isStreaming,
              var conversation = conversations.first(where: { $0.id == conversationID }),
              let index = conversation.messages.firstIndex(where: { $0.id == messageID })
        else { return }
        conversation.messages[index].thinking = (conversation.messages[index].thinking ?? "") + delta
        updateConversation(conversation)
    }

    private func finishStreaming(conversationID: UUID, messageID: UUID, errorMessage: String?) {
        isStreaming = false
        isThinking = false
        streamingTask = nil

        guard var conversation = conversations.first(where: { $0.id == conversationID }),
              let index = conversation.messages.firstIndex(where: { $0.id == messageID })
        else { return }

        if let errorMessage {
            if conversation.messages[index].content.isEmpty {
                conversation.messages[index].content = errorMessage
                conversation.messages[index].isError = true
            } else {
                // 已有部分内容: 保留内容, 追加错误说明
                conversation.messages.append(ChatMessage(role: .assistant,
                                                         content: errorMessage,
                                                         isError: true))
            }
        } else if conversation.messages[index].content.isEmpty {
            conversation.messages[index].content = "(空响应：当前 API 未返回正文，请检查模型名称、推理档位与 API Key)"
            conversation.messages[index].isError = true
        }
        conversation.updatedAt = Date()
        updateConversation(conversation)
    }
}
