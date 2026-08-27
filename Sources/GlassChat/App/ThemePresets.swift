import SwiftUI

/// 客户端主题预设 — 1:1 移植自 FDPClient `ClientThemesUtils.kt` 的主题色表。
///
/// 每个主题是一对「起始色 → 结束色」的渐变; 选中后:
/// - `start` 作为全局强调色 (按钮高亮 / 输入框边框 / 气泡等)
/// - `end` 仅用于主题预览色样与 fade 参考
/// 特殊主题 `rainbow` / `astolfo` 为动态彩虹模式 (`isRainbow == true`)。
struct ThemePreset: Identifiable {
    /// 小写标识 (与 FDP 的 `ClientColorMode` 一致)
    let key: String
    /// 展示名
    let name: String
    /// 渐变起始色 (作为全局强调色)
    let start: Color
    /// 渐变结束色
    let end: Color
    /// 动态彩虹模式
    let isRainbow: Bool
    /// 彩虹饱和度 (仅彩虹主题使用; 对应 skyRainbow 的 st)
    let rainbowSaturation: Double
    /// 彩虹亮度 (仅彩虹主题使用; 对应 skyRainbow 的 bright)
    let rainbowBrightness: Double

    var id: String { key }

    init(key: String, name: String, start: Color, end: Color,
         isRainbow: Bool = false,
         rainbowSaturation: Double = 0,
         rainbowBrightness: Double = 0) {
        self.key = key
        self.name = name
        self.start = start
        self.end = end
        self.isRainbow = isRainbow
        self.rainbowSaturation = rainbowSaturation
        self.rainbowBrightness = rainbowBrightness
    }

    /// 全部主题 (顺序: Moon Purple 默认在前, 其余按字母, 彩虹收尾)
    static let all: [ThemePreset] = {
        func c(_ r: Int, _ g: Int, _ b: Int) -> Color {
            Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
        return [
            ThemePreset(key: "moonpurple", name: "Moon Purple", start: c(78, 84, 200), end: c(143, 148, 251), isRainbow: false),
            ThemePreset(key: "abyss", name: "Abyss", start: c(10, 20, 60), end: c(40, 80, 160), isRainbow: false),
            ThemePreset(key: "amethyst", name: "Amethyst", start: c(157, 80, 187), end: c(110, 72, 170), isRainbow: false),
            ThemePreset(key: "amin", name: "Amin", start: c(142, 45, 226), end: c(74, 0, 224), isRainbow: false),
            ThemePreset(key: "aqua", name: "Aqua", start: c(80, 255, 255), end: c(80, 190, 255), isRainbow: false),
            ThemePreset(key: "aqualicious", name: "Aqualicious", start: c(80, 201, 195), end: c(150, 222, 218), isRainbow: false),
            ThemePreset(key: "azure", name: "Azure", start: c(0, 90, 255), end: c(0, 180, 255), isRainbow: false),
            ThemePreset(key: "blush", name: "Blush", start: c(178, 69, 146), end: c(241, 95, 121), isRainbow: false),
            ThemePreset(key: "cero", name: "Cero", start: c(170, 0, 170), end: c(170, 255, 170), isRainbow: false),
            ThemePreset(key: "coral", name: "Coral", start: c(52, 133, 151), end: c(244, 168, 150), isRainbow: false),
            ThemePreset(key: "crimson", name: "Crimson", start: c(200, 20, 60), end: c(120, 0, 40), isRainbow: false),
            ThemePreset(key: "cyber", name: "Cyber", start: c(0, 255, 200), end: c(0, 140, 255), isRainbow: false),
            ThemePreset(key: "darknight", name: "Dark Night", start: c(93, 95, 95), end: c(203, 200, 204), isRainbow: false),
            ThemePreset(key: "dirtyfog", name: "Dirty Fog", start: c(185, 147, 214), end: c(140, 166, 219), isRainbow: false),
            ThemePreset(key: "ember", name: "Ember", start: c(255, 90, 20), end: c(180, 30, 20), isRainbow: false),
            ThemePreset(key: "eveningsunshine", name: "Evening Sunshine", start: c(185, 43, 39), end: c(21, 101, 192), isRainbow: false),
            ThemePreset(key: "fdp", name: "FDP", start: c(255, 100, 255), end: c(100, 255, 255), isRainbow: false),
            ThemePreset(key: "fire", name: "Fire", start: c(255, 45, 30), end: c(255, 123, 15), isRainbow: false),
            ThemePreset(key: "flower", name: "Flower", start: c(184, 85, 199), end: c(182, 140, 195), isRainbow: false),
            ThemePreset(key: "glacier", name: "Glacier", start: c(140, 220, 255), end: c(40, 120, 200), isRainbow: false),
            ThemePreset(key: "gold", name: "Gold", start: c(255, 210, 90), end: c(200, 140, 20), isRainbow: false),
            ThemePreset(key: "inbox", name: "Inbox", start: c(69, 127, 202), end: c(86, 145, 200), isRainbow: false),
            ThemePreset(key: "lava", name: "Lava", start: c(255, 140, 0), end: c(200, 0, 0), isRainbow: false),
            ThemePreset(key: "lightorange", name: "Light Orange", start: c(255, 183, 94), end: c(237, 143, 3), isRainbow: false),
            ThemePreset(key: "lime", name: "Lime", start: c(180, 255, 80), end: c(80, 200, 40), isRainbow: false),
            ThemePreset(key: "littleleaf", name: "Little Leaf", start: c(118, 184, 82), end: c(141, 194, 111), isRainbow: false),
            ThemePreset(key: "loyoi", name: "Loyoi", start: c(255, 131, 0), end: c(255, 131, 124), isRainbow: false),
            ThemePreset(key: "magic", name: "Magic", start: c(255, 180, 255), end: c(181, 139, 194), isRainbow: false),
            ThemePreset(key: "magics", name: "Magics", start: c(89, 193, 115), end: c(93, 38, 193), isRainbow: false),
            ThemePreset(key: "mangopulp", name: "Mango Pulp", start: c(240, 152, 25), end: c(237, 222, 93), isRainbow: false),
            ThemePreset(key: "martini", name: "Martini", start: c(253, 252, 71), end: c(36, 254, 65), isRainbow: false),
            ThemePreset(key: "may", name: "May", start: c(255, 80, 255), end: c(255, 255, 255), isRainbow: false),
            ThemePreset(key: "mint", name: "Mint", start: c(85, 255, 140), end: c(85, 255, 255), isRainbow: false),
            ThemePreset(key: "mocharose", name: "Mocha Rose", start: c(245, 194, 231), end: c(243, 139, 168), isRainbow: false),
            ThemePreset(key: "moonasteroid", name: "Moon Asteroid", start: c(15, 32, 39), end: c(44, 83, 100), isRainbow: false),
            ThemePreset(key: "nelson", name: "Nelson", start: c(242, 112, 156), end: c(255, 148, 114), isRainbow: false),
            ThemePreset(key: "orca", name: "Orca", start: c(68, 160, 141), end: c(9, 54, 55), isRainbow: false),
            ThemePreset(key: "peony", name: "Peony", start: c(255, 120, 255), end: c(255, 190, 255), isRainbow: false),
            ThemePreset(key: "piglet", name: "Piglet", start: c(238, 156, 167), end: c(255, 221, 225), isRainbow: false),
            ThemePreset(key: "pinkflavour", name: "Pink Flavour", start: c(128, 0, 128), end: c(255, 192, 203), isRainbow: false),
            ThemePreset(key: "pinotnoir", name: "Pinot Noir", start: c(75, 108, 183), end: c(24, 40, 72), isRainbow: false),
            ThemePreset(key: "polarized", name: "Polarized", start: c(0, 32, 64), end: c(173, 239, 209), isRainbow: false),
            ThemePreset(key: "pumpkin", name: "Pumpkin", start: c(255, 216, 169), end: c(241, 166, 98), isRainbow: false),
            ThemePreset(key: "purplin", name: "Purplin", start: c(106, 48, 147), end: c(160, 68, 255), isRainbow: false),
            ThemePreset(key: "quepal", name: "Quepal", start: c(17, 153, 142), end: c(56, 239, 125), isRainbow: false),
            ThemePreset(key: "reef", name: "Reef", start: c(0, 210, 255), end: c(58, 123, 213), isRainbow: false),
            ThemePreset(key: "roseglow", name: "Rose Glow", start: c(255, 120, 160), end: c(220, 40, 120), isRainbow: false),
            ThemePreset(key: "shifter", name: "Shifter", start: c(188, 78, 156), end: c(248, 7, 89), isRainbow: false),
            ThemePreset(key: "sincityred", name: "Sin City Red", start: c(237, 33, 58), end: c(147, 41, 30), isRainbow: false),
            ThemePreset(key: "soundcloud", name: "SoundCloud", start: c(254, 140, 0), end: c(248, 54, 0), isRainbow: false),
            ThemePreset(key: "steel", name: "Steel", start: c(120, 140, 160), end: c(40, 50, 70), isRainbow: false),
            ThemePreset(key: "stripe", name: "Stripe", start: c(31, 162, 255), end: c(166, 255, 203), isRainbow: false),
            ThemePreset(key: "sublimevivid", name: "Sublime Vivid", start: c(252, 70, 107), end: c(63, 94, 251), isRainbow: false),
            ThemePreset(key: "summerdog", name: "Summer Dog", start: c(168, 255, 120), end: c(120, 255, 214), isRainbow: false),
            ThemePreset(key: "sun", name: "Sun", start: c(255, 143, 0), end: c(252, 205, 44), isRainbow: false),
            ThemePreset(key: "sundae", name: "Sundae", start: c(28, 28, 27), end: c(206, 74, 126), isRainbow: false),
            ThemePreset(key: "terminal", name: "Terminal", start: c(25, 30, 25), end: c(15, 155, 15), isRainbow: false),
            ThemePreset(key: "timber", name: "Timber", start: c(252, 0, 255), end: c(0, 219, 222), isRainbow: false),
            ThemePreset(key: "tree", name: "Tree", start: c(18, 155, 38), end: c(76, 255, 102), isRainbow: false),
            ThemePreset(key: "turquoiseflow", name: "Turquoise Flow", start: c(19, 106, 138), end: c(38, 120, 113), isRainbow: false),
            ThemePreset(key: "twilight", name: "Twilight", start: c(90, 40, 160), end: c(220, 90, 200), isRainbow: false),
            ThemePreset(key: "venom", name: "Venom", start: c(120, 255, 40), end: c(20, 140, 60), isRainbow: false),
            ThemePreset(key: "vergren", name: "Vergren", start: c(170, 255, 169), end: c(17, 255, 189), isRainbow: false),
            ThemePreset(key: "water", name: "Water", start: c(35, 69, 148), end: c(108, 170, 207), isRainbow: false),
            ThemePreset(key: "zywl", name: "Zywl", start: c(206, 58, 98), end: c(215, 171, 168), isRainbow: false),
            ThemePreset(key: "rainbow", name: "Rainbow", start: c(255, 60, 60), end: c(90, 120, 255),
                        isRainbow: true, rainbowSaturation: 1.0, rainbowBrightness: 1.0),
            ThemePreset(key: "astolfo", name: "Astolfo", start: c(255, 120, 200), end: c(120, 180, 255),
                        isRainbow: true, rainbowSaturation: 0.6, rainbowBrightness: 1.0),
        ]
    }()

    /// 按 key 查找 (空 key = 自定义颜色, 返回 nil)
    static func byKey(_ key: String) -> ThemePreset? {
        all.first { $0.key == key }
    }

    /// 默认主题 (与 FDP 一致: Moon Purple)
    static let defaultKey = "moonpurple"
}
