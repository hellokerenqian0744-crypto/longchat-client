import SwiftUI
import UniformTypeIdentifiers

/// 根视图: 原生 NavigationSplitView 布局。
///
/// macOS Tahoe 中 NavigationSplitView 的侧边栏列由系统自动渲染为
/// 原生液态玻璃面板(设置/访达同款): 材质、悬浮、圆角、滚动毛边
/// 全部交给系统, 不再手写任何 NSVisualEffectView 背景。
/// 主内容区使用系统窗口背景并居中 768pt 内容列;
/// 标题栏工具项(侧边栏开关/会话标题/设置)由场景 Toolbar 承载,
/// 与系统红绿灯自动对齐在同一水平线上。
struct ContentView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.openSettings) private var openSettings

    /// 把持久化的侧边栏显隐状态桥接到 NavigationSplitView 的列可见性,
    /// 系统会负责折叠/展开动画与工具栏按钮的联动。
    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { app.sidebarVisible ? .all : .detailOnly },
            set: { (value: NavigationSplitViewVisibility, _) in
                app.sidebarVisible = (value != NavigationSplitViewVisibility.detailOnly)
            }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            SidebarView()
        } detail: {
            ChatView()
                // 拖拽文件进窗口 (未松手) 时模糊右侧聊天区
                .blur(radius: app.isFileDragging ? 16 : 0)
                .animation(Theme.Motion.fade, value: app.isFileDragging)
        }
        .overlay {
            FileDropOverlay()
                .environmentObject(app)
        }
        // 拖拽文件进窗口: 未松手时显示模糊/提示/阴影, 松手后写入待发送附件
        .onDrop(of: [UTType.fileURL], delegate: FileDropDelegate(app: app))
        // 原生窗口标题: 跟随当前会话, 无会话时显示 JBChat
        .navigationTitle(app.activeConversation?.title ?? "JBChat")
        // 任何位置请求打开设置时, 路由到标准 Settings 场景
        .onChange(of: app.showProviderSettings) { _, requested in
            guard requested else { return }
            app.showProviderSettings = false
            openSettings()
        }
    }
}
