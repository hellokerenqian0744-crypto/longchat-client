import SwiftUI
import Foundation

// MARK: - 桌面式默认界面小组件

/// 大时钟: 时间 + 星期 + 日期 (每秒刷新)。
struct ClockWidget: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            VStack(alignment: .leading, spacing: 6) {
                Text(date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                HStack(spacing: 10) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(date.formatted(.dateTime.month().day()))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: 天气

/// 天气服务: Open-Meteo (免费, 无需 Key), 默认上海。
enum WeatherService {
    struct Result: Equatable {
        let temperature: Double
        let code: Int
    }

    static func fetch(latitude: Double = 36.389, longitude: Double = 120.447) async throws -> Result {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = obj["current"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        let temperature = current["temperature_2m"] as? Double ?? 0
        let code = current["weather_code"] as? Int ?? 0
        return Result(temperature: temperature, code: code)
    }
}

/// WMO 天气码 → SF Symbol 与中文描述。
enum WeatherSymbol {
    static func name(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 61, 63, 65: return "cloud.rain.fill"
        case 66, 67, 80, 81, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func text(for code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1, 2: return "多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51, 53, 55: return "毛毛雨"
        case 56, 57: return "冻雨"
        case 61, 63, 65: return "雨"
        case 66, 67: return "冻雨"
        case 71, 73, 75, 77: return "雪"
        case 80, 81, 82: return "阵雨"
        case 85, 86: return "阵雪"
        case 95: return "雷暴"
        case 96, 99: return "雷阵雨"
        default: return "--"
        }
    }
}

struct WeatherWidget: View {
    @Environment(\.liveAccent) private var liveAccent
    @Local private var temperature: Double = 0
    @Local private var weatherCode: Int = -1
    @Local private var loaded = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: WeatherSymbol.name(for: weatherCode))
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(loaded ? "\(Int(temperature.rounded()))°" : "--°")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.primary)
                Text(loaded ? WeatherSymbol.text(for: weatherCode) : "加载中")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("即墨")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Text("今天")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassTile()
        .task { await load() }
    }

    private var accentColor: Color {
        switch weatherCode {
        case 0: return .orange
        case 1, 2, 3: return liveAccent
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99: return .blue
        case 71, 73, 75, 77, 85, 86: return .cyan
        case 45, 48: return .gray
        default: return .secondary
        }
    }

    private func load() async {
        do {
            let result = try await WeatherService.fetch()
            temperature = result.temperature
            weatherCode = result.code
        } catch {
            // 网络失败保持 "--"
        }
        loaded = true
    }
}

// MARK: 迷你日历

struct CalendarWidget: View {
    @Environment(\.liveAccent) private var liveAccent

    private let weekdayHeaders = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let monthComponents = calendar.dateComponents([.year, .month], from: now)
        let firstOfMonth = calendar.date(from: DateComponents(year: monthComponents.year, month: monthComponents.month, day: 1))!
        let weekday = calendar.component(.weekday, from: firstOfMonth) // 1=周日 ... 7=周六
        let leadingBlanks = (weekday - 2 + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let today = calendar.component(.day, from: now)

        VStack(spacing: 12) {
            Text(monthComponents.year.map { "\($0)年" } ?? "")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                ForEach(weekdayHeaders, id: \.self) { w in
                    Text(w)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 26)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    Text("\(day)")
                        .font(.system(size: 14, weight: day == today ? .semibold : .regular))
                        .foregroundStyle(day == today ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background {
                            if day == today {
                                Circle().fill(liveAccent)
                            }
                        }
                }
            }
        }
        .padding(16)
        .glassTile()
    }
}

// MARK: 每日一言

enum DailyQuote {
    static let quotes: [(text: String, author: String)] = [
        ("生活的意义在于拼搏, 因为世界本身就是一个竞技场。", "泰戈尔"),
        ("路漫漫其修远兮, 吾将上下而求索。", "屈原"),
        ("知之者不如好之者, 好之者不如乐之者。", "孔子"),
        ("不积跬步, 无以至千里。", "荀子"),
        ("千里之行, 始于足下。", "老子"),
        ("海纳百川, 有容乃大。", "林则徐"),
        ("山重水复疑无路, 柳暗花明又一村。", "陆游"),
        ("宝剑锋从磨砺出, 梅花香自苦寒来。", "佚名"),
        ("天行健, 君子以自强不息。", "《周易》"),
        ("纸上得来终觉浅, 绝知此事要躬行。", "陆游"),
    ]

    static func today() -> (text: String, author: String) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[day % quotes.count]
    }
}

struct QuoteWidget: View {
    @Environment(\.liveAccent) private var liveAccent

    var body: some View {
        let quote = DailyQuote.today()
        VStack(alignment: .leading, spacing: 8) {
            Label("每日一言", systemImage: "quote.opening")
                .font(.caption.weight(.semibold))
                .foregroundStyle(liveAccent)
            Text(quote.text)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineSpacing(3)
            Text("— \(quote.author)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassTile()
    }
}

// MARK: - AI 元素

/// 发光 AI 圆球: 主题双色实时流动渐变 + 星光图标。
private struct AIOrb: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let timer = t * (Theme.fadeSpeed / 5.0) * 4.0
            let stops: [Gradient.Stop] = (0..<24).map { i in
                let p = (sin(timer + Double(i) * 0.18) + 1.0) * 0.5
                let color = Theme.mix(Theme.fadeSecond, Theme.fadeFirst, p)
                return .init(color: color, location: Double(i) / 23.0)
            }
            let shadowColor = Theme.fadeColor(at: t)

            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .glassEffect(.regular, in: Circle())
                Circle()
                    .fill(LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .opacity(0.85)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            .shadow(color: shadowColor.opacity(0.45), radius: 14, y: 4)
        }
    }
}

/// AI 状态卡: 发光 AI 球 + 名称 + 当前模型 + 在线状态。
struct AIStatusWidget: View {
    @EnvironmentObject private var app: AppState

    private var modelLabel: String {
        if let model = app.activeProvider?.model, !model.isEmpty {
            return ModelDisplayName.chipLabel(providerName: app.activeProvider?.name ?? "",
                                              model: model,
                                              effort: app.reasoningEffort)
        }
        return app.activeProvider?.name ?? "模型"
    }

    var body: some View {
        HStack(spacing: 18) {
            AIOrb()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("JBChat")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("多模型 AI 客户端")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.fadeFirst)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.fadeFirst.opacity(0.14)))
                }
                HStack(spacing: 7) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("在线 · \(modelLabel)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("连接多个 AI 服务 · 统一对话与推理")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassTile()
    }
}

/// AI 能力胶囊: 点击即发送对应开场提示。
struct AICapabilitiesWidget: View {
    @EnvironmentObject private var app: AppState

    private let capabilities: [(icon: String, title: String, prompt: String)] = [
        ("bubble.left.and.bubble.right.fill", "对话", "我们聊聊吧"),
        ("brain.head.profile", "深度思考", "帮我深入思考一个问题"),
        ("pencil.line", "写作", "帮我写一段文字"),
        ("chevron.left.forwardslash.chevron.right", "代码", "帮我写一段代码"),
        ("globe", "翻译", "帮我翻译一段文字"),
        ("text.alignleft", "总结", "帮我总结一段内容"),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            ForEach(capabilities, id: \.title) { cap in
                Button {
                    app.send(cap.prompt)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: cap.icon)
                            .font(.caption)
                            .foregroundStyle(Theme.fadeFirst)
                        Text(cap.title)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 8)
                    .background(Theme.Palette.cardFill, in: Capsule())
                    .glassEffect(.regular, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Theme.Palette.glassHighlight, lineWidth: 1)
                    }
                    .shadow(color: Theme.Palette.glassShadow, radius: 8, y: 3)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 720)
    }
}
