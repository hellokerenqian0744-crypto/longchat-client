import SwiftUI
import AppKit

/// 全局设计常量。
///
/// 所有视觉相关的魔法数字都集中在这里, 修改主题时只需要改这一个文件。
/// 设计语言参考 ChatGPT 桌面端: 居中 768pt 内容列、浅灰底、圆角输入卡、
/// 暗色圆形发送键、左对齐助手消息与右对齐用户气泡;
/// 材质统一采用 macOS Tahoe 的 Liquid Glass(液态玻璃)质感,
/// 让极光背景透过玻璃面板流动。
enum Theme {

    // MARK: - 全局强调色 (设置 > 个性化 可自定义)

    /// 默认强调色: ChatGPT 品牌绿
    static let defaultAccentHex = "#10A37F"
    /// 由 AppState 在启动/变更时写入; 所有使用 Theme.Palette.accent 的位置实时生效
    static var accentOverride: Color?

    // MARK: - 彩虹主题状态 (设置 > 外观 > 主题)

    /// 当前是否为动态彩虹主题 (rainbow / astolfo)
    static var rainbowThemeActive = false
    /// 彩虹动画速度 (对应 ClientThemesUtils.ThemeFadeSpeed, 1...10, 默认 7)
    static var rainbowSpeed: Double = 7
    /// 彩虹流动方向是否反转 (对应 ClientThemesUtils.updown)
    static var rainbowReversed = false
    /// 彩虹饱和度
    static var rainbowSaturation: Double = 0.7
    /// 彩虹亮度
    static var rainbowBrightness: Double = 1.0
    /// 主题彩虹饱和度 (rainbow=1.0 / astolfo=0.6, 对应 skyRainbow 的 st)
    static var themeRainbowSaturation: Double = 1.0
    /// 主题彩虹亮度 (两者均为 1.0, 对应 skyRainbow 的 bright)
    static var themeRainbowBrightness: Double = 1.0

    // MARK: - Fade 呼吸状态 (对应 ClientThemesUtils.mixColors)

    /// fade 起点色 (命名主题的起始色; 自定义色 = 强调色最亮)
    static var fadeStart: Color = Color(red: 0.063, green: 0.639, blue: 0.498)
    /// fade 终点色 (命名主题的结束色; 自定义色 = 强调色压暗)
    static var fadeEnd: Color = Color(red: 0.02, green: 0.21, blue: 0.16)
    /// fade 呼吸速度 (对应 ClientThemesUtils.ThemeFadeSpeed, 1...10, 默认 7)
    static var fadeSpeed: Double = 7
    /// fade 方向 (对应 ClientThemesUtils.updown)
    static var fadeReversed = false
    /// 是否启用全局 fade 呼吸 (关闭时全局为单一静态色 = 主题首色, 消除逐帧刷新卡顿)
    static var fadeEnabled = true

    /// 首色 (反转方向时与次色互换, 实现「1→2 变成 2→1」)
    static var fadeFirst: Color { fadeReversed ? fadeEnd : fadeStart }
    /// 次色
    static var fadeSecond: Color { fadeReversed ? fadeStart : fadeEnd }

    /// 计算某时刻的全局强调色呼吸值。
    /// fade 主题在 fadeStart ↔ fadeEnd 之间正弦呼吸 (对应 ColorUtils.mixColors);
    /// 彩虹主题则按 hue 循环。
    static func breathingAccent(at t: TimeInterval) -> Color {
        if !fadeEnabled {
            return fadeFirst
        }
        if rainbowThemeActive {
            // 复刻 ColorUtils.skyRainbow: v1 = ceil(now_ms / 5); hue = (v1 % 360) / 360
            let nowMs = t * 1000.0
            let v1 = (nowMs / 5.0).rounded(.up)
            let hue = v1.truncatingRemainder(dividingBy: 360.0) / 360.0
            return Color(hue: hue,
                         saturation: themeRainbowSaturation,
                         brightness: themeRainbowBrightness)
        }
        return fadeColor(at: t)
    }

    /// 始终 fade 的呼吸色 (供推理强度滑块使用, 不受全局 Fade 开关影响)。
    static func fadeColor(at t: TimeInterval) -> Color {
        // 对应 ColorUtils.mixColors 的呼吸公式: percent = (sin(timer) + 1) / 2
        let ms = fadeSpeed / 5.0
        let percent = (sin(t * ms * 4.0) + 1.0) * 0.5
        // color = first * percent + second * (1 - percent)
        return mix(fadeSecond, fadeFirst, percent)
    }

    // MARK: 布局

    enum Layout {
        static let sidebarWidth: CGFloat = 272
        static let windowMinSize = CGSize(width: 900, height: 600)
        static let windowDefaultSize = CGSize(width: 1180, height: 760)
        /// ChatGPT 桌面端的内容列宽度
        static let chatMaxWidth: CGFloat = 768
        /// 聊天内容区顶部留白
        static let topBarInset: CGFloat = 24
        /// 侧边栏顶部留白
        static let sidebarTopInset: CGFloat = 14
        static let messageSpacing: CGFloat = 18
    }

    // MARK: 圆角

    enum Radius {
        static let panel: CGFloat = 26
        static let bubble: CGFloat = 20
        static let composer: CGFloat = 24
        static let card: CGFloat = 14
        static let code: CGFloat = 12
        static let row: CGFloat = 10
        static let chip: CGFloat = 10
        /// 欢迎页建议卡片
        static let tile: CGFloat = 18
    }

    // MARK: 动画

    enum Motion {
        /// Liquid Glass 风格的弹性动画
        static let spring = Animation.spring(response: 0.36, dampingFraction: 0.82)
        static let quickSpring = Animation.spring(response: 0.24, dampingFraction: 0.86)
        static let fade = Animation.easeInOut(duration: 0.22)
    }

    // MARK: 颜色

    enum Palette {
        /// 全局强调色 (按钮高亮 / 输入框高亮边框 / 品牌元素)
        static var accent: Color {
            Theme.accentOverride ?? Color(red: 0.063, green: 0.639, blue: 0.498)
        }
        /// 主题色最亮变体 (滑块划过填充: 主题色提亮后向拇指处 fade)
        static var accentBright: Color { mix(accent, .white, 0.30) }
        /// 主题色变暗变体 (填充 fade 终点: 最亮 → 深色主题色, 非纯黑)
        static var accentDim: Color { mix(accent, .black, 0.45) }
        /// 主题色极暗变体 (fade 终点: 保留色相的深色, 非纯黑)
        static var accentDeepDark: Color { mix(accent, .black, 0.82) }
        /// 主题色最高饱和度变体 (fade 起点)
        static var accentMaxSat: Color {
            let ns = NSColor(accent).usingColorSpace(.sRGB) ?? NSColor(accent)
            return Color(hue: ns.hueComponent,
                         saturation: 1.0,
                         brightness: max(ns.brightnessComponent, 0.65))
        }
        /// fade 终点: 最高饱和度主题色混入大量黑 (低饱和度暗色)
        static var accentFadeEnd: Color { mix(accentMaxSat, .black, 0.85) }
        /// fade 暗端: 最高饱和度主题色压暗 (非纯黑, 低饱和)
        static var accentFadeLow: Color { mix(accentMaxSat, .black, 0.70) }
        static let danger = Color(red: 0.86, green: 0.29, blue: 0.25)
        /// 成功/选中态跟随全局强调色
        static var success: Color { accent }
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary

        /// 原生窗口背景 (系统 windowBackgroundColor, 跟随明暗模式)
        static let chatBackground = Color(nsColor: .windowBackgroundColor)
        /// 用户消息气泡: 浅色浅灰, 深色中灰
        static let userBubbleFill = adaptive(light: Color(red: 0.914, green: 0.918, blue: 0.933),
                                             dark: Color(red: 0.243, green: 0.247, blue: 0.267))
        /// 卡片填充 (兼容旧引用): 浅色=白, 深色=深灰
        static let cardFill = adaptive(light: Color(red: 0.969, green: 0.969, blue: 0.973),
                                       dark: Color(white: 0.15))
        /// 卡片描边
        static let cardStroke = adaptive(light: .black.opacity(0.07),
                                         dark: .white.opacity(0.10))
        /// 玻璃面板的高光描边 (Liquid Glass 边缘亮线)
        static let glassHighlight = LinearGradient(
            colors: [.white.opacity(0.45), .white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        /// 行悬停填充
        static let hoverFill = adaptive(light: .black.opacity(0.045),
                                        dark: .white.opacity(0.07))
        /// 选中行填充
        static let selectedFill = adaptive(light: .black.opacity(0.07),
                                           dark: .white.opacity(0.12))
        /// 柔和阴影
        static let cardShadow = adaptive(light: .black.opacity(0.06),
                                         dark: .black.opacity(0.35))
        /// 玻璃面板的深色投影 (液态玻璃悬浮感)
        static let glassShadow = adaptive(light: .black.opacity(0.10),
                                          dark: .black.opacity(0.45))

        // MARK: ChatGPT 客户端图表色 (Catppuccin 主题)
        /// 滑块划过填充的纯蓝色 (客户端 --color-chart-blue)
        static let chartBlue = adaptive(light: Color(hex: "1E66F5"),
                                        dark: Color(hex: "8CAAEE"))
        /// 滑块 max/ultra 渐变紫 (客户端 --color-chart-purple)
        static let chartPurple = adaptive(light: Color(hex: "8839EF"),
                                          dark: Color(hex: "CA9EE6"))
    }

    /// sRGB 线性混合 (等价 CSS color-mix(in srgb, a (1-t)%, b t%))
    static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let na = NSColor(a).usingColorSpace(.sRGB) ?? NSColor(a)
        let nb = NSColor(b).usingColorSpace(.sRGB) ?? NSColor(b)
        return Color(red: na.redComponent + (nb.redComponent - na.redComponent) * t,
                     green: na.greenComponent + (nb.greenComponent - na.greenComponent) * t,
                     blue: na.blueComponent + (nb.blueComponent - na.blueComponent) * t)
    }

    /// 构造随外观自动切换的动态颜色。
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }

    /// 根据背景色亮度返回高对比度文字色 (浅底黑字 / 深底白字)。
    static func contrastingTextColor(for background: Color) -> Color {
        let ns = NSColor(background).usingColorSpace(.sRGB) ?? NSColor(background)
        let luminance = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return luminance > 0.6 ? Color.black.opacity(0.85) : Color.white
    }
}

// MARK: - 气泡样式 (设置 > 外观 > 气泡)

/// 用户消息气泡的背景样式。
enum BubbleStyle: String, CaseIterable, Identifiable {
    /// 主题渐变: 首色 → 次色 (跟随反转方向)
    case themeGradient
    /// 亮色渐变: 强调色亮部 → 强调色基色
    case brightGradient
    /// 纯色: 主题首色 (跟随反转方向)
    case solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .themeGradient: return "主题渐变 (首色 → 次色)"
        case .brightGradient: return "亮色渐变"
        case .solid: return "纯色"
        }
    }
}

// MARK: - Color hex 工具

extension Color {
    /// 从 "#RRGGBB" 或 "RRGGBB" 构造颜色
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: value).scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF) / 255.0,
                  green: Double((rgb >> 8) & 0xFF) / 255.0,
                  blue: Double(rgb & 0xFF) / 255.0)
    }

    /// 输出 "#RRGGBB"
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - 玻璃面板通用修饰符

/// 给任意视图包一层 Liquid Glass 面板(圆角 + 玻璃质感 + 高光描边 + 投影)。
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.panel
    var tint: Color? = nil

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Theme.Palette.cardFill, in: shape)
            .glassEffect(glass, in: shape)
            .overlay {
                shape.strokeBorder(Theme.Palette.glassHighlight, lineWidth: 1)
            }
            .shadow(color: Theme.Palette.glassShadow, radius: 16, y: 6)
    }

    private var glass: Glass {
        if let tint {
            return .regular.tint(tint)
        }
        return .regular
    }
}

extension View {
    /// 包一层 Liquid Glass 面板。
    func glassPanel(cornerRadius: CGFloat = Theme.Radius.panel, tint: Color? = nil) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, tint: tint))
    }

    /// ChatGPT 式建议卡片: 玻璃面板 + 高光描边。
    func glassTile() -> some View {
        glassPanel(cornerRadius: Theme.Radius.tile)
    }

    /// 明亮极简风格的实体卡片 (浅灰底 + 细描边 + 柔和阴影)。
    func card(cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Theme.Palette.cardFill, in: shape)
            .overlay { shape.strokeBorder(Theme.Palette.cardStroke, lineWidth: 1) }
            .shadow(color: Theme.Palette.cardShadow, radius: 10, y: 3)
    }
}
