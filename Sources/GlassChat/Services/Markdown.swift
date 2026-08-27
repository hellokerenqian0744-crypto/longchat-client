import Foundation

/// 消息内容的轻量 Markdown 分段。
///
/// 设计目标: 不引入第三方依赖, 把正文拆成「富文本段」与「代码块」两类,
/// 分别交给 SwiftUI 渲染。支持 ``` 围栏代码块(含语言标注)。
enum Markdown {

    enum Segment: Identifiable, Equatable {
        case text(String)
        case code(language: String?, source: String)

        var id: String {
            switch self {
            case .text(let s): return "text-\(s.hashValue)"
            case .code(let lang, let src): return "code-\(lang ?? "")-\(src.hashValue)"
            }
        }
    }

    /// 将 Markdown 原文切分为渲染段。
    static func segments(from raw: String) -> [Segment] {
        var result: [Segment] = []
        var textBuffer: [String] = []
        var codeBuffer: [String] = []
        var language: String?
        var inCodeBlock = false

        func flushText() {
            let joined = textBuffer.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                result.append(.text(joined))
            }
            textBuffer = []
        }

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    // 围栏结束
                    result.append(.code(language: language, source: codeBuffer.joined(separator: "\n")))
                    codeBuffer = []
                    language = nil
                    inCodeBlock = false
                } else {
                    // 围栏开始
                    flushText()
                    let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    language = lang.isEmpty ? nil : lang
                    inCodeBlock = true
                }
            } else if inCodeBlock {
                codeBuffer.append(line)
            } else {
                textBuffer.append(line)
            }
        }

        // 未闭合的代码块按代码处理, 剩余文本按文本处理
        if inCodeBlock {
            result.append(.code(language: language, source: codeBuffer.joined(separator: "\n")))
        }
        flushText()
        return result
    }
}
