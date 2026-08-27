import Foundation
import CryptoKit

/// GitHub Raw JSON 授权文件校验：账号、密码哈希与本机 HWID 必须同时匹配。
enum AccessAuthorization {
    static let accessURL = URL(string: "https://raw.githubusercontent.com/hellokerenqian0744-crypto/longchat-access/main/access.json")!

    struct AccessFile: Decodable {
        let users: [User]
    }

    struct User: Decodable {
        let account: String
        let passwordHash: String
        let hwids: [String]
    }

    static func currentHWID() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        task.arguments = ["-rd1", "-c", "IOPlatformExpertDevice"]
        let pipe = Pipe()
        task.standardOutput = pipe
        guard (try? task.run()) != nil else { return "" }
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let pattern = #"\"IOPlatformUUID\"\s*=\s*\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else { return "" }
        return String(output[range]).uppercased()
    }

    static func verify(account: String, password: String) async -> Result<Void, AccessError> {
        let normalizedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        let hwid = currentHWID()
        guard !normalizedAccount.isEmpty, !password.isEmpty else { return .failure(.invalidCredentials) }
        guard !hwid.isEmpty else { return .failure(.unavailableHWID) }

        var request = URLRequest(url: accessURL)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let access = try? JSONDecoder().decode(AccessFile.self, from: data) else {
            return .failure(.unavailableList)
        }

        let hash = passwordHash(account: normalizedAccount, password: password)
        guard let user = access.users.first(where: { $0.account.caseInsensitiveCompare(normalizedAccount) == .orderedSame }),
              user.passwordHash.caseInsensitiveCompare(hash) == .orderedSame else {
            return .failure(.invalidCredentials)
        }
        guard user.hwids.map({ $0.uppercased() }).contains(hwid) else { return .failure(.unregisteredDevice) }
        return .success(())
    }

    static func passwordHash(account: String, password: String) -> String {
        let source = "GlassChat|\(account.lowercased())|\(password)"
        return SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum AccessError: LocalizedError {
    case invalidCredentials, unavailableHWID, unavailableList, unregisteredDevice

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "账号或密码不正确"
        case .unavailableHWID: return "无法读取本机设备标识"
        case .unavailableList: return "无法连接授权服务"
        case .unregisteredDevice: return "此设备未登记"
        }
    }
}
