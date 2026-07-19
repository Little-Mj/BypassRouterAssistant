import Foundation

enum NetworkConfigurationError: LocalizedError, Sendable {
    case missingHelper
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingHelper: "缺少网络配置组件，请重新安装应用"
        case .commandFailed(let message): message
        }
    }
}

struct NetworkConfigurationService: Sendable {
    let helperPath: String
    let logPath: String

    func apply(
        _ profile: WiFiProfile,
        to service: String,
        interface: String,
        expectedConnectionID: String
    ) async -> Result<String, NetworkConfigurationError> {
        guard FileManager.default.isExecutableFile(atPath: helperPath) else { return .failure(.missingHelper) }
        let arguments = [
            helperPath,
            profile.mode.rawValue,
            service,
            interface,
            expectedConnectionID,
            profile.ip,
            profile.subnet,
            profile.gateway,
            profile.dns,
            logPath
        ]
        let command = arguments.map(Self.shellQuote).joined(separator: " ")
        let appleScript = "do shell script \(Self.appleScriptQuote(command)) with administrator privileges"
        let result = await Task.detached(priority: .userInitiated) {
            Shell.run("/usr/bin/osascript", ["-e", appleScript])
        }.value
        if result.1 == 0 { return .success(result.0) }
        return .failure(.commandFailed(result.0.nilIfEmpty ?? "未知错误；已尝试恢复切换前配置"))
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
