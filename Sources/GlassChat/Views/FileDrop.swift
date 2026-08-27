import SwiftUI
import UniformTypeIdentifiers

// MARK: - 拖拽文件进窗口 (未松手时反馈 + 松手落点)

/// 把访达等外部来源的文件拖进窗口时的落点代理。
///
/// - 未松手时: `dropEntered` / `dropUpdated` 持续上报拖拽状态与鼠标位置,
///   驱动聊天区模糊、「松手发送」提示与鼠标下方的主题色渐变阴影。
/// - 松手时: `performDrop` 把文件读入待发送附件 (与「+」菜单选择文件一致)。
struct FileDropDelegate: DropDelegate {
    let app: AppState

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        app.isFileDragging = true
        app.dragLocation = info.location
    }

    func dropUpdated(info: DropInfo) {
        app.dragLocation = info.location
    }

    func dropExited(info: DropInfo) {
        app.isFileDragging = false
        app.dragLocation = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        app.isFileDragging = false
        app.dragLocation = nil
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let url else { return }
            Task { @MainActor in
                self.app.addPendingAttachments([url])
            }
        }
        return true
    }
}

// MARK: - 拖拽覆盖层

/// 拖拽文件进窗口时的覆盖层 (仅在未松手时显示):
/// 居中「松手发送」提示 + 鼠标下方 (拖拽文件正下方) 的主题色渐变阴影。
struct FileDropOverlay: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            if app.isFileDragging {
                dropHint
                dropShadow
            }
        }
        .allowsHitTesting(false)
        .animation(Theme.Motion.fade, value: app.isFileDragging)
    }

    /// 居中提示: 向下箭头 + 「松手发送」
    private var dropHint: some View {
        VStack(spacing: 7) {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.fadeFirst)
            Text("松手发送")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
        .glassTile()
        .shadow(color: Theme.Palette.glassShadow, radius: 12, y: 5)
    }

    /// 鼠标下方 (拖拽文件正下方) 的主题色渐变阴影, 随鼠标移动。
    private var dropShadow: some View {
        GeometryReader { _ in
            if let loc = app.dragLocation {
                Ellipse()
                    .fill(LinearGradient(
                        colors: [
                            Theme.fadeFirst.opacity(0.80),
                            Theme.fadeSecond.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 158, height: 60)
                    .blur(radius: 15)
                    .position(x: loc.x, y: loc.y + 42)
                    .transition(.opacity)
            }
        }
    }
}
