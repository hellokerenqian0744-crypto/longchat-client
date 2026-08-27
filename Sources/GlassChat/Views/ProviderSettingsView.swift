import SwiftUI

/// API 提供商管理 — 标准 macOS 设置窗口 (Settings 场景, ⌘,)。
///
/// 采用苹果官方文档的设置窗口范式: 标签页在窗口顶部, 内容在下方。
/// 自定义顶栏标签: 选中项图标/文字使用全局强调色
/// (原生 TabView 的选中色跟随系统强调色, 无法覆盖, 故自绘)。
struct ProviderSettingsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.liveAccent) private var liveAccent


    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general
        case appearance
        case personalization
        case providers
        case experimental

        var id: String { rawValue }

        var title: String {
            switch self {
            case .providers: return "提供商"
            case .general: return "通用"
            case .personalization: return "个性化"
            case .appearance: return "外观"
            case .experimental: return "实验性"
            }
        }

        var icon: String {
            switch self {
            case .providers: return "server.rack"
            case .general: return "gearshape"
            case .personalization: return "paintbrush"
            case .appearance: return "circle.lefthalf.filled"
            case .experimental: return "flask"
            }
        }
    }

    @Local private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            content
        }
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 640,
               minHeight: 460, idealHeight: 500, maxHeight: 640)
        .onAppear {
            // 设置窗口标题显示「设置」而非 "GlassChat Settings"
            DispatchQueue.main.async {
                for window in NSApplication.shared.windows
                where window.isVisible && window.title.contains("Settings") {
                    window.title = "设置"
                }
            }
        }
    }

    // MARK: - 自定义顶栏标签

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(tab.title)
                            .font(.callout.weight(selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? liveAccent : Color.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background {
                        if selectedTab == tab {
                            Capsule().fill(liveAccent.opacity(0.12))
                        }
                    }
                    .overlay {
                        if selectedTab == tab {
                            Capsule().strokeBorder(liveAccent.opacity(0.45), lineWidth: 1)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - 标签内容

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .providers: ProvidersPane()
        case .general: GeneralPane()
        case .personalization: PersonalizationPane()
        case .appearance: AppearancePane()
        case .experimental: ExperimentalPane()
        }
    }
}

// MARK: - 实验性标签页 (CC Switch 导入等)

private struct ExperimentalPane: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.liveAccent) private var liveAccent


    @Local private var importing = false
    @Local private var resultText: String?

    var body: some View {
        Form {
            Section("实验性功能") {
                Button {
                    runImport()
                } label: {
                    if importing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("从 CC Switch 导入", systemImage: "tray.and.arrow.down")
                    }
                }
                .disabled(importing)

                if let resultText {
                    Text(resultText)
                        .font(.callout)
                        .foregroundStyle(liveAccent)
                }

                Text("从 ~/.cc-switch/cc-switch.db 读取 CC Switch 的提供商配置，导入名称、API Key、Base URL 与模型（同名同地址的配置会被覆盖更新）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private func runImport() {
        importing = true
        resultText = nil
        let result = app.importFromCCSwitch()
        importing = false
        if result.imported > 0 {
            resultText = "✅ 成功导入 \(result.imported) 个提供商"
                + (result.failed > 0 ? "，\(result.failed) 个解析失败" : "")
        } else if result.failed > 0 {
            resultText = "导入完成，但 \(result.failed) 个配置解析失败（缺少 Base URL）"
        } else {
            resultText = "未发现可导入的 CC Switch 配置"
        }
    }
}

// MARK: - 个性化标签页 (用户名 + 系统提示词 + 温度)

private struct PersonalizationPane: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Form {
            Section("生成") {
                LabeledContent("系统提示词") {
                    TextField("可选, 例如: 你是一个简洁的助手", text: $app.systemPrompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...5)
                }

                LabeledContent("温度\(app.temperature, specifier: "%.1f")") {
                    Slider(value: $app.temperature, in: 0...2, step: 0.1)
                }
            }

            Section {
                Text("系统提示词与输出温度对所有对话生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

// MARK: - 外观标签页 (全局强调色)

private struct AppearancePane: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.liveAccent) private var liveAccent


    var body: some View {
        Form {
            Section("主题") {
                Text("主题色应用于按钮高亮、输入框高亮边框等全局元素。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("当前主题") {
                    Text(currentThemeName)
                        .foregroundStyle(liveAccent)
                }

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 30, maximum: 34), spacing: 10)],
                              alignment: .leading,
                              spacing: 10) {
                        customSwatch()
                        ForEach(ThemePreset.all) { preset in
                            swatch(for: preset)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(height: 200)

                if app.themeKey.isEmpty {
                    ColorPicker("全局强调色", selection: accentBinding)
                }

                Toggle("反色", isOn: $app.themeUpdown)

                LabeledContent("Fade 速度 \(app.themeFadeSpeed)") {
                    Slider(value: fadeSpeedBinding, in: 1...10, step: 1)
                }
            }

            Section("气泡") {
                Picker("样式", selection: $app.bubbleStyle) {
                    ForEach(BubbleStyle.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                Text("主题渐变在首/次色间过渡; 亮色渐变为单色亮→基(随反色切换首/次色); 纯色跟随首色。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("账号") {
                LabeledContent("用户名") {
                    TextField("例如: 小明", text: $app.username)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { app.accentColor },
            set: {
                app.accentHex = $0.hexString
                // 手动取色 → 视为自定义颜色, 解除命名主题绑定
                app.themeKey = ""
            }
        )
    }

    private var currentThemeName: String {
        ThemePreset.byKey(app.themeKey)?.name ?? "自定义"
    }

    private var fadeSpeedBinding: Binding<Double> {
        Binding(
            get: { Double(app.themeFadeSpeed) },
            set: { app.themeFadeSpeed = Int($0.rounded()) }
        )
    }

    @ViewBuilder
    private func swatch(for preset: ThemePreset) -> some View {
        let selected = app.themeKey == preset.key
        Button {
            app.selectTheme(preset.key)
        } label: {
            swatchFill(for: preset)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(selected ? liveAccent : Color.primary.opacity(0.12),
                                      lineWidth: selected ? 2 : 1)
                }
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1)
                            .padding(1)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(preset.name)
    }

    @ViewBuilder
    private func customSwatch() -> some View {
        let selected = app.themeKey.isEmpty
        Button {
            // 切换到自定义颜色, 下方显示全局强调色调色盘
            app.themeKey = ""
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                Image(systemName: "eyedropper.halffull")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 30, height: 30)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? liveAccent : Color.primary.opacity(0.12),
                                  lineWidth: selected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .padding(1)
                }
            }
        }
        .buttonStyle(.plain)
        .help("自定义颜色")
    }

    @ViewBuilder
    private func swatchFill(for preset: ThemePreset) -> some View {
        if preset.isRainbow {
            let hues = (0...12).map {
                Color(hue: Double($0 % 12) / 12.0,
                      saturation: preset.rainbowSaturation,
                      brightness: preset.rainbowBrightness)
            }
            AngularGradient(colors: hues, center: .center)
        } else {
            LinearGradient(colors: [preset.start, preset.end],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        }
    }
}

// MARK: - 提供商标签页 (上下格局: 顶部选择栏 + 下方表单)

private struct ProvidersPane: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.liveAccent) private var liveAccent


    @Local private var selectedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            editor
        }
        .onAppear {
            if selectedID == nil {
                selectedID = app.activeProvider?.id ?? app.providers.first?.id
            }
        }
        // 当前编辑的提供商被删除后, 自动切到剩余的第一个
        .onChange(of: app.providers.map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID) {
                self.selectedID = ids.first
            }
        }
    }

    // MARK: 顶部: 选择 / 新增 / 设为当前

    private var topBar: some View {
        HStack(spacing: 10) {
            Picker("提供商", selection: $selectedID) {
                ForEach(app.providers) { provider in
                    Text(provider.name.isEmpty ? "未命名" : provider.name)
                        .tag(Optional(provider.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 240)

            Menu {
                ForEach(APIProvider.presets) { preset in
                    Button {
                        let provider = APIProvider.from(preset)
                        app.upsertProvider(provider)
                        selectedID = provider.id
                    } label: {
                        VStack(alignment: .leading) {
                            Text(preset.name)
                            Text(preset.note)
                        }
                    }
                }
            } label: {
                Label("新增", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

            Spacer()

            if let provider = app.providers.first(where: { $0.id == selectedID }) {
                if provider.id != app.activeProvider?.id {
                    Button {
                        withAnimation(Theme.Motion.quickSpring) {
                            app.setActiveProvider(provider.id)
                        }
                    } label: {
                        Label("设为当前", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(liveAccent)
                } else {
                    Label("当前使用中", systemImage: "checkmark.seal.fill")
                        .font(.callout)
                        .foregroundStyle(liveAccent)
                }
            }
        }
        .padding(12)
    }

    // MARK: 下方: 编辑表单

    @ViewBuilder
    private var editor: some View {
        if let selectedID,
           let provider = app.providers.first(where: { $0.id == selectedID }) {
            ProviderEditor(provider: provider)
        } else {
            ContentUnavailableView("选择一个提供商",
                                   systemImage: "server.rack",
                                   description: Text("从顶部选择或新增一个 API 配置"))
        }
    }
}

// MARK: - 通用标签页

private struct GeneralPane: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Form {
            Section("窗口") {
                Toggle("启动时显示侧边栏", isOn: $app.sidebarVisible)
                Toggle("启动时打开上一个对话", isOn: $app.resumeLastConversation)
            }

            Section {
                Text("关闭「打开上一个对话」时, 启动后显示主页; 开启则恢复到上次会话。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
        .padding(12)
    }
}

// MARK: - 单个提供商编辑器 (系统设置式分组表单)

private struct ProviderEditor: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.liveAccent) private var liveAccent


    let provider: APIProvider

    @Local private var showsSecret = false
    @Local private var testPhase: TestPhase = .idle
    @Local private var isRefreshingModels = false
    @Local private var modelResult: String?

    enum TestPhase: Equatable {
        case idle
        case running
        case success(String)
        case failure(String)
    }

    /// 直接写回 AppState 的绑定, 编辑即时生效并自动持久化
    private func binding<T>(_ keyPath: WritableKeyPath<APIProvider, T>) -> Binding<T> {
        Binding(
            get: {
                app.providers.first(where: { $0.id == provider.id })?[keyPath: keyPath]
                    ?? provider[keyPath: keyPath]
            },
            set: { newValue in
                guard let index = app.providers.firstIndex(where: { $0.id == provider.id }) else { return }
                app.providers[index][keyPath: keyPath] = newValue
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                form
            }
            .padding(20)
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(provider.tint)
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name.isEmpty ? "未命名提供商" : provider.name)
                    .font(.title3.weight(.semibold))
                Text(provider.kind.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: 分组表单

    private var form: some View {
        Form {
            Section("基本信息") {
                LabeledContent("名称") {
                    TextField("例如: OpenAI 主账号", text: binding(\.name))
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("协议类型") {
                    Picker("", selection: binding(\.kind)) {
                        ForEach(ProviderKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                LabeledContent("Base URL") {
                    TextField("https://api.openai.com/v1", text: binding(\.baseURL))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent("API Key") {
                    HStack(spacing: 6) {
                        Group {
                            if showsSecret {
                                TextField("sk-…", text: binding(\.apiKey))
                            } else {
                                SecureField("sk-…", text: binding(\.apiKey))
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                        Button {
                            showsSecret.toggle()
                        } label: {
                            Image(systemName: showsSecret ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(showsSecret ? "隐藏" : "显示")
                    }
                }

                LabeledContent("模型") {
                    TextField("gpt-4o / deepseek-chat / claude-…", text: binding(\.model))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section("高级") {
                HStack(spacing: 10) {
                    Button {
                        refreshModels()
                    } label: {
                        if isRefreshingModels {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("刷新模型列表", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(isRefreshingModels)

                    if let modelResult {
                        Text(modelResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if !provider.models.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已缓存 \(provider.models.count) 个模型 · 图标随列表刷新")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        // API 模型图标列表: 刷新后随模型名自动更新
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(provider.models, id: \.self) { model in
                                    HStack(spacing: 5) {
                                        ModelBrandView(providerName: provider.name,
                                                       model: model,
                                                       height: 10)
                                        Text(ModelDisplayName.name(providerName: provider.name,
                                                                   model: model))
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Theme.Palette.hoverFill.opacity(0.6)))
                                        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                                }
                            }
                        }
                    }
                }
            }

            Section("连接") {
                HStack(spacing: 10) {
                    Button {
                        runTest()
                    } label: {
                        if testPhase == .running {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("测试连接", systemImage: "dot.radiowaves.left.and.right")
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(testPhase == .running)

                    statusText
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        app.deleteProvider(provider.id)
                    } label: {
                        Label("删除此提供商", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var statusText: some View {
        switch testPhase {
        case .idle:
            EmptyView()
        case .running:
            Text("正在请求 \(host)…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(liveAccent)
        case .failure(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.caption)
                .foregroundStyle(Theme.Palette.danger)
                .lineLimit(2)
        }
    }

    private var host: String {
        URL(string: provider.baseURL)?.host ?? provider.baseURL
    }

    private func runTest() {
        testPhase = .running
        let snapshot = provider
        Task {
            do {
                let message = try await ChatClient.testConnection(snapshot)
                await MainActor.run { testPhase = .success(message) }
            } catch {
                await MainActor.run { testPhase = .failure(error.localizedDescription) }
            }
        }
    }

    /// 刷新模型列表 (参考 CC Switch: 从提供商 API 拉取真实模型)
    private func refreshModels() {
        guard !isRefreshingModels else { return }
        isRefreshingModels = true
        modelResult = nil
        let snapshot = provider
        Task {
            do {
                let models = try await ChatClient.fetchModels(provider: snapshot)
                await MainActor.run {
                    if let index = app.providers.firstIndex(where: { $0.id == snapshot.id }) {
                        app.providers[index].models = models
                    }
                    modelResult = "已获取 \(models.count) 个模型 · 图标已刷新"
                    isRefreshingModels = false
                }
            } catch {
                await MainActor.run {
                    modelResult = "获取失败: \(error.localizedDescription)"
                    isRefreshingModels = false
                }
            }
        }
    }
}
