import Foundation

@MainActor
final class AppLogStore {
    let fileURL: URL
    private(set) var lines: [String] = []

    init() {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/旁路由助手", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("运行日志.log")
        rotateIfNeeded()
        loadRecent()
    }

    @discardableResult
    func append(_ message: String) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)"
        lines.insert(line, at: 0)
        if lines.count > 300 { lines.removeLast(lines.count - 300) }
        guard let data = (line + "\n").data(using: .utf8) else { return lines }
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        }
        return lines
    }

    func clear() -> [String] {
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        lines = []
        return append("日志已清除")
    }

    private func rotateIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? NSNumber, size.intValue > 2_000_000 else { return }
        let oldURL = fileURL.deletingLastPathComponent().appendingPathComponent("运行日志.old.log")
        try? FileManager.default.removeItem(at: oldURL)
        try? FileManager.default.moveItem(at: fileURL, to: oldURL)
    }

    private func loadRecent() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        lines = text.split(separator: "\n").suffix(300).reversed().map(String.init)
    }
}
