import SwiftUI
import AppKit

/// 底部输入卡 (单行三段式): 圆形加号 / 一条聊天框 / 圆形发送按钮。
///
/// - 加号: 点击在按钮上方弹出功能菜单 (文件和文件夹 / 目标 / 计划 / 技能, 均为规划中)。
/// - 发送按钮: 触控板重按 (Force Touch) 弹出模型/输出强度切换面板。
struct ComposerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.liveAccent) private var liveAccent

    @Local private var draft = ""
    @FocusState private var inputFocused: Bool
    /// 模型 / 输出强度面板 (发送按钮重按弹出)
    @Local private var showsPanel = false
    /// 加号功能菜单
    @Local private var showsPlusMenu = false
    /// 加号菜单中点击的未实现功能提示
    @Local private var pendingFeature: String?
    /// 发送按钮在窗口坐标系中的位置 (重按检测用)
    @Local private var sendButtonFrame: CGRect = .zero
    /// 压力事件本地监听器
    @Local private var pressureMonitor: Any?
    /// 重按触发了面板 → 抑制这次点击的发送动作
    @Local private var suppressNextSend = false
    /// 发送按钮是否被指针悬停
    @Local private var isSendHovered = false
    /// 输入框内模型文字是否被指针悬停
    @Local private var chipHovered = false

    var body: some View {
        VStack(spacing: 8) {
            if !app.pendingAttachments.isEmpty {
                attachmentStrip
            }
            composerCard
        }
            // iMessage 式: 输入卡占满聊天区宽度
            .frame(maxWidth: .infinity)
            .onAppear {
                inputFocused = true
                installPressureMonitor()
            }
            .onDisappear {
                if let monitor = pressureMonitor {
                    NSEvent.removeMonitor(monitor)
                    pressureMonitor = nil
                }
            }
            .onChange(of: app.activeConversationID) {
                inputFocused = true
            }
    }

    // MARK: - 输入卡

    private var composerCard: some View {
        HStack(spacing: 9) {
            plusButton
            chatField
            actionButton
        }
    }

    /// 独立聊天胶囊 (iMessage 式: 与两侧圆钮分离, 自带玻璃底与聚焦高亮)
    private var chatField: some View {
        HStack(spacing: 8) {
            TextField("输入消息…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...8)
                .focused($inputFocused)
                .onSubmit(send)
                .frame(maxWidth: .infinity, alignment: .leading)

            modelPickerChip
        }
        .padding(.leading, 11)
        .padding(.trailing, 6)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .frame(minHeight: 30)
        .background(
            Capsule().fill(Theme.Palette.cardFill.opacity(0.55))
        )
        .glassEffect(.regular, in: Capsule())
        .overlay {
            if inputFocused {
                FlowingBorder(shape: Capsule())
            } else {
                Capsule()
                    .strokeBorder(Theme.Palette.glassHighlight, lineWidth: 1)
            }
        }
        .shadow(color: Theme.Palette.glassShadow, radius: 6, y: 2)
        .animation(Theme.Motion.fade, value: inputFocused)
    }

    /// 输入框右侧的模型名称 + 推理强度 (点击弹出模型选择菜单)
    private var modelPickerChip: some View {
        Button {
            showsPanel = true
        } label: {
            Text(modelLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .opacity(0.5)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(4)
                .background(
                    Capsule().fill(chipHovered ? Color.primary.opacity(0.10) : Color.clear)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { chipHovered = $0 }
        .popover(isPresented: $showsPanel, arrowEdge: .bottom) {
            ComposerControlPanel()
                .environmentObject(app)
        }
    }

    /// 友好模型名 + 推理强度 (如 "5.6 Sol Medium")
    private var modelLabel: String {
        if let model = app.activeProvider?.model, !model.isEmpty {
            return ModelDisplayName.chipLabel(providerName: app.activeProvider?.name ?? "",
                                              model: model,
                                              effort: app.reasoningEffort)
        }
        return app.activeProvider?.name ?? "模型"
    }

    // MARK: - 圆形加号 (功能菜单)

    private var plusButton: some View {
        Button {
            showsPlusMenu.toggle()
            pendingFeature = nil
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 29.5, height: 29.5)
                .background(Circle().fill(.white.opacity(0.08)))
                .glassEffect(.regular, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                .shadow(color: Theme.Palette.glassShadow, radius: 4, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsPlusMenu, arrowEdge: .bottom) {
            plusMenu
        }
        .help("添加")
    }

    /// 加号上方弹出的功能菜单 (均为规划中功能, 详见「关于 LongChat」)。
    private var plusMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            plusMenuItem("文件和文件夹", icon: "folder") {
                attachFiles()
            }
            plusMenuItem("目标", icon: "target")
            plusMenuItem("计划", icon: "checklist")
            plusMenuItem("技能", icon: "sparkles")

            Divider()

            Text(pendingFeature.map { "「\($0)」尚未实现 · 详见「关于 LongChat」" }
                 ?? "功能开发中 · 详见「关于 LongChat」")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .padding(6)
        .frame(minWidth: 220)
    }

    private func plusMenuItem(_ title: String, icon: String, action: (() -> Void)? = nil) -> some View {
        Button {
            if let action {
                action()
            } else {
                pendingFeature = title
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 附件

    /// 附件暂存条: 位于输入卡上方, 横向滚动, 每条可单独移除。
    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(app.pendingAttachments) { att in
                    attachmentChip(att)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attachmentChip(_ att: FileAttachment) -> some View {
        HStack(spacing: 6) {
            if att.kind == .image, let image = NSImage(data: att.data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: att.kind.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Theme.Palette.hoverFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(att.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(att.sizeDisplay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                app.removePendingAttachment(att.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("移除附件")
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Palette.cardFill.opacity(0.55))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
    }

    /// 打开系统文件选择器并暂存所选文件。
    private func attachFiles() {
        showsPlusMenu = false
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.prompt = "添加"
        guard panel.runModal() == .OK else { return }
        app.addPendingAttachments(panel.urls)
    }

    // MARK: - 发送 / 停止 (重按弹出模型面板)

    @ViewBuilder
    private var actionButton: some View {
        Group {
            if app.isStreaming {
                Button {
                    app.stopStreaming()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.Palette.danger)
                        .frame(width: 29.5, height: 29.5)
                        .background(Circle().fill(.white.opacity(0.08)))
                        .glassEffect(.regular, in: Circle())
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        }
                        .shadow(color: Theme.Palette.glassShadow, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .help("停止生成")
            } else {
                Button(action: send) {
                    Group {
                        if isSendHovered {
                            // 悬停: 空液态玻璃底 + 实时流动双色 fade(25%) + 发送箭头
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.06))
                                    .glassEffect(.regular, in: Circle())
                                ThemeFadeFill()
                                    .clipShape(Circle())
                                    .opacity(0.25)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.black)
                            }
                            .frame(width: 29.5, height: 29.5)
                            .overlay {
                                Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.75)
                            }
                            .shadow(color: Theme.Palette.glassShadow, radius: 4, y: 2)
                        } else {
                            // 默认: 透明玻璃底 + 当前模型图标
                            ModelBrandView(providerName: app.activeProvider?.name ?? "",
                                           model: app.activeProvider?.model ?? "",
                                           height: 15)
                                .frame(width: 29.5, height: 29.5)
                                .background(Circle().fill(.white.opacity(0.08)))
                                .glassEffect(.regular, in: Circle())
                                .overlay {
                                    Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1)
                                }
                                .shadow(color: Theme.Palette.glassShadow, radius: 4, y: 2)
                                .opacity(canSend ? 1 : 0.4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .onHover { isSendHovered = $0 }
                .animation(.easeInOut(duration: 0.2), value: isSendHovered)
                .help("发送 (Return)")
            }
        }
        .background(WindowFrameReader { frame in
            sendButtonFrame = frame
        })
    }

    // MARK: - 行为

    /// 有正文或附件即可发送。
    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !app.pendingAttachments.isEmpty
    }

    private func send() {
        // 重按弹出面板时抑制本次点击的发送动作
        if suppressNextSend {
            suppressNextSend = false
            return
        }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, !app.isStreaming else { return }
        draft = ""
        let currentAttachments = app.pendingAttachments
        app.clearPendingAttachments()
        app.send(text, attachments: currentAttachments)
        inputFocused = true
    }

    // MARK: - 触控板重按 (Force Touch)

    /// 安装压力事件监听: 在发送按钮范围内重按 (stage 2) 时弹出模型面板。
    private func installPressureMonitor() {
        guard pressureMonitor == nil else { return }
        pressureMonitor = NSEvent.addLocalMonitorForEvents(matching: .pressure) { event in
            guard event.stage == 2, !app.isStreaming else { return event }
            guard let window = event.window, window.isKeyWindow else { return event }
            guard sendButtonFrame.contains(event.locationInWindow) else { return event }
            // 重按 → 打开面板并抑制随后的点击发送
            suppressNextSend = true
            DispatchQueue.main.async {
                if !showsPanel { showsPanel = true }
            }
            return event
        }
    }
}

// MARK: - 窗口坐标读取

/// 以背景层形式挂到按钮上, 把按钮在窗口坐标系中的 frame 回传给调用方。
private struct WindowFrameReader: NSViewRepresentable {
    var onFrame: (CGRect) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onFrame = onFrame
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {
        nsView.onFrame = onFrame
        nsView.report()
    }

    final class ReaderView: NSView {
        var onFrame: (CGRect) -> Void = { _ in }

        override func layout() {
            super.layout()
            report()
        }

        func report() {
            guard let window else { return }
            onFrame(convert(bounds, to: nil))
        }
    }
}

// MARK: - 输入框聚焦流动渐变描边

/// 复用「关于 LongChat」窗口的流动渐变 (AngularGradient 随时间旋转),
/// 用于输入框聚焦与用户气泡的高亮描边, 线条更细。
struct FlowingBorder<S: InsettableShape>: View {
    let shape: S
    var lineWidth: CGFloat = 0.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            shape
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Theme.fadeFirst,
                            Theme.fadeSecond,
                            Theme.fadeFirst,
                            Theme.fadeSecond,
                            Theme.fadeFirst
                        ],
                        center: .center,
                        angle: .degrees(
                            (timeline.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 6)) / 6 * 360
                        )
                    ),
                    lineWidth: lineWidth
                )
                .shadow(color: Theme.fadeFirst.opacity(0.30), radius: 3)
        }
    }
}

// MARK: - 模型/输出强度控制面板

/// 点击发送键左侧单个按钮弹出的小菜单。
/// 默认仅显示输出强度滑块; 点「更多」展开 API 切换 + 模型切换 + 输出强度。
private struct ComposerControlPanel: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.liveAccent) private var liveAccent

    @Local private var expanded = false
    /// 切换 API 后待确认刷新的提供商
    @Local private var switchPendingProviderID: UUID?
    @Local private var modelRefreshResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 展开后追加当前模型的档位快捷胶囊 (随模型切换刷新)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("推理强度", systemImage: "brain.head.profile")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Text(currentTitle)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if expanded {
                    // 档位快捷选项 (随当前模型刷新; GPT 全档位自动换行)
                    FlowLayout(spacing: 6) {
                        ForEach(levels) { level in
                            Button {
                                app.reasoningEffort = level.effort
                            } label: {
                                Text(level.title)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(isCurrentLevel(level)
                                                              ? liveAccent.opacity(0.16)
                                                              : Theme.Palette.hoverFill.opacity(0.6)))
                                    .overlay(Capsule().strokeBorder(isCurrentLevel(level)
                                                                    ? liveAccent.opacity(0.5)
                                                                    : .white.opacity(0.12),
                                                                    lineWidth: 1))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                // 档位级滑块: sol/terra 用客户端 Power 滑块 (组合可切模型),
                // 其他 GPT 用 ChatGPT 客户端式扁平滑块, 非 GPT 用原生滑块
                if isPowerModel, !powerBundles.isEmpty {
                    PowerSlider(bundles: powerBundles,
                                currentModel: currentModel,
                                effort: $app.reasoningEffort,
                                onSelect: selectPowerBundle)
                } else if isGPTModel {
                    ChatGPTEffortSlider(levels: levels,
                                        sliderLevels: sliderLevels,
                                        effort: $app.reasoningEffort)
                } else {
                    Slider(value: levelIndexBinding,
                           in: 0...Double(max(levels.count - 1, 1)),
                           step: 1)
                }
            }

            if expanded {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("API")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: providerBinding) {
                        ForEach(app.providers) { provider in
                            Text(provider.name).tag(Optional(provider.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("模型")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // 原生 Picker (与上方 API 切换一致); 图标仅在聊天输入按钮上显示
                    Picker("", selection: modelBinding) {
                        ForEach(modelOptions, id: \.self) { model in
                            // 显示友好名称, tag 仍用原始模型 ID
                            Text(ModelDisplayName.name(providerName: app.activeProvider?.name ?? "",
                                                       model: model)).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded = false }
                } label: {
                    Label("收起", systemImage: "chevron.up")
                }
                .buttonStyle(.borderless)
                .font(.callout)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded = true }
                } label: {
                    Label("更多", systemImage: "chevron.down")
                }
                .buttonStyle(.borderless)
                .font(.callout)
            }
        }
        .padding(12)
        .frame(width: 280)
        // 切换 API 后询问是否刷新模型列表
        .confirmationDialog("刷新模型列表？",
                            isPresented: Binding(
                                get: { switchPendingProviderID != nil },
                                set: { if !$0 { switchPendingProviderID = nil } }
                            ),
                            titleVisibility: .visible) {
            Button("刷新模型列表") {
                refreshModelsForSwitch()
            }
            Button("取消", role: .cancel) {
                switchPendingProviderID = nil
            }
        } message: {
            Text("更换 API 后是否需要拉取该提供商的模型列表？\n模型强度档位会自动刷新。")
        }
        .overlay(alignment: .bottom) {
            if let modelRefreshResult {
                Text(modelRefreshResult)
                    .font(.caption)
                    .foregroundStyle(liveAccent)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: 绑定

    /// 档位索引绑定: 滑块 0...N 对应当前模型的推理强度档位, 一格一档
    private var levelIndexBinding: Binding<Double> {
        Binding(
            get: {
                let index = levels.firstIndex(where: { $0.effort == app.reasoningEffort })
                    ?? levels.firstIndex(where: { $0.title == "中" })
                    ?? 0
                return Double(index)
            },
            set: { newValue in
                let index = Int(newValue.rounded())
                guard levels.indices.contains(index) else { return }
                app.reasoningEffort = levels[index].effort
            }
        )
    }

    /// 当前推理强度是否命中某档位
    private func isCurrentLevel(_ level: IntensityLevel) -> Bool {
        level.effort == app.reasoningEffort
    }

    private var providerBinding: Binding<UUID?> {
        Binding(
            get: { app.activeProvider?.id },
            set: { newID in
                if let newID {
                    app.setActiveProvider(newID)
                    // 推理强度跟随模型: 载入该 API 当前模型的记忆强度
                    if let index = app.providers.firstIndex(where: { $0.id == newID }) {
                        let p = app.providers[index]
                        app.loadEffort(forModel: p.model, providerName: p.name)
                    }
                    // 弹出询问: 是否刷新模型列表
                    switchPendingProviderID = newID
                    modelRefreshResult = nil
                }
            }
        )
    }

    /// 弹窗确认后: 拉取新 API 的模型列表
    private func refreshModelsForSwitch() {
        guard let id = switchPendingProviderID,
              let provider = app.providers.first(where: { $0.id == id }) else {
            switchPendingProviderID = nil
            return
        }
        let snapshot = provider
        Task {
            do {
                let models = try await ChatClient.fetchModels(provider: snapshot)
                await MainActor.run {
                    if let index = app.providers.firstIndex(where: { $0.id == snapshot.id }) {
                        app.providers[index].models = models
                        // 推理强度档位随模型自动刷新
                    }
                    modelRefreshResult = "已获取 \(models.count) 个模型 · 档位/图标已刷新"
                    switchPendingProviderID = nil
                }
            } catch {
                await MainActor.run {
                    modelRefreshResult = "刷新失败: \(error.localizedDescription)"
                    switchPendingProviderID = nil
                }
            }
        }
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { app.activeProvider?.model ?? "" },
            set: { newModel in
                guard let id = app.activeProvider?.id,
                      let index = app.providers.firstIndex(where: { $0.id == id }) else { return }
                app.providers[index].model = newModel
                // 推理强度跟随模型: 载入该模型的记忆强度
                let p = app.providers[index]
                app.loadEffort(forModel: newModel, providerName: p.name)
            }
        )
    }

    /// 当前推理强度档位列表 (随当前 API/模型自动更新)
    private var levels: [IntensityLevel] {
        Reasoning.levels(name: app.activeProvider?.name ?? "",
                         model: app.activeProvider?.model ?? "")
    }

    /// ChatGPT 客户端滑块可见档位 (低/中/高/超高); 其余为隐藏档位, 仅选项可切换
    private var sliderLevels: [IntensityLevel] {
        Reasoning.sliderLevels(name: app.activeProvider?.name ?? "",
                               model: app.activeProvider?.model ?? "")
    }

    /// 是否 GPT 系列模型: 使用 ChatGPT 客户端式扁平滑块
    private var isGPTModel: Bool {
        Reasoning.isGPT(name: app.activeProvider?.name ?? "",
                        model: app.activeProvider?.model ?? "")
    }

    /// 当前模型名
    private var currentModel: String {
        app.activeProvider?.model ?? ""
    }

    /// 是否 sol/terra 家族 (客户端 Power 滑块专属)
    private var isPowerModel: Bool {
        guard let family = Reasoning.gptFamily(name: app.activeProvider?.name ?? "",
                                               model: currentModel) else { return false }
        return family == .sol || family == .terra
    }

    /// Power 滑块档位组合 (随模型列表刷新)
    private var powerBundles: [PowerBundle] {
        Reasoning.powerSliderBundles(availableModels: app.activeProvider?.models ?? [])
    }

    /// 当前选中的 Power 组合 (含隐藏档)
    private var currentBundle: PowerBundle? {
        if let b = powerBundles.first(where: { $0.model == currentModel && $0.effort == app.reasoningEffort }) {
            return b
        }
        return Reasoning.hiddenBundles(for: currentModel)
            .first(where: { $0.model == currentModel && $0.effort == app.reasoningEffort })
    }

    /// 标题: Power 模型显示客户端组合名 (如 "5.6 Sol Standard"), 其余显示档位名
    private var currentTitle: String {
        if isPowerModel, let b = currentBundle { return b.displayLabel }
        return levelTitle
    }

    /// 选择 Power 组合: 同时切换模型与推理强度 (客户端 Power 滑块行为)
    private func selectPowerBundle(_ bundle: PowerBundle) {
        guard let id = app.activeProvider?.id,
              let index = app.providers.firstIndex(where: { $0.id == id }) else { return }
        app.providers[index].model = bundle.model
        app.reasoningEffort = bundle.effort
    }

    /// 当前档位显示名 (无/低/中/高)
    private var levelTitle: String {
        levels.first(where: { $0.effort == app.reasoningEffort })?.title
            ?? levels.first(where: { $0.title == "中" })?.title
            ?? "中"
    }

    /// 模型候选列表 (当前模型若不在候选里, 追加到末尾)
    private var modelOptions: [String] {
        // 已通过「刷新模型列表」拉取的模型优先
        if let fetched = app.activeProvider?.models, !fetched.isEmpty {
            var result = fetched
            if let current = app.activeProvider?.model, !current.isEmpty, !result.contains(current) {
                result.append(current)
            }
            return result
        }
        let name = (app.activeProvider?.name ?? "").lowercased()
        let current = app.activeProvider?.model ?? ""
        var candidates: [String]
        if name.contains("deepseek") || current.contains("deepseek") {
            candidates = ["deepseek-v4-flash", "deepseek-v4-pro"]
        } else if name.contains("ollama") || current.contains("llama") || current.contains("qwen") {
            candidates = ["llama3.1", "qwen2.5", "deepseek-r1:7b", "mistral"]
        } else if name.contains("claude") || current.contains("claude") {
            candidates = ["claude-sonnet-4-5", "claude-opus-4-1", "claude-haiku-4-5"]
        } else if name.contains("kimi") || name.contains("moonshot") || current.contains("moonshot") {
            candidates = ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"]
        } else if name.contains("glm") || name.contains("智谱") || current.contains("glm") {
            candidates = ["glm-4-plus", "glm-4-flash", "glm-4-air"]
        } else {
            candidates = ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "o3-mini"]
        }
        if !current.isEmpty && !candidates.contains(current) {
            candidates.append(current)
        }
        return candidates
    }
}

/// Max 档位提示音。将 `filePath` 改成你自己的 MP3 绝对路径。
enum MaxTierSound {
    /// 已裁切到 7s 的档位提示音 (原 max.mp3 保留未动)。
    static let filePath = "/Users/bobo/Documents/ChatGPT/client/Sources/GlassChat/max_7s.mp3"
    private static var sound: NSSound?
    private static var stopTimer: Timer?

    static func play() {
        // 正在播放时不重复播放, 也不打断 (播放完毕前再次切换不会触发新播放)
        if let s = sound, s.isPlaying { return }
        guard FileManager.default.fileExists(atPath: filePath) else {
            NSSound.beep()
            return
        }
        let s = NSSound(contentsOfFile: filePath, byReference: true)
        s?.volume = 0.1   // 音量 10%
        sound = s
        s?.play()
        // 安全兜底: 7 秒后停止 (文件本身已裁到 7s)
        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { _ in
            sound?.stop()
        }
    }
}

/// 简单自动换行布局: 档位胶囊过多时换到下一行, 不溢出面板宽度。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width
            maxX = max(maxX, x)
            rowHeight = max(rowHeight, size.height)
            x += spacing
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - RGB 灯条式流动彩虹填充

/// 客户端 max/ultra 的蓝紫灯条 + 彩虹主题共用的流动渐变。
/// 连续 hue 循环无缝; 速度 / 方向 / 饱和度 / 亮度由 Theme 彩虹状态驱动。
private struct RainbowFill: View {
    /// 速度倍率 (max / ultra 用不同速度)
    var speed: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let direction = Theme.rainbowReversed ? -1.0 : 1.0
            let phase = t * (Theme.rainbowSpeed / 50.0) * speed * direction
            let stops: [Gradient.Stop] = (0..<24).map { i in
                let raw = Double(i) / 24.0 + phase
                let hue = raw - floor(raw)
                return .init(color: Color(hue: hue,
                                         saturation: Theme.rainbowSaturation,
                                         brightness: Theme.rainbowBrightness),
                             location: Double(i) / 23.0)
            }
            LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - 主题 fade 填充 (对应 ClientThemesUtils.mixColors 的流动渐变)

/// 客户端「fade」= 首色 ↔ 次色之间随时间流动的**条状渐变** (与彩虹同类型)。
/// 每段水平位置带一个相位偏移 (对应 mixColors 的 offset*0.55),
/// 让首/次色在轨道上形成平滑的波浪色带并随 Fade 速度流动。
private struct ThemeFadeFill: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let timer = t * (Theme.fadeSpeed / 5.0) * 4.0
            let stops: [Gradient.Stop] = (0..<24).map { i in
                let percent = (sin(timer + Double(i) * 0.18) + 1.0) * 0.5
                // color = first * percent + second * (1 - percent)
                let color = Theme.mix(Theme.fadeSecond, Theme.fadeFirst, percent)
                return .init(color: color, location: Double(i) / 23.0)
            }
            LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - 切换到 max/ultra 的粒子爆发过渡

/// 进入 max/ultra 档时的一次性粒子爆发: 从中心向四周喷出小圆点并淡出。
private struct ParticleBurst: View {
    /// 当前是否处于 max/ultra (切换瞬间触发爆发)
    let isActive: Bool
    let tint: Color

    @Local private var burst: Burst?

    private struct Particle {
        let angle: Double
        let speed: Double
        let size: Double
        let fade: Double
    }

    private struct Burst {
        let startTime: TimeInterval
        let particles: [Particle]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                guard let burst, now - burst.startTime < 0.85 else { return }
                let t = now - burst.startTime
                let progress = t / 0.85
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for p in burst.particles {
                    let dist = p.speed * t * size.width
                    let pos = CGPoint(x: center.x + cos(p.angle) * dist,
                                      y: center.y + sin(p.angle) * dist * 0.5)
                    let alpha = max(0, 1.0 - progress) * p.fade
                    let radius = p.size * (1.0 - progress * 0.6)
                    let rect = CGRect(x: pos.x - radius, y: pos.y - radius,
                                      width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(tint.opacity(alpha)))
                }
            }
        }
        .onAppear { if isActive { trigger() } }
        .onChange(of: isActive) { _, active in
            if active { trigger() }
        }
        .allowsHitTesting(false)
    }

    private func trigger() {
        var particles: [Particle] = []
        for _ in 0..<40 {
            particles.append(Particle(
                angle: Double.random(in: 0..<(2 * .pi)),
                speed: Double.random(in: 0.10...0.38),
                size: Double.random(in: 2.5...6.0),
                fade: Double.random(in: 0.5...1.0)
            ))
        }
        burst = Burst(startTime: Date().timeIntervalSinceReferenceDate, particles: particles)
    }
}

// MARK: - ChatGPT 客户端式扁平滑块 (仅 GPT 系列)

/// 直接从 ChatGPT 桌面端抄来的推理强度滑块:
/// 24pt 全圆角胶囊轨道 (文字色 10% + 发丝描边), 4pt 刻度圆点,
/// 28pt 白色圆形拇指 (0.5pt 描边 + 微弱阴影), 点击/拖拽吸附最近档位。
/// 拖拽或到达「最大」时, 轨道填充蓝→紫渐变 (对应客户端 _Fill/_Mask 层)。
/// 1:1 复刻: 刻度只显示滑块可见档位 (enabled-reasoning-efforts ∩ 模型支持),
/// 隐藏档位 (无/极小/最大) 只能通过选项胶囊切换, 拇指吸附到最近可见档位。
private struct ChatGPTEffortSlider: View {
    /// 模型全部档位 (含隐藏档位, 用于映射与标题)
    let levels: [IntensityLevel]
    /// 滑块可见档位 (客户端默认启用: 低/中/高/超高)
    let sliderLevels: [IntensityLevel]
    @Binding var effort: String
    @Local private var isDragging = false
    @Local private var isHovered = false

    private var sliderCount: Int { max(sliderLevels.count, 1) }

    /// 拇指位置: 可见档位直接命中; 隐藏档位 (无/极小/最大) 吸附到最近可见档位
    private var displayIndex: Int {
        if let i = sliderLevels.firstIndex(where: { $0.effort == effort }) {
            return i
        }
        let fullIdx = levels.firstIndex(where: { $0.effort == effort }) ?? 0
        let nearest = sliderLevels.indices.min { a, b in
            let ia = levels.firstIndex(where: { $0.effort == sliderLevels[a].effort }) ?? 0
            let ib = levels.firstIndex(where: { $0.effort == sliderLevels[b].effort }) ?? 0
            return abs(ia - fullIdx) < abs(ib - fullIdx)
        }
        return nearest ?? sliderLevels.count - 1
    }

    /// 拇指半径: 刻度范围两端各让出半个拇指, 拇指中心正好落在首尾档位
    private var inset: CGFloat { 14 }
    /// 已选「最大」隐藏档位 (蓝紫填充常驻, data-max)
    private var isMax: Bool { effort == "max" }
    /// Sol 专属隐藏顶档，选中时显示在滑块末端。
    private var isUltra: Bool { effort == "ultra" }
    /// 彩虹速度倍率: ultra > max > 彩虹主题
    private var rainbowSpeedMultiplier: Double {
        if isUltra { return 10.0 }
        if isMax { return 6.0 }
        return 1.0
    }
    /// 拇指悬停/拖拽放大 (客户端 $e = 32/28)
    private var thumbScale: CGFloat { isHovered || isDragging ? 32.0 / 28.0 : 1.0 }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = max(width - inset * 2, 1)
            let y: CGFloat = geo.size.height / 2
            let thumbX = xPosition(for: displayIndex, usable: usable)

            ZStack(alignment: .leading) {
                // 轨道: 24pt 全圆角胶囊, 文字色 10% + 发丝描边
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                    .frame(height: 24)

                // 主题色填充 (非 max): 呼吸 fade (起始色 ↔ 结束色 正弦呼吸), 不透明
                if !isMax && !isUltra && !Theme.rainbowThemeActive {
                    ThemeFadeFill()
                        .frame(width: thumbX, height: 24)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 12, bottomLeadingRadius: 12,
                            bottomTrailingRadius: 0, topTrailingRadius: 0))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // max (或彩虹主题): RGB 灯条式流动渐变 (hue 循环无缝), 切换即直接全显
                if isMax || isUltra || Theme.rainbowThemeActive {
                    RainbowFill(speed: rainbowSpeedMultiplier)
                        .frame(width: thumbX, height: 24)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 12, bottomLeadingRadius: 12,
                            bottomTrailingRadius: 0, topTrailingRadius: 0))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // 刻度圆点: 4pt, 选中更亮
                ForEach(Array(sliderLevels.enumerated()), id: \.element.id) { i, _ in
                    Circle()
                        .fill(i == displayIndex
                              ? Color.primary.opacity(0.65)
                              : Color.secondary.opacity(0.42))
                        .frame(width: 4, height: 4)
                        .position(x: xPosition(for: i, usable: usable), y: y)
                }

                // 白色圆形拇指
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                    .frame(width: 28 * thumbScale, height: 28 * thumbScale)
                    .position(x: thumbX, y: y)
            }
            .animation(.easeInOut(duration: 0.4),
                       value: isMax || isUltra || Theme.rainbowThemeActive)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let t = (value.location.x - inset) / usable
                        let idx = Int((t * CGFloat(sliderCount - 1)).rounded())
                        setIndex(idx)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            // 端点标签: 拖拽时显示 Faster / Smarter (客户端 _SliderEndpoints 32pt 顶部条带)
            .overlay(alignment: .top) {
                if isDragging {
                    HStack {
                        Text("Faster")
                        Spacer()
                        Text("Smarter")
                    }
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .allowsHitTesting(false)
                }
            }
            .overlay {
                ParticleBurst(isActive: isMax, tint: Theme.Palette.accent)
                    .frame(width: width, height: 56)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 32)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: displayIndex)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: thumbScale)
    }

    private func xPosition(for i: Int, usable: CGFloat) -> CGFloat {
        guard sliderCount > 1 else { return inset + usable / 2 }
        return inset + usable * CGFloat(i) / CGFloat(sliderCount - 1)
    }

    private func setIndex(_ i: Int) {
        guard sliderLevels.indices.contains(i) else { return }
        effort = sliderLevels[i].effort
    }
}

// MARK: - ChatGPT 客户端 Power 滑块 (sol/terra 专属, 组合可切换模型)

/// 1:1 复刻客户端 Power 滑块 (l2s/d2s 组合):
/// 每个刻度是一个 (模型+推理强度) 组合, 选择即切换模型与强度;
/// 隐藏档 (ultra) 只能通过选项胶囊切换, 选中时拇指到末端 + 蓝紫填充。
private struct PowerSlider: View {
    let bundles: [PowerBundle]
    let currentModel: String
    @Binding var effort: String
    let onSelect: (PowerBundle) -> Void
    @Local private var isDragging = false
    @Local private var isHovered = false

    private var count: Int { max(bundles.count, 1) }
    /// 拇指半径: 刻度范围两端各让出半个拇指
    private var inset: CGFloat { 14 }
    /// 隐藏顶档 (ultra/max) 选中 → 蓝紫填充常驻 (客户端 data-max)
    private var isMaxTier: Bool { effort == "max" || effort == "ultra" }
    /// Sol 专属隐藏顶档。
    private var isUltra: Bool { effort == "ultra" }
    /// 彩虹速度倍率: ultra > max > 彩虹主题
    private var rainbowSpeedMultiplier: Double {
        if isUltra { return 10.0 }
        if effort == "max" { return 6.0 }
        return 1.0
    }
    /// 拇指悬停/拖拽放大 (客户端 $e = 32/28)
    private var thumbScale: CGFloat { isHovered || isDragging ? 32.0 / 28.0 : 1.0 }

    /// 拇指位置: 命中 (当前模型+强度) 的组合; 隐藏档 (ultra) → 末端; 其余 → 最近
    private var displayIndex: Int {
        if let i = bundles.firstIndex(where: { $0.model == currentModel && $0.effort == effort }) {
            return i
        }
        if isMaxTier { return bundles.count - 1 }
        if let i = bundles.firstIndex(where: { $0.effort == effort }) { return i }
        if let i = bundles.firstIndex(where: { $0.effort == "medium" }) { return i }
        return bundles.count - 1
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = max(width - inset * 2, 1)
            let y: CGFloat = geo.size.height / 2
            let thumbX = xPosition(for: displayIndex, usable: usable)

            ZStack(alignment: .leading) {
                // 轨道: 24pt 全圆角胶囊, 文字色 10% + 发丝描边
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                    .frame(height: 24)

                // 主题色填充 (非 max/ultra): 呼吸 fade (起始色 ↔ 结束色 正弦呼吸), 不透明
                if !isMaxTier && !Theme.rainbowThemeActive {
                    ThemeFadeFill()
                        .frame(width: thumbX, height: 24)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 12, bottomLeadingRadius: 12,
                            bottomTrailingRadius: 0, topTrailingRadius: 0))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // max/ultra (或彩虹主题): RGB 灯条式流动渐变 (hue 循环无缝), 切换即直接全显
                if isMaxTier || Theme.rainbowThemeActive {
                    RainbowFill(speed: rainbowSpeedMultiplier)
                        .frame(width: thumbX, height: 24)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 12, bottomLeadingRadius: 12,
                            bottomTrailingRadius: 0, topTrailingRadius: 0))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // 刻度圆点: 4pt, 选中更亮
                ForEach(Array(bundles.enumerated()), id: \.element.id) { i, _ in
                    Circle()
                        .fill(i == displayIndex
                              ? Color.primary.opacity(0.65)
                              : Color.secondary.opacity(0.42))
                        .frame(width: 4, height: 4)
                        .position(x: xPosition(for: i, usable: usable), y: y)
                }

                // 白色圆形拇指
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                    .frame(width: 28 * thumbScale, height: 28 * thumbScale)
                    .position(x: thumbX, y: y)
            }
            .animation(.easeInOut(duration: 0.4),
                       value: isMaxTier || Theme.rainbowThemeActive)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let t = (value.location.x - inset) / usable
                        let idx = Int((t * CGFloat(count - 1)).rounded())
                        selectIndex(idx)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            // 端点标签: 拖拽时显示 Faster / Smarter (客户端 _SliderEndpoints)
            .overlay(alignment: .top) {
                if isDragging {
                    HStack {
                        Text("Faster")
                        Spacer()
                        Text("Smarter")
                    }
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .allowsHitTesting(false)
                }
            }
            .overlay {
                ParticleBurst(isActive: isMaxTier, tint: Theme.Palette.accent)
                    .frame(width: width, height: 56)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 32)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: displayIndex)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: thumbScale)
    }

    private func xPosition(for i: Int, usable: CGFloat) -> CGFloat {
        guard count > 1 else { return inset + usable / 2 }
        return inset + usable * CGFloat(i) / CGFloat(count - 1)
    }

    private func selectIndex(_ i: Int) {
        guard bundles.indices.contains(i) else { return }
        onSelect(bundles[i])
    }
}
