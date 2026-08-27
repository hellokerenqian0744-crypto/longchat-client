import Foundation
import SwiftUI

// MARK: - Provider (API 配置, CCSwitch 式)

enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case openAICompatible = "openai_compatible"
    case anthropic = "anthropic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible: return "OpenAI 兼容"
        case .anthropic: return "Anthropic"
        }
    }

    var hint: String {
        switch self {
        case .openAICompatible: return "POST {baseURL}/chat/completions (SSE 流式)"
        case .anthropic: return "POST {baseURL}/v1/messages (SSE 流式)"
        }
    }
}

struct APIProvider: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var kind: ProviderKind = .openAICompatible
    var baseURL: String = ""
    var apiKey: String = ""
    var model: String = ""
    var systemPrompt: String = ""
    var temperature: Double = 0.7
    /// 拉取到的模型列表 (设置 > 提供商高级「刷新模型列表」)
    var models: [String] = []
    var createdAt: Date = Date()

    /// 由名称派生的品牌色 (用于切换器圆点与用户气泡着色)
    var tint: Color {
        let palette: [Color] = [
            Color(red: 0.35, green: 0.78, blue: 1.00),
            Color(red: 0.62, green: 0.55, blue: 1.00),
            Color(red: 1.00, green: 0.55, blue: 0.62),
            Color(red: 0.40, green: 0.90, blue: 0.70),
            Color(red: 1.00, green: 0.76, blue: 0.40),
            Color(red: 0.55, green: 0.85, blue: 1.00),
        ]
        var h: UInt64 = 0
        for b in name.utf8 { h = h &* 31 &+ UInt64(b) }
        return palette[Int(h % UInt64(palette.count))]
    }
}

// MARK: - 推理强度档位 (输出强度 = reasoning effort)

struct IntensityLevel: Identifiable, Codable, Hashable {
    let title: String
    let effort: String
    var id: String { title }
}

/// ChatGPT 客户端 Power 滑块档位组合 (model + reasoningEffort 绑定)。
/// sliderLabel 为客户端 sliderSettings 下发的每档专属标题 (如 "Terra Light"/"Medium"/"Ultra High"),
/// 缺失时回退到 modelLabel + effortLabel。
struct PowerBundle: Identifiable, Hashable {
    let key: String
    let model: String
    let modelLabel: String
    let effort: String
    let sliderLabel: String?
    var id: String { key }

    /// 滑块/标题显示名 (客户端 U2s: modelLabel + effortLabel)
    var displayLabel: String {
        sliderLabel ?? "\(modelLabel) \(Reasoning.clientEffortLabel(effort))"
    }
}

/// 推理强度档位 (输出强度): 无/低/中/高 → reasoning_effort 参数。
/// 部分模型无「无」档 (不允许关闭推理)。
enum Reasoning {
    /// 是否 GPT 系列 (OpenAI/gpt/sol/o3/o4): 使用 ChatGPT 客户端式档位与滑块样式。
    static func isGPT(name: String, model: String) -> Bool {
        let n = name.lowercased()
        let m = model.lowercased()
        return n.contains("openai") || n.contains("gpt")
            || m.contains("gpt") || m.contains("sol") || m.contains("o3") || m.contains("o4")
    }

    static func levels(name: String, model: String) -> [IntensityLevel] {
        let n = name.lowercased()
        // GPT 系列: 档位取自 ChatGPT 桌面端 app.asar 内嵌数据
        //   - aN(): 全量档位宇宙 = none/minimal/low/medium/high/xhigh/max/ultra
        //   - dUr:  GPT 默认模型 (gpt-5.5) 兜底档位 = minimal/low/medium/high/xhigh/max
        //   - 无(none) 由 gpt-5.1+ 系列 API 支持, 追加在客户端兜底列表前
        //   - ultra 客户端默认隐藏 (showUltraInModelPickerSlider=false), 不展示
        if isGPT(name: name, model: model) {
            switch gptFamily(name: name, model: model) {
            case .sol:
                // sol 选项档位 (客户端): Light/Medium/High/Extra High/Max/Ultra
                // 滑块只显示 Terra Light/Sol Light/Medium/High/Ultra High, 其余走选项
                return [
                    .init(title: "低", effort: "low"),
                    .init(title: "中", effort: "medium"),
                    .init(title: "高", effort: "high"),
                    .init(title: "超高", effort: "xhigh"),
                    .init(title: "最大", effort: "max"),
                    .init(title: "终极", effort: "ultra"),
                ]
            case .terra:
                // terra: 客户端 d2s 档位 = low/medium/high/xhigh
                return [
                    .init(title: "低", effort: "low"),
                    .init(title: "中", effort: "medium"),
                    .init(title: "高", effort: "high"),
                    .init(title: "超高", effort: "xhigh"),
                ]
            case .other, nil:
                return [
                    .init(title: "无", effort: "none"),
                    .init(title: "极小", effort: "minimal"),
                    .init(title: "低", effort: "low"),
                    .init(title: "中", effort: "medium"),
                    .init(title: "高", effort: "high"),
                    .init(title: "超高", effort: "xhigh"),
                    .init(title: "最大", effort: "max"),
                ]
            }
        }

        // 其他模型: 无/低/中/高
        var result: [IntensityLevel] = [
            .init(title: "低", effort: "low"),
            .init(title: "中", effort: "medium"),
            .init(title: "高", effort: "high"),
        ]
        // 部分模型不允许关闭推理 (无「无」档)
        let hasNone = !(n.contains("deepseek") && model.lowercased().contains("pro"))
        if hasNone {
            result.insert(.init(title: "无", effort: "none"), at: 0)
        }
        return result
    }

    /// ChatGPT 客户端滑块可见档位 = enabled-reasoning-efforts (low/medium/high/xhigh/ultra)
    /// ∩ 模型支持列表; ultra 默认隐藏 → GPT 滑块为 低/中/高/超高 (客户端 Instant/Medium/High/Extra High)。
    /// 其余档位 (无/极小/最大) 为隐藏档位, 只能通过选项菜单切换, 不出现在滑块刻度上。
    static func sliderLevels(name: String, model: String) -> [IntensityLevel] {
        let enabled = Set(["low", "medium", "high", "xhigh"])
        return levels(name: name, model: model).filter { enabled.contains($0.effort) }
    }

    // MARK: - GPT 家族 (客户端 Power 滑块: 仅 sol/terra 有)

    enum GPTFamily: Equatable {
        case sol
        case terra
        case other
    }

    /// GPT 家族判定: 客户端正则 /(?:^|[-_.])sol(?:$|[-_.])/iu, terra 同理。
    static func gptFamily(name: String, model: String) -> GPTFamily? {
        guard isGPT(name: name, model: model) else { return nil }
        let tokens = model.lowercased().split { $0 == "-" || $0 == "_" || $0 == "." }
        if tokens.contains("sol") { return .sol }
        if tokens.contains("terra") { return .terra }
        return .other
    }

    /// 客户端档位显示名 (聊天模式 z1): low→Light, medium→Medium, high→High, xhigh→Extra High…
    static func clientEffortLabel(_ effort: String) -> String {
        switch effort {
        case "none": return "None"
        case "minimal": return "Minimal"
        case "low": return "Light"
        case "medium": return "Medium"
        case "high": return "High"
        case "xhigh": return "Extra High"
        case "max": return "Max"
        case "ultra": return "Ultra"
        default: return effort
        }
    }

    /// Power 滑块档位组合 (客户端 e2s): 模型列表含 sol 优先 l2s (5 档), 否则 d2s (terra 4 档);
    /// 可用档位 ≥3 才启用, 否则返回空 (回到普通强度滑块)。
    static func powerSliderBundles(availableModels: [String]) -> [PowerBundle] {
        let has: (String) -> Bool = { model in
            availableModels.isEmpty || availableModels.contains(model)
        }
        if has("gpt-5.6-sol") {
            let sol = solPowerBundles.filter { has($0.model) }
            if sol.count >= 3 { return sol }
        }
        let terra = terraPowerBundles.filter { has($0.model) }
        return terra.count >= 3 ? terra : []
    }

    /// Sol 的 Ultra 是隐藏顶档：可在强度选项中选择，不作为 Power 主滑块刻度。
    static func hiddenBundles(for model: String) -> [PowerBundle] {
        guard gptFamily(name: "", model: model) == .sol else { return [] }
        return [PowerBundle(key: "gpt-5.6-sol:ultra",
                            model: "gpt-5.6-sol",
                            modelLabel: "5.6 Sol",
                            effort: "ultra",
                            sliderLabel: "Ultra")]
    }

    private static let solPowerBundles: [PowerBundle] = [
        PowerBundle(key: "gpt-5.6-terra:low",    model: "gpt-5.6-terra", modelLabel: "5.6 Terra", effort: "low",    sliderLabel: "Terra Light"),
        PowerBundle(key: "gpt-5.6-sol:low",      model: "gpt-5.6-sol",   modelLabel: "5.6 Sol",   effort: "low",    sliderLabel: "Sol Light"),
        PowerBundle(key: "gpt-5.6-sol:medium",   model: "gpt-5.6-sol",   modelLabel: "5.6 Sol",   effort: "medium", sliderLabel: "Medium"),
        PowerBundle(key: "gpt-5.6-sol:high",     model: "gpt-5.6-sol",   modelLabel: "5.6 Sol",   effort: "high",   sliderLabel: "High"),
        PowerBundle(key: "gpt-5.6-sol:xhigh",    model: "gpt-5.6-sol",   modelLabel: "5.6 Sol",   effort: "xhigh",  sliderLabel: "Extra High"),
    ]
    private static let terraPowerBundles: [PowerBundle] = [
        PowerBundle(key: "gpt-5.6-terra:low",    model: "gpt-5.6-terra", modelLabel: "5.6 Terra", effort: "low",    sliderLabel: "Terra Light"),
        PowerBundle(key: "gpt-5.6-terra:medium", model: "gpt-5.6-terra", modelLabel: "5.6 Terra", effort: "medium", sliderLabel: "Medium"),
        PowerBundle(key: "gpt-5.6-terra:high",   model: "gpt-5.6-terra", modelLabel: "5.6 Terra", effort: "high",   sliderLabel: "High"),
        PowerBundle(key: "gpt-5.6-terra:xhigh",  model: "gpt-5.6-terra", modelLabel: "5.6 Terra", effort: "xhigh",  sliderLabel: "Extra High"),
    ]

    /// 默认推理强度 (中档)
    static func defaultEffort(name: String, model: String) -> String {
        levels(name: name, model: model).first(where: { $0.title == "中" })?.effort ?? "medium"
    }
}

extension APIProvider {
    struct Preset: Identifiable {
        let id = UUID()
        let name: String
        let kind: ProviderKind
        let baseURL: String
        let model: String
        let note: String
    }

    static let presets: [Preset] = [
        .init(name: "OpenAI", kind: .openAICompatible,
              baseURL: "https://api.openai.com/v1",
              model: "gpt-4o",
              note: "OpenAI 官方"),
        .init(name: "Anthropic Claude", kind: .anthropic,
              baseURL: "https://api.anthropic.com",
              model: "claude-sonnet-4-5",
              note: "Claude 官方"),
        .init(name: "DeepSeek", kind: .openAICompatible,
              baseURL: "https://api.deepseek.com/v1",
              model: "deepseek-v4-flash",
              note: "DeepSeek 官方"),
        .init(name: "Moonshot (Kimi)", kind: .openAICompatible,
              baseURL: "https://api.moonshot.cn/v1",
              model: "moonshot-v1-8k",
              note: "月之暗面"),
        .init(name: "智谱 GLM", kind: .openAICompatible,
              baseURL: "https://open.bigmodel.cn/api/paas/v4",
              model: "glm-4-plus",
              note: "智谱 AI"),
        .init(name: "Ollama (本地)", kind: .openAICompatible,
              baseURL: "http://localhost:11434/v1",
              model: "llama3.1",
              note: "本地推理, 无需 Key"),
        .init(name: "自定义 (OpenAI 兼容)", kind: .openAICompatible,
              baseURL: "https://your-gateway.example.com/v1",
              model: "your-model",
              note: "任意中转 / 网关"),
    ]

    static func from(_ preset: Preset) -> APIProvider {
        var p = APIProvider()
        p.name = preset.name
        p.kind = preset.kind
        p.baseURL = preset.baseURL
        p.model = preset.model
        return p
    }
}

// MARK: - Chat

enum ChatRole: String, Codable {
    case system
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var role: ChatRole
    var content: String
    var date: Date = Date()
    var isError: Bool = false
    var modelName: String? = nil
    /// 思考过程 (reasoning/thinking 增量, 流式期间累积)
    var thinking: String? = nil
    /// 附加的文件 (图片走多模态 base64 发送, 文本文件内容并入正文)
    var attachments: [FileAttachment] = []
}

struct Conversation: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = "新对话"
    var messages: [ChatMessage] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastProviderID: UUID? = nil

    var subtitle: String {
        if let last = messages.last {
            return String(last.content.prefix(60)).replacingOccurrences(of: "\n", with: " ")
        }
        return "暂无消息"
    }
}

// MARK: - 文件附件

/// 附件类型: 文本 / 图片 / 二进制。
enum FileKind: String, Codable, CaseIterable {
    case text
    case image
    case binary

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .binary: return "doc"
        }
    }

    /// 根据文件扩展名 + 内容嗅探判断类型。
    static func detect(fileName: String, data: Data) -> FileKind {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tiff", "tif"]
        if imageExts.contains(ext) { return .image }
        // 能按 UTF-8 解码则按文本处理 (支持 txt/md/json/swift/log/csv 等)
        if String(data: data, encoding: .utf8) != nil { return .text }
        return .binary
    }
}

/// 一条附件的完整信息 (含原始内容, 便于发送与再生成)。
struct FileAttachment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var kind: FileKind = .binary
    var sizeBytes: Int = 0
    /// 原始字节 (文本发送前解析为字符串, 图片编码为 base64)
    var data: Data = Data()

    /// 人类可读的体积 (如 "1.2 MB")。
    var sizeDisplay: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }

    /// 图片的 MIME 类型 (用于 data URL / Anthropic source.media_type)。
    var mediaType: String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "heif": return "image/heif"
        case "bmp": return "image/bmp"
        case "tiff", "tif": return "image/tiff"
        default: return "application/octet-stream"
        }
    }

    /// 文本文件的解码内容 (非文本返回 nil)。
    var textContent: String? {
        guard kind == .text else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - 持久化载荷

struct AppData: Codable {
    var providers: [APIProvider] = []
    var activeProviderID: UUID? = nil
    var conversations: [Conversation] = []
    var activeConversationID: UUID? = nil
}
