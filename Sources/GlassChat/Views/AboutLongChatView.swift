import SwiftUI

/// 菜单栏 About LongChat 打开的独立关于窗口。
struct AboutLongChatView: View {
    @Environment(\.dismiss) private var dismiss
    private let cornerRadius: CGFloat = 18

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.mix(Theme.fadeFirst, .white, 0.90),
                    Theme.mix(Theme.fadeSecond, .white, 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Theme.fadeFirst)
                    .frame(width: 78, height: 78)
                    .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(spacing: 5) {
                    Text("JBChat")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("液态玻璃 AI API 客户端")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("版本 1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(width: 220)

                VStack(spacing: 8) {
                    Text("规划中功能")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        Label("文件和文件夹", systemImage: "folder")
                        Label("目标", systemImage: "target")
                        Label("计划", systemImage: "checklist")
                        Label("技能", systemImage: "sparkles")
                    }
                    .font(.callout)
                    .foregroundStyle(.primary)
                    Text("以上功能尚未实现, 后续版本陆续推出。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Theme.fadeFirst)
            }
            .padding(34)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            AboutFlowingBorder(cornerRadius: cornerRadius)
                .allowsHitTesting(false)
        }
        .frame(width: 380, height: 470)
    }
}

/// 仅关于窗口使用的双色流动窗沿。
private struct AboutFlowingBorder: View {
    let cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = (time.truncatingRemainder(dividingBy: 6)) / 6
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
                        angle: .degrees(phase * 360)
                    ),
                    lineWidth: 2
                )
                .shadow(color: Theme.fadeFirst.opacity(0.32), radius: 6)
                .padding(1)
        }
    }
}
