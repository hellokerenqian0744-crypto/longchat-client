import Foundation

// MARK: - 错误

struct ChatClientError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// MARK: - 流式客户端
// 支持两类协议:
//  1. OpenAI 兼容: POST {base}/chat/completions, SSE "data: {...}" / "[DONE]"
//  2. Anthropic:   POST {base}/v1/messages, SSE event content_block_delta

enum ChatClient {

    static func stream(
        provider: APIProvider,
        history: [ChatMessage],
        systemPrompt: String,
        temperature: Double,
        reasoningEffort: String,
        onDelta: @escaping @Sendable (String) -> Void,
        onThinking: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        switch provider.kind {
        case .openAICompatible:
            return try await streamOpenAI(provider: provider, history: history,
                                          systemPrompt: systemPrompt, temperature: temperature,
                                          reasoningEffort: reasoningEffort,
                                          onDelta: onDelta, onThinking: onThinking)
        case .anthropic:
            return try await streamAnthropic(provider: provider, history: history,
                                             systemPrompt: systemPrompt, temperature: temperature,
                                             reasoningEffort: reasoningEffort,
                                             onDelta: onDelta, onThinking: onThinking)
        }
    }

    // MARK: OpenAI 兼容

    private static func streamOpenAI(
        provider: APIProvider,
        history: [ChatMessage],
        systemPrompt: String,
        temperature: Double,
        reasoningEffort: String,
        onDelta: @escaping @Sendable (String) -> Void,
        onThinking: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let url = try endpointURL(base: provider.baseURL, path: "/chat/completions")

        var payloadMessages: [[String: Any]] = []
        let sys = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sys.isEmpty {
            payloadMessages.append(["role": "system", "content": sys])
        }
        for m in history where m.role != .system && !m.isError {
            if m.role == .user {
                payloadMessages.append(["role": m.role.rawValue,
                                        "content": userContent(for: m, anthropic: false)])
            } else {
                payloadMessages.append(["role": m.role.rawValue, "content": m.content])
            }
        }
        guard !payloadMessages.isEmpty else { throw ChatClientError("消息为空") }

        var body: [String: Any] = [
            "model": provider.model,
            "stream": true,
            "messages": payloadMessages,
        ]
        body["temperature"] = temperature
        // 输出强度 = 推理强度 (OpenAI 兼容 reasoning_effort)
        if !reasoningEffort.isEmpty && reasoningEffort != "none" {
            body["reasoning_effort"] = reasoningEffort
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try await checkHTTP(response, bytes: bytes)

        var full = ""
        for try await rawLine in bytes.lines {
            try Task.checkCancellation()
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let err = obj["error"] as? [String: Any], let msg = err["message"] as? String {
                throw ChatClientError(msg)
            }
            guard let choices = obj["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any]
            else { continue }
            // 思考过程 (OpenAI 兼容: reasoning_content / reasoning)
            if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                onThinking(reasoning)
            } else if let reasoning = delta["reasoning"] as? String, !reasoning.isEmpty {
                onThinking(reasoning)
            }
            if let piece = delta["content"] as? String, !piece.isEmpty {
                full += piece
                onDelta(piece)
            }
        }
        // ChatGPT 产品端的 Ultra 不一定映射到第三方 OpenAI 兼容接口。
        // 若该接口仅结束流而未给出正文，降级为该接口普遍支持的 Max 重试一次。
        if full.isEmpty && reasoningEffort == "ultra" {
            return try await streamOpenAI(provider: provider,
                                          history: history,
                                          systemPrompt: systemPrompt,
                                          temperature: temperature,
                                          reasoningEffort: "max",
                                          onDelta: onDelta,
                                          onThinking: onThinking)
        }
        return full
    }

    // MARK: Anthropic

    private static func streamAnthropic(
        provider: APIProvider,
        history: [ChatMessage],
        systemPrompt: String,
        temperature: Double,
        reasoningEffort: String,
        onDelta: @escaping @Sendable (String) -> Void,
        onThinking: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let url = try anthropicMessagesURL(base: provider.baseURL)

        var payloadMessages: [[String: Any]] = []
        for m in history where m.role != .system && !m.isError {
            let role = m.role == .assistant ? "assistant" : "user"
            if m.role == .user {
                payloadMessages.append(["role": role,
                                        "content": userContent(for: m, anthropic: true)])
            } else {
                payloadMessages.append(["role": role, "content": m.content])
            }
        }
        guard !payloadMessages.isEmpty else { throw ChatClientError("消息为空") }

        var body: [String: Any] = [
            "model": provider.model,
            "max_tokens": 8192,
            "stream": true,
            "messages": payloadMessages,
        ]
        let sys = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sys.isEmpty { body["system"] = sys }
        body["temperature"] = temperature

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                         forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try await checkHTTP(response, bytes: bytes)

        var full = ""
        for try await rawLine in bytes.lines {
            try Task.checkCancellation()
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = obj["type"] as? String
            else { continue }
            switch type {
            case "content_block_delta":
                if let delta = obj["delta"] as? [String: Any],
                   let type = delta["type"] as? String {
                    if type == "thinking_delta",
                       let thinking = delta["thinking"] as? String, !thinking.isEmpty {
                        onThinking(thinking)
                    } else if type == "text_delta",
                              let text = delta["text"] as? String, !text.isEmpty {
                        full += text
                        onDelta(text)
                    }
                }
            case "error":
                let msg = (obj["error"] as? [String: Any])?["message"] as? String ?? "Anthropic 流式错误"
                throw ChatClientError(msg)
            case "message_stop":
                return full
            default:
                break
            }
        }
        return full
    }

    // MARK: 连接测试 (CCSwitch 风格)

    static func testConnection(_ provider: APIProvider) async throws -> String {
        switch provider.kind {
        case .openAICompatible:
            let url = try endpointURL(base: provider.baseURL, path: "/models")
            var request = URLRequest(url: url)
            let key = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            try checkHTTPData(response, data: data)
            let count = modelCount(data: data)
            return count > 0 ? "连接成功 · \(count) 个可用模型" : "连接成功"
        case .anthropic:
            let url = try anthropicModelsURL(base: provider.baseURL)
            var request = URLRequest(url: url)
            request.setValue(provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                             forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            try checkHTTPData(response, data: data)
            let count = modelCount(data: data)
            return count > 0 ? "连接成功 · \(count) 个可用模型" : "连接成功"
        }
    }

    // MARK: 模型列表拉取 (刷新按钮)

    /// 拉取提供商可用的模型列表 (OpenAI 兼容: GET /models; Anthropic: GET /v1/models)
    static func fetchModels(provider: APIProvider) async throws -> [String] {
        switch provider.kind {
        case .openAICompatible:
            let url = try endpointURL(base: provider.baseURL, path: "/models")
            var request = URLRequest(url: url)
            let key = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            try checkHTTPData(response, data: data)
            return modelIDs(data: data)
        case .anthropic:
            let url = try anthropicModelsURL(base: provider.baseURL)
            var request = URLRequest(url: url)
            request.setValue(provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                             forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            try checkHTTPData(response, data: data)
            return modelIDs(data: data)
        }
    }

    // MARK: 工具

    /// 构造单条用户消息的 content: 无附件 → 字符串;
    /// 含图片 → OpenAI 兼容 image_url 块 / Anthropic image 块的数组,
    /// 文本文件内容并入 text 块, 二进制文件以提示文字标注。
    private static func userContent(for message: ChatMessage, anthropic: Bool) -> Any {
        var textParts: [String] = []
        if !message.content.isEmpty { textParts.append(message.content) }
        var imageBlocks: [[String: Any]] = []

        for att in message.attachments {
            switch att.kind {
            case .text:
                if let text = att.textContent, !text.isEmpty {
                    textParts.append("【文件: \(att.name)】\n\(text)")
                }
            case .image:
                let b64 = att.data.base64EncodedString()
                if anthropic {
                    imageBlocks.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": att.mediaType,
                            "data": b64,
                        ],
                    ])
                } else {
                    imageBlocks.append([
                        "type": "image_url",
                        "image_url": ["url": "data:\(att.mediaType);base64,\(b64)"],
                    ])
                }
            case .binary:
                textParts.append("【已附加二进制文件: \(att.name)（\(att.sizeDisplay)），内容无法作为文本发送】")
            }
        }

        let joinedText = textParts.joined(separator: "\n\n")
        if imageBlocks.isEmpty {
            return joinedText
        }

        var blocks: [[String: Any]] = []
        if !joinedText.isEmpty {
            blocks.append(["type": "text", "text": joinedText])
        }
        blocks.append(contentsOf: imageBlocks)
        return blocks
    }

    private static func modelIDs(data: Data) -> [String] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["data"] as? [[String: Any]] else { return [] }
        return arr.compactMap { $0["id"] as? String }
    }

    private static func modelCount(data: Data) -> Int {
        modelIDs(data: data).count
    }

    private static func normalizedBase(_ base: String) throws -> String {
        var b = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !b.isEmpty else { throw ChatClientError("请先填写 Base URL") }
        while b.hasSuffix("/") { b.removeLast() }
        guard b.hasPrefix("http://") || b.hasPrefix("https://") else {
            throw ChatClientError("Base URL 需以 http:// 或 https:// 开头")
        }
        return b
    }

    private static func endpointURL(base: String, path: String) throws -> URL {
        let b = try normalizedBase(base)
        guard let url = URL(string: b + path) else { throw ChatClientError("无效的 URL: \(b + path)") }
        return url
    }

    private static func anthropicMessagesURL(base: String) throws -> URL {
        let b = try normalizedBase(base)
        let suffix = b.hasSuffix("/v1") ? "/messages" : "/v1/messages"
        guard let url = URL(string: b + suffix) else { throw ChatClientError("无效的 URL: \(b + suffix)") }
        return url
    }

    private static func anthropicModelsURL(base: String) throws -> URL {
        let b = try normalizedBase(base)
        let suffix = b.hasSuffix("/v1") ? "/models" : "/v1/models"
        guard let url = URL(string: b + suffix) else { throw ChatClientError("无效的 URL: \(b + suffix)") }
        return url
    }

    private static func checkHTTP(_ response: URLResponse, bytes: URLSession.AsyncBytes) async throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard http.statusCode >= 400 else { return }
        var snippet = ""
        for try await line in bytes.lines {
            snippet += line
            if snippet.count > 4000 { break }
        }
        throw ChatClientError("HTTP \(http.statusCode): \(extractErrorMessage(snippet) ?? "请求失败")")
    }

    private static func checkHTTPData(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard http.statusCode >= 400 else { return }
        let snippet = String(data: data.prefix(4000), encoding: .utf8) ?? ""
        throw ChatClientError("HTTP \(http.statusCode): \(extractErrorMessage(snippet) ?? "请求失败")")
    }

    private static func extractErrorMessage(_ snippet: String) -> String? {
        guard let data = snippet.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return String(snippet.prefix(300)) }
        if let err = obj["error"] as? [String: Any], let msg = err["message"] as? String {
            return msg
        }
        if let err = obj["error"] as? String { return err }
        if let msg = obj["message"] as? String { return msg }
        return String(snippet.prefix(300))
    }
}
