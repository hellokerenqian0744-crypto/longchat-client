import Foundation
import SwiftUI
import AppKit

// MARK: - 模型品牌图标

/// 模型品牌图标: 按「提供商名 + 模型名」解析品牌资产名列表。
///
/// 资产为 Resources/Brands 下的品牌 PNG (brand_<名称>.png), 可一次返回多个品牌
/// 并排摆放 (如 Qwen 图标 + 阿里巴巴图标)。无需网络请求;
/// 设置 > 提供商「刷新模型列表」拉取新模型后, 图标随模型名自动刷新。
enum ModelIcon {

    /// 解析品牌资产名列表 (对应 Resources/Brands 下的 PNG)。
    /// 空数组表示未匹配到品牌, 由调用方回退到通用 SF Symbol。
    static func brands(providerName: String, model: String) -> [String] {
        let m = model.lowercased()
        let n = providerName.lowercased()

        // 1) 模型名 → 品牌 (按优先级匹配)
        if m.contains("sol") || m.contains("terra") || m.contains("gpt")
            || m.hasPrefix("o1") || m.hasPrefix("o3") || m.hasPrefix("o4")
            || m.hasPrefix("chatgpt") {
            return ["openai"]                       // OpenAI 结形标
        }
        if m.contains("deepseek") { return ["deepseek"] }   // 深度求索: 鲸鱼
        if m.contains("claude") { return ["anthropic"] }    // Anthropic 星芒
        if m.contains("gemini") { return ["gemini"] }       // Google Gemini 四芒星
        if m.contains("qwen") { return ["qwen"] }           // 仅千问图标
        if m.contains("llama") { return ["meta"] }
        if m.contains("mistral") { return ["mistral"] }
        if m.contains("moonshot") || m.contains("kimi") { return ["kimi"] }
        if m.contains("glm") { return [] }                  // 智谱暂无素材 → 兜底
        if m.contains("command") { return [] }              // Cohere → 兜底
        if m.contains("embedding") || m.contains("whisper")
            || m.contains("tts") || m.contains("audio")
            || m.contains("dall-e") || m.contains("image") { return [] }

        // 2) 提供商名 → 品牌 (兜底)
        if n.contains("openai") || n.contains("chatgpt") || n.contains("gpt") {
            return ["openai"]
        }
        if n.contains("anthropic") || n.contains("claude") { return ["anthropic"] }
        if n.contains("deepseek") { return ["deepseek"] }
        if n.contains("moonshot") || n.contains("kimi") || n.contains("月之暗面") {
            return ["kimi"]
        }
        if n.contains("智谱") || n.contains("glm") || n.contains("bigmodel") { return [] }
        if n.contains("通义") || n.contains("qwen") || n.contains("阿里") {
            return ["qwen"]
        }
        if n.contains("ollama") || n.contains("本地") { return ["ollama"] }
        if n.contains("google") || n.contains("gemini") { return ["gemini"] }
        if n.contains("mistral") { return ["mistral"] }
        if n.contains("llama") || n.contains("meta") { return ["meta"] }
        if n.contains("huggingface") { return ["huggingface"] }

        return []
    }

    /// 从 Bundle 加载品牌 PNG (不存在时返回 nil)。
    static func image(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: "brand_\(name)", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        return image
    }
}

// MARK: - 品牌图标视图

/// 单个品牌图标: 渲染一个品牌 PNG, 保持宽高比, 高度由调用方指定。
struct BrandMarkView: View {
    let name: String
    var height: CGFloat = 14

    var body: some View {
        if let image = ModelIcon.image(named: name) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
        }
    }
}

/// 模型品牌图标视图: 把解析出的品牌列表并排摆放
/// (如 Qwen 图标 + 阿里巴巴图标), 未匹配到品牌时回退到通用 SF Symbol。
struct ModelBrandView: View {
    let providerName: String
    let model: String
    var height: CGFloat = 14

    var body: some View {
        let brands = ModelIcon.brands(providerName: providerName, model: model)
        if brands.isEmpty {
            Image(systemName: "cpu")
                .font(.system(size: height * 0.72, weight: .semibold))
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: height * 0.14) {
                ForEach(brands, id: \.self) { name in
                    BrandMarkView(name: name, height: height)
                }
            }
        }
    }
}
