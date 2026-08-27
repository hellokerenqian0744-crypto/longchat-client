import SwiftUI
import AppKit

// MARK: - 消息行

/// 单条消息的布局 (ChatGPT 桌面端式):
/// 用户消息右对齐浅灰气泡, 助手消息左对齐无气泡纯文本,
/// 代码块与元信息保留玻璃质感。
struct MessageRow: View {
    @EnvironmentObject private var app: AppState
    @State private var isHovered = false


    let message: ChatMessage
    let providerTint: Color
    let isLastAssistant: Bool
    let canRegenerate: Bool
    let onRegenerate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user { Spacer(minLength: 120) }

            if message.role == .assistant {
                assistantMark
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                bubble
                metadata
                    .opacity(isHovered ? 1 : 0)
                    .frame(height: 12, alignment: message.role == .user ? .trailing : .leading)
            }
            .frame(maxWidth: message.role == .user ? 560 : 620,
                   alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer(minLength: 34) }
        }
        .frame(maxWidth: .infinity)
        .onHover { isHovered = $0 }
    }

    private var assistantMark: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(providerTint)
            .frame(width: 22, height: 22)
            .background(Theme.Palette.hoverFill, in: Circle())
            .overlay {
                Circle().strokeBorder(providerTint.opacity(0.18), lineWidth: 1)
            }
    }

    // MARK: 气泡

    @ViewBuilder
    private var bubble: some View {
        if message.role == .user {
            VStack(alignment: .trailing, spacing: 8) {
                if !message.attachments.isEmpty {
                    userAttachmentStrip
                }
                if !message.content.isEmpty {
                    MarkdownText(text: message.content,
                                 fillsWidth: false,
                                 textColor: Theme.contrastingTextColor(for: .white))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.white,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.bubble, style: .continuous))
            .overlay {
                FlowingBorder(shape: RoundedRectangle(cornerRadius: Theme.Radius.bubble, style: .continuous),
                              lineWidth: 1)
            }
            .shadow(color: Theme.Palette.glassShadow, radius: 6, y: 2)
            .contextMenu {
                Button {
                    copyToPasteboard(message.content)
                } label: {
                    Label("复制内容", systemImage: "doc.on.doc")
                }
            }
        } else {
            Group {
                if message.isError {
                    Label {
                        MarkdownText(text: message.content)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Palette.danger)
                    }
                } else if app.isThinking && isLastAssistant && message.content.isEmpty {
                    ThinkingDots()
                        .frame(minHeight: 22, alignment: .leading)
                } else if isStreamingMessage {
                    streamingReply
                } else {
                    MarkdownText(text: message.content)
                }
            }
            .frame(minHeight: 22, alignment: .topLeading)
            .padding(.top, app.isThinking && message.content.isEmpty ? 0 : 2)
            // 流式结束切换为最终 Markdown 时平滑过渡, 避免换行突兀出现
            .animation(.easeInOut(duration: 0.35), value: isStreamingMessage)
            .contextMenu {
                Button {
                    copyToPasteboard(message.content)
                } label: {
                    Label("复制内容", systemImage: "doc.on.doc")
                }
                if isLastAssistant && canRegenerate {
                    Button(action: onRegenerate) {
                        Label("重新生成", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    /// 用户气泡内的附件展示: 图片显示缩略图, 其余显示图标 + 文件名。
    private var userAttachmentStrip: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(message.attachments) { att in
                HStack(spacing: 7) {
                    if att.kind == .image, let image = NSImage(data: att.data) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else {
                        Image(systemName: att.kind.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 34, height: 34)
                            .background(
                                Color.black.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(att.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(att.sizeDisplay)
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                }
                .padding(6)
                .background(
                    Color.black.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
            }
        }
    }

    /// 该消息是否为正在流式生成的最后一条助手消息
    private var isStreamingMessage: Bool {
        app.isStreaming && isLastAssistant && !message.isError
    }

    /// Apple Music 歌词式逐行淡入的流式回复
    private var streamingReply: some View {
        let segments = Markdown.segments(from: message.content)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    streamingText(content)
                case .code(let language, let source):
                    CodeBlockView(language: language, source: source)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: segments.count)
    }

    /// 文本段按行逐行淡入 (Apple Music 歌词式)
    private func streamingText(_ content: String) -> some View {
        let lines = content.split(separator: "\n").map(String.init)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                MarkdownText(text: line.isEmpty ? " " : line, fillsWidth: false)
                    .transition(.opacity
                        .combined(with: .scale(scale: 0.97))
                        .combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.3), value: lines.count)
    }

    /// 当前气泡样式
    private var bubbleStyle: BubbleStyle {
        BubbleStyle(rawValue: app.bubbleStyle) ?? .themeGradient
    }

    /// 用于文字反色的基准色
    private var bubbleBaseColor: Color {
        switch bubbleStyle {
        case .themeGradient, .solid: return Theme.fadeFirst
        case .brightGradient: return brightGradientBase
        }
    }

    /// 亮色渐变所基于的颜色 (反色关 = 首色, 反色开 = 次色)
    private var brightGradientBase: Color {
        Theme.fadeReversed ? Theme.fadeEnd : Theme.fadeStart
    }

    /// 用户气泡背景: 静态 (跟随全局强调色, 但不呼吸 fade)
    private var bubbleFill: AnyShapeStyle {
        switch bubbleStyle {
        case .themeGradient:
            return AnyShapeStyle(LinearGradient(
                colors: [Theme.fadeFirst, Theme.fadeSecond],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .brightGradient:
            let bright = Theme.mix(brightGradientBase, .white, 0.30)
            return AnyShapeStyle(LinearGradient(
                colors: [bright, brightGradientBase],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .solid:
            return AnyShapeStyle(Theme.fadeFirst)
        }
    }

    // MARK: 元信息

    @ViewBuilder
    private var metadata: some View {
        HStack(spacing: 6) {
            Text(message.date.formatted(date: .omitted, time: .shortened))
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, message.role == .user ? 8 : 0)
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

// MARK: - Markdown 渲染

/// 把 Markdown 分段渲染: 富文本段 + 代码块。
struct MarkdownText: View {
    let text: String
    /// 文本段是否占满整行宽度 (气泡内为 false, 让气泡贴合内容)
    var fillsWidth: Bool = true
    /// 文本颜色 (默认跟随环境; 用户气泡内为对比色)
    var textColor: Color = .primary

    var body: some View {
        let segments = Markdown.segments(from: text)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    Text(attributed(content))
                        .foregroundStyle(textColor)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
                case .code(let language, let source):
                    CodeBlockView(language: language, source: source)
                }
            }
        }
    }

    /// 内联 Markdown (粗体/斜体/行内代码/链接)
    private func attributed(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let parsed = try? AttributedString(markdown: source, options: options) {
            return parsed
        }
        return AttributedString(source)
    }
}

// MARK: - 代码块

/// 围栏代码块: 深色玻璃卡片 + 语言标签 + 复制按钮。
struct CodeBlockView: View {
    let language: String?
    let source: String

    @Local private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(source)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color(red: 0.10, green: 0.11, blue: 0.16), in: RoundedRectangle(cornerRadius: Theme.Radius.code, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.code, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack {
            Text(language?.uppercased() ?? "CODE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                copy()
            } label: {
                Label(copied ? "已复制" : "复制",
                      systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(source, forType: .string)
        withAnimation(Theme.Motion.quickSpring) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(Theme.Motion.fade) { copied = false }
        }
    }
}

// MARK: - 思考指示器

/// 流式响应开始前的「思考中」动画: 三个相位错开的玻璃圆点。
struct ThinkingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    let phase = sin(time * 4 + Double(index) * 0.9) * 0.5 + 0.5
                    Circle()
                        // 主题色 fade: 颜色在首色 ↔ 次色之间呼吸, 叠加轻微明暗节奏
                        .fill(Theme.fadeColor(at: time).opacity(0.3 + phase * 0.7))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
