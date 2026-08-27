import SwiftUI

/// 主聊天区: 消息流 + 底部输入框。ChatGPT 式通透留白 + 居中 768pt 内容列。
struct ChatView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            messageArea
                .padding(.horizontal, 24)
                .padding(.top, Theme.Layout.topBarInset)
            // 首页 (无对话) 不显示输入框
            if hasConversation {
                ComposerView()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 11)
                    .padding(.bottom, 11)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.chatBackground)
    }

    /// 是否有活动会话 (新建对话即进入聊天界面; 真正无会话时才显示首页)
    private var hasConversation: Bool {
        app.activeConversation != nil
    }

    // MARK: - 消息区

    @ViewBuilder
    private var messageArea: some View {
        if let conversation = app.activeConversation {
            if conversation.messages.isEmpty {
                // 空会话: 留白, 等待输入 (输入框已显示)
                Color.clear
            } else {
                MessageList(conversation: conversation)
            }
        } else {
            WelcomeView()
        }
    }
}

// MARK: - 消息流

private struct MessageList: View {
    @EnvironmentObject private var app: AppState

    let conversation: Conversation

    /// 锚点: 新消息与流式增量都会滚动到这里
    private let bottomAnchorID = "bottom-anchor"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Layout.messageSpacing) {
                    ForEach(conversation.messages) { message in
                        MessageRow(
                            message: message,
                            providerTint: app.activeProvider?.tint ?? Theme.Palette.accent,
                            isLastAssistant: message.id == lastAssistantMessageID,
                            canRegenerate: !app.isStreaming,
                            onRegenerate: app.regenerate
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .frame(maxWidth: Theme.Layout.chatMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            // 流式增量到达时保持贴底
            .onChange(of: conversation.messages.last?.content) {
                scrollToBottom(proxy)
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
            .onChange(of: conversation.id) {
                scrollToBottom(proxy, animated: false)
            }
        }
    }

    private var lastAssistantMessageID: UUID? {
        conversation.messages.last(where: { $0.role == .assistant && !$0.isError })?.id
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(Theme.Motion.quickSpring) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }
}

// MARK: - 欢迎页

/// 空会话时的引导页: 玻璃标识 + 大标题 + 液态玻璃建议卡片 (ChatGPT 首屏式)。
private struct WelcomeView: View {
    @EnvironmentObject private var app: AppState


    private let suggestions: [(icon: String, tint: Color, title: String, prompt: String)] = [
        ("lightbulb.max.fill", .blue, "给我一些灵感", "给我 5 个有趣的周末活动创意"),
        ("pencil.line", .purple, "帮我写点东西", "帮我写一封礼貌的会议延期邮件"),
        ("chevron.left.forwardslash.chevron.right", .green, "解释一段代码", "用简单的话解释什么是闭包"),
        ("globe.asia.australia", .orange, "翻译与总结", "把一段话总结成 3 个要点"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // AI 状态卡 (英雄位)
                AIStatusWidget()

                // 桌面式小组件: 时钟 + 天气
                HStack(alignment: .top, spacing: 18) {
                    ClockWidget()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    WeatherWidget()
                        .frame(maxWidth: .infinity)
                }

                // 日历 + 每日一言
                HStack(alignment: .top, spacing: 18) {
                    CalendarWidget()
                        .frame(maxWidth: .infinity)
                    QuoteWidget()
                        .frame(maxWidth: .infinity)
                }

                // AI 能力胶囊
                AICapabilitiesWidget()

                // 聊天快捷建议
                suggestionGrid
            }
            .padding(28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private var suggestionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 12)],
                  spacing: 12) {
            ForEach(suggestions, id: \.title) { item in
                Button {
                    app.send(item.prompt)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(item.tint)
                        Text(item.title)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(item.prompt)
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassTile()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 720)
    }
}
