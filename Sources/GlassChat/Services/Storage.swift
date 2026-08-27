import Foundation

/// 轻量级 JSON 持久化。
///
/// 数据保存在 `~/Library/Application Support/GlassChat/data.json`。
/// 不引入 CoreData/SwiftData, 方便阅读与二次开发。
enum Storage {

    static let appSupportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("GlassChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var dataFileURL: URL {
        appSupportDirectory.appendingPathComponent("data.json")
    }

    /// 读取全部数据; 文件不存在或损坏时返回空数据。
    static func load() -> AppData {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            return AppData()
        }
        do {
            let raw = try Data(contentsOf: dataFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppData.self, from: raw)
        } catch {
            NSLog("[GlassChat] 读取数据失败: \(error)")
            return AppData()
        }
    }

    /// 原子写入全部数据。
    static func save(_ data: AppData) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let raw = try encoder.encode(data)
            try raw.write(to: dataFileURL, options: .atomic)
        } catch {
            NSLog("[GlassChat] 保存数据失败: \(error)")
        }
    }
}
