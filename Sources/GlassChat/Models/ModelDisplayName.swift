import Foundation

// MARK: - 模型显示名

/// 模型显示名: 把原始模型 ID (如 gpt-5.6-sol / qwen3.8-max) 转为友好名称
/// (如 5.6 Sol / Qwen 3.8 Max), 可附带推理强度 (如 "5.6 Sol Medium")。
enum ModelDisplayName {

    /// 友好模型名 (不带推理强度)
    static func name(providerName: String, model: String) -> String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return model }
        if let r = known(model: m) { return r }
        if let r = prefixed(model: m) { return r }
        return prettify(m)
    }

    /// 聊天界面按钮显示名: 友好模型名 + 推理强度 (如 "5.6 Sol Medium")
    static func chatLabel(providerName: String, model: String, effort: String) -> String {
        let n = name(providerName: providerName, model: model)
        guard !effort.isEmpty else { return n }
        return "\(n) \(Reasoning.clientEffortLabel(effort))"
    }

    /// 输入框内的紧凑显示: 去掉品牌词 + 「｜」分隔强度 (如 "V4 Pro｜Medium")。
    static func chipLabel(providerName: String, model: String, effort: String) -> String {
        let full = name(providerName: providerName, model: model)
        let brandWords: Set<String> = ["DeepSeek", "Qwen", "Claude", "Llama",
                                       "Mistral", "Gemini", "Moonshot", "Wan", "Wanx"]
        var parts = full.split(separator: " ").map(String.init)
        if let first = parts.first, brandWords.contains(first) {
            parts.removeFirst()
        }
        let short = parts.joined(separator: " ")
        let effortLabel = effort.isEmpty ? "" : Reasoning.clientEffortLabel(effort)
        if short.isEmpty { return effortLabel }
        if effortLabel.isEmpty { return short }
        return "\(short)｜\(effortLabel)"
    }

    // MARK: 精确映射

    private static func known(model m: String) -> String? {
        switch m.lowercased() {
        case "gpt-5.6-sol": return "5.6 Sol"
        case "gpt-5.6-terra": return "5.6 Terra"
        case "gpt-4o": return "4o"
        case "gpt-4o-mini": return "4o Mini"
        case "gpt-4-turbo": return "4 Turbo"
        case "gpt-3.5-turbo": return "3.5 Turbo"
        case "o1": return "o1"
        case "o1-mini": return "o1 Mini"
        case "o1-preview": return "o1 Preview"
        case "o3-mini": return "o3 Mini"
        case "o4-mini": return "o4 Mini"
        case "deepseek-chat": return "DeepSeek Chat"
        case "deepseek-reasoner": return "DeepSeek Reasoner"
        case "deepseek-v4-flash": return "DeepSeek V4 Flash"
        case "deepseek-v4-pro": return "DeepSeek V4 Pro"
        case "claude-sonnet-4-5": return "Claude Sonnet 4.5"
        case "claude-opus-4-1": return "Claude Opus 4.1"
        case "claude-haiku-4-5": return "Claude Haiku 4.5"
        case "claude-3-5-sonnet": return "Claude 3.5 Sonnet"
        case "llama3.1": return "Llama 3.1"
        case "llama3.2": return "Llama 3.2"
        case "llama3.3": return "Llama 3.3"
        case "mistral-large-latest": return "Mistral Large"
        case "mistral-small-latest": return "Mistral Small"
        case "mistral-medium-latest": return "Mistral Medium"
        case "glm-4-plus": return "GLM-4 Plus"
        case "glm-4-flash": return "GLM-4 Flash"
        case "glm-4v-plus": return "GLM-4V Plus"
        case "moonshot-v1-8k": return "Moonshot V1 8K"
        case "moonshot-v1-32k": return "Moonshot V1 32K"
        case "moonshot-v1-128k": return "Moonshot V1 128K"
        case "gemini-2.5-pro": return "Gemini 2.5 Pro"
        case "gemini-2.5-flash": return "Gemini 2.5 Flash"
        case "gemini-2.0-flash": return "Gemini 2.0 Flash"
        default: return nil
        }
    }

    // MARK: 前缀映射

    private static func prefixed(model m: String) -> String? {
        let lower = m.lowercased()

        // Qwen: qwen3.8-max → Qwen 3.8 Max; qwen-plus → Qwen Plus; qwen2.5 → Qwen 2.5
        if lower.hasPrefix("qwen") {
            let rest = String(lower.dropFirst(4))
            if rest.isEmpty { return "Qwen" }
            if rest.hasPrefix("-") {
                let tier = rest.dropFirst().capitalized
                return "Qwen \(tier)".trimmingCharacters(in: .whitespaces)
            }
            let parts = rest.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            let version = String(parts.first ?? "").uppercased()
            let tier = parts.count > 1 ? parts[1].capitalized : ""
            var out = "Qwen"
            if !version.isEmpty { out += " \(version)" }
            if !tier.isEmpty { out += " \(tier)" }
            return out
        }

        // gpt 系列: 去掉 "GPT-" 前缀 (gpt-5.4 → 5.4, gpt-4.1-mini → 4.1 Mini)
        if lower.hasPrefix("gpt") {
            let base = lower.hasPrefix("gpt-") ? String(lower.dropFirst(4)) : String(lower.dropFirst(3))
            let parts = base.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            let v = String(parts.first ?? "")
            let suffix = parts.count > 1 ? parts[1].capitalized : ""
            if v.isEmpty { return "GPT" }
            return "\(v)\(suffix.isEmpty ? "" : " \(suffix)")"
        }

        // o1/o3/o4 系列: o3-mini → o3 Mini
        if lower.hasPrefix("o1") || lower.hasPrefix("o3") || lower.hasPrefix("o4") {
            let parts = lower.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            let base = String(parts.first ?? "")
            let suffix = parts.count > 1 ? parts[1].capitalized : ""
            return suffix.isEmpty ? base : "\(base) \(suffix)"
        }

        // claude-sonnet-4-5 → Claude Sonnet 4.5
        if lower.hasPrefix("claude") {
            let rest = lower.dropFirst("claude".count).split(separator: "-").filter { !$0.isEmpty }
            guard let first = rest.first else { return "Claude" }
            var out = "Claude " + first.capitalized
            let nums = rest.dropFirst().filter { $0.allSatisfy(\.isNumber) }
            if nums.count >= 2 {
                out += " " + nums.prefix(2).joined(separator: ".")
            } else if nums.count == 1 {
                out += " " + nums[0]
            }
            return out
        }

        // deepseek-v4-flash → DeepSeek V4 Flash
        if lower.hasPrefix("deepseek") {
            let rest = lower.dropFirst("deepseek".count).split(separator: "-").filter { !$0.isEmpty }
            if rest.isEmpty { return "DeepSeek" }
            return "DeepSeek " + rest.map { $0.capitalized }.joined(separator: " ")
        }

        // llama3.1 / llama3.1-70b → Llama 3.1 / Llama 3.1 70B
        if lower.hasPrefix("llama") {
            let rest = lower.dropFirst("llama".count)
            let parts = rest.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            let v = String(parts.first ?? "")
            let suffix = parts.count > 1 ? parts[1].uppercased() : ""
            return "Llama \(v)\(suffix.isEmpty ? "" : " \(suffix)")"
        }

        // mistral-large-latest → Mistral Large
        if lower.hasPrefix("mistral") {
            let rest = lower.dropFirst("mistral".count).split(separator: "-")
                .filter { !$0.isEmpty && $0 != "latest" }
            if rest.isEmpty { return "Mistral" }
            return "Mistral " + rest.map { $0.capitalized }.joined(separator: " ")
        }

        // glm-4-plus → GLM-4 Plus
        if lower.hasPrefix("glm") {
            let rest = lower.dropFirst("glm".count).split(separator: "-").filter { !$0.isEmpty }
            var out = "GLM"
            for part in rest {
                if part.allSatisfy(\.isNumber) { out += "-\(part)" }
                else { out += " " + part.capitalized }
            }
            return out
        }

        // moonshot-v1-8k → Moonshot V1 8K
        if lower.hasPrefix("moonshot") {
            let rest = lower.dropFirst("moonshot".count).split(separator: "-").filter { !$0.isEmpty }
            if rest.isEmpty { return "Moonshot" }
            return "Moonshot " + rest.map { $0.capitalized }.joined(separator: " ")
        }

        // gemini-2.5-pro → Gemini 2.5 Pro
        if lower.hasPrefix("gemini") {
            let rest = lower.dropFirst("gemini".count).split(separator: "-").filter { !$0.isEmpty }
            if rest.isEmpty { return "Gemini" }
            return "Gemini " + rest.map { $0.capitalized }.joined(separator: " ")
        }

        // wanx2.1-t2v-turbo → Wanx 2.1 T2V Turbo (通义万相)
        if lower.hasPrefix("wanx") {
            let rest = String(lower.dropFirst(4))
            let parts = rest.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            let version = String(parts.first ?? "").uppercased()
            let suffix = parts.count > 1
                ? wanSuffix(parts[1])
                : ""
            var out = "Wanx"
            if !version.isEmpty { out += " \(version)" }
            if !suffix.isEmpty { out += " \(suffix)" }
            return out
        }

        // wan2.5-t2v → Wan 2.5 T2V (万相视频生成)
        if lower.hasPrefix("wan") {
            let rest = String(lower.dropFirst(3))
            let parts = rest.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            let version = String(parts.first ?? "").uppercased()
            let suffix = parts.count > 1
                ? wanSuffix(parts[1])
                : ""
            var out = "Wan"
            if !version.isEmpty { out += " \(version)" }
            if !suffix.isEmpty { out += " \(suffix)" }
            return out
        }

        return nil
    }

    // MARK: 兜底

    /// Wan/Wanx 后缀段: 含数字的段大写 (t2v→T2V, 14b→14B), 纯字母段首字母大写 (turbo→Turbo)。
    private static func wanSuffix(_ s: Substring) -> String {
        s.split(separator: "-").map { seg in
            seg.contains(where: { $0.isNumber }) ? seg.uppercased() : seg.capitalized
        }.joined(separator: " ")
    }

    /// 去掉连字符/下划线, 单词首字母大写
    private static func prettify(_ m: String) -> String {
        let words = m.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "." })
            .map { $0.capitalized }
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? m : joined
    }
}
