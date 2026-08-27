import SwiftUI

/// 全局强调色「呼吸」值, 通过环境注入。
///
/// 用 TimelineView 以 30fps 计算, 再经 `.environment(\.liveAccent, …)` 下发:
/// 只有读取该环境值的视图会重绘, 其余视图 (如 Markdown 解析) 不受影响,
/// 避免 ObservableObject 的 objectWillChange 导致整棵视图树每帧重算。
private struct LiveAccentKey: EnvironmentKey {
    static let defaultValue: Color = Color(red: 0.063, green: 0.639, blue: 0.498)
}

extension EnvironmentValues {
    /// 全局强调色呼吸值 (fade / 彩虹), 由 ThemePulseProvider 每帧更新。
    var liveAccent: Color {
        get { self[LiveAccentKey.self] }
        set { self[LiveAccentKey.self] = newValue }
    }
}
