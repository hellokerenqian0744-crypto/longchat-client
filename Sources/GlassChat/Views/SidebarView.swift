import SwiftUI
import AppKit

/// 左侧原生侧边栏。
///
/// 布局: 标题 + 原生搜索框(NSSearchField, 液态玻璃外观),
/// 下方为两个原生分类:
/// - 类别 1: 新建对话 + 定时任务(空壳占位, 后续实现)
/// - 类别 2: 项目文件夹(空壳占位) + 对话列表
/// 两个类别为原生可折叠分区(带类别标题与折叠箭头, 状态持久化);
/// 底部仅显示当前模型名称(设置入口已移入 ⌘, 设置窗口)。
/// 列表材质由 NavigationSplitView 在 macOS Tahoe 下自动提供原生液态玻璃。
struct SidebarView: View {
    @EnvironmentObject private var app: AppState

    @Local private var query = ""
    /// iOS 式底部搜索: 折叠为圆形图标, 点击展开全宽搜索框
    @Local private var searchExpanded = false
    @FocusState private var searchFocused: Bool

    /// 两个类别的展开状态 (原生可折叠分区, 记忆上次状态)
    @AppStorage("sidebar.section.actions") private var actionsExpanded = true
    @AppStorage("sidebar.section.recents") private var recentsExpanded = true
    @AppStorage("sidebar.section.projects") private var projectsExpanded = true

    /// 空壳占位行的弹层显示状态
    @Local private var showTasksShell = false
    @Local private var showProjectsShell = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            list
            bottomRow
            Divider().padding(.horizontal, 12)
            searchControl
        }
        .frame(maxHeight: .infinity)
        // 系统列宽: 理想 272pt, 允许像访达一样拖拽调整
        .navigationSplitViewColumnWidth(min: 220, ideal: Theme.Layout.sidebarWidth, max: 380)
    }

    // MARK: - 列表 (两个类别)

    private var list: some View {
        List {
            // 类别 1: 新建对话 + 定时任务
            Section(isExpanded: $actionsExpanded) {
                newChatRow
                shellRow("定时任务", systemImage: "clock", isPresented: $showTasksShell)
            } header: {
                Text("快捷操作")
            }

            // 类别 2: 最近 (对话列表)
            Section(isExpanded: $recentsExpanded) {
                if filteredConversations.isEmpty {
                    emptyHint
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                ForEach(filteredConversations) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        isActive: conversation.id == app.activeConversationID
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: -2, bottom: 0, trailing: -2))
                }
            } header: {
                Text("最近")
            }

            // 类别 3: 项目 (待开发)
            Section(isExpanded: $projectsExpanded) {
                shellRow("项目文件夹", systemImage: "folder", isPresented: $showProjectsShell)
            } header: {
                Text("项目")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: 空壳占位行 (可点击, 弹出「即将推出」面板)

    private func shellRow(_ title: String, systemImage: String, isPresented: Binding<Bool>) -> some View {
        Button {
            isPresented.wrappedValue.toggle()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverRowStyle())
        .popover(isPresented: isPresented, arrowEdge: .trailing) {
            ShellPopover(title: title, systemImage: systemImage)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: -2, bottom: 0, trailing: -2))
    }

    // MARK: - 底部搜索 (iOS 式: 圆形图标 ⇄ 全宽搜索框)

    private var searchControl: some View {
        Group {
            if searchExpanded {
                expandedSearchField
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                searchIconButton
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onChange(of: searchFocused) {
            guard !searchFocused, searchExpanded else { return }
            // 失焦后稍作延迟收起, 避免点击内部控件时闪动
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if !searchFocused, searchExpanded {
                    withAnimation(Theme.Motion.spring) {
                        searchExpanded = false
                        query = ""
                    }
                }
            }
        }
    }

    /// 折叠态: 圆形放大镜图标 (侧边栏左下角)
    private var searchIconButton: some View {
        Button {
            withAnimation(Theme.Motion.spring) {
                searchExpanded = true
                searchFocused = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                // 液态玻璃圆形按钮
                .background(Circle().fill(Theme.Palette.cardFill))
                .glassEffect(.regular, in: Circle())
                .overlay(Circle().strokeBorder(Theme.Palette.glassHighlight, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("搜索会话")
    }

    /// 展开态: 侧边栏长度搜索框 (左右带间距)
    private var expandedSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("搜索会话", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onExitCommand {
                    withAnimation(Theme.Motion.spring) {
                        searchExpanded = false
                        query = ""
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.Palette.cardFill)
        )
        // 液态玻璃搜索框
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(searchFocused
                              ? AnyShapeStyle(Theme.Palette.accent.opacity(0.6))
                              : AnyShapeStyle(Theme.Palette.glassHighlight),
                              lineWidth: searchFocused ? 1.5 : 1)
        }
    }

    // MARK: - 新建对话

    private var newChatRow: some View {
        Button {
            app.newConversation()
        } label: {
            Label("新建对话", systemImage: "square.and.pencil")
                .font(.callout)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverRowStyle())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: -2, bottom: 0, trailing: -2))
        .keyboardShortcut("n", modifiers: .command)
    }

    // MARK: - 会话列表

    private var filteredConversations: [Conversation] {
        let sorted = app.sortedConversations
        guard !query.isEmpty else { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Text(query.isEmpty ? "还没有会话" : "没有匹配的会话")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(query.isEmpty ? "点击「新建对话」开始" : " ")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - 底部: 用户名

    private var bottomRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(bottomUserName)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    /// 用户名显示: 设置的用户名 → 电脑用户名 → 占位
    private var bottomUserName: String {
        if !app.username.isEmpty { return app.username }
        let systemUser = NSUserName().trimmingCharacters(in: .whitespaces)
        if !systemUser.isEmpty { return systemUser }
        return "未设置用户名"
    }
}

// MARK: - 悬停行按钮样式

/// 侧边栏通用的「悬停变灰」行样式。
struct HoverRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverRowBody(configuration: configuration)
    }

    /// 真正承载悬停状态的视图 (ButtonStyle 本身不保证 @State 语义)。
    private struct HoverRowBody: View {
        let configuration: Configuration
        @Local private var isHovered = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                        .fill(configuration.isPressed
                              ? Theme.Palette.selectedFill
                              : (isHovered ? Theme.Palette.hoverFill : .clear))
                )
                .onHover { isHovered = $0 }
                .animation(Theme.Motion.fade, value: isHovered)
        }
    }
}

// MARK: - 会话行

private struct ConversationRow: View {
    @EnvironmentObject private var app: AppState

    let conversation: Conversation
    let isActive: Bool

    @Local private var isRenaming = false
    @Local private var draftTitle = ""

    var body: some View {
        Button {
            withAnimation(Theme.Motion.quickSpring) {
                app.selectConversation(conversation.id)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Text(conversation.title)
                    .font(.callout.weight(isActive ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 7)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                        .fill(Theme.Palette.selectedFill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                draftTitle = conversation.title
                isRenaming = true
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            Button(role: .destructive) {
                withAnimation(Theme.Motion.spring) {
                    app.deleteConversation(conversation.id)
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .alert("重命名会话", isPresented: $isRenaming) {
            TextField("标题", text: $draftTitle)
            Button("保存") {
                app.renameConversation(conversation.id, to: draftTitle)
            }
            Button("取消", role: .cancel) {}
        }
    }
}

// MARK: - 空壳占位弹层

/// 「定时任务 / 项目文件夹」等尚未实现功能的占位弹层。
private struct ShellPopover: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("暂无\(title)", systemImage: systemImage)
                .font(.callout.weight(.semibold))
            Text("「\(title)」功能即将推出。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("新建\(title)") {}
                .disabled(true)
        }
        .padding(14)
        .frame(width: 240)
    }
}
