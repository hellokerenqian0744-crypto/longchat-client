import SwiftUI
import AppKit

/// JBChat — 遵循 Apple HIG 的液态玻璃多模型 AI 客户端。
///
/// 窗口结构采用 macOS 标准样式: 标准标题栏 + Unified 工具栏。
/// 红绿灯由系统置于标准位置, 工具栏项由系统与红绿灯自动对齐,
/// 内容区由系统管理, 不做任何安全区 hack。
@main
struct JBChatApp: App {
    @StateObject private var app = AppState()
    @Environment(\.openWindow) private var openWindow

    init() {
        // 调试: 管道下 print 默认块缓冲, 关闭缓冲以便观察日志
        setvbuf(stdout, nil, _IONBF, 0)
    }

    var body: some Scene {
        WindowGroup(id: "authorization") {
            AuthorizationView()
                .environmentObject(app)
                .environment(\.liveAccent, Theme.fadeFirst)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 360, height: 310)

        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(app)
                .environment(\.liveAccent, Theme.fadeFirst)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: Theme.Layout.windowDefaultSize.width,
                     height: Theme.Layout.windowDefaultSize.height)

        WindowGroup(id: "about") {
            AboutLongChatView()
                .environmentObject(app)
                .environment(\.liveAccent, Theme.fadeFirst)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 380, height: 330)
        // 标准设置窗口 (⌘,): 独立窗口 + 系统设置式侧边栏, 符合 Apple HIG
        Settings {
            ProviderSettingsView()
                .environmentObject(app)
                .environment(\.liveAccent, Theme.fadeFirst)
        }
        .defaultSize(width: 560, height: 500)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 JBChat") {
                    openWindow(id: "about")
                }
            }
            // View 菜单的「显示/隐藏侧边栏」+ ⌘⌥S (照片应用式标准位置)
            CommandGroup(replacing: .sidebar) {
                Button(app.sidebarVisible ? "隐藏侧边栏" : "显示侧边栏") {
                    withAnimation(Theme.Motion.spring) {
                        app.sidebarVisible.toggle()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }

            // 去掉 NavigationSplitView 自动塞进 Help 菜单的冗余 'Toggle Sidebar'
            CommandGroup(replacing: .help) {}

            CommandGroup(replacing: .newItem) {
                Button("新建对话") {
                    app.newConversation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

}
