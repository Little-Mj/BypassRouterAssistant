import SwiftUI

enum NetworkMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case bypass = "旁路由"
    case dhcp = "DHCP"
    case unknown = "未知"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .bypass: "point.3.connected.trianglepath.dotted"
        case .dhcp: "arrow.triangle.2.circlepath"
        case .unknown: "wifi.exclamationmark"
        }
    }
    var color: Color {
        switch self {
        case .bypass: .orange
        case .dhcp: .blue
        case .unknown: .secondary
        }
    }
}

struct WiFiProfile: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var ssid: String
    var mode: NetworkMode
    var ip = "192.168.5.188"
    var subnet = "255.255.255.0"
    var gateway = "192.168.5.202"
    var dns = "192.168.5.202"
    var autoApply = false
}

enum RecommendedAction: Sendable {
    case setupBypass
    case applyBypass(WiFiProfile)
    case restoreDHCP
    case unavailable
}

enum OperationState: Equatable, Sendable {
    case idle
    case applying(title: String, detail: String)
    case succeeded(title: String, detail: String)
    case failed(title: String, detail: String)

    var isApplying: Bool {
        if case .applying = self { return true }
        return false
    }

    var isVisible: Bool { self != .idle }
    var title: String {
        switch self {
        case .idle: ""
        case .applying(let title, _), .succeeded(let title, _), .failed(let title, _): title
        }
    }
    var detail: String {
        switch self {
        case .idle: ""
        case .applying(_, let detail), .succeeded(_, let detail), .failed(_, let detail): detail
        }
    }
}

enum ProfileEditorContext: Sendable {
    case currentWiFi
    case library
}

struct ProfileEditorRoute: Identifiable, Sendable {
    let id = UUID()
    let context: ProfileEditorContext
    let profile: WiFiProfile
}

struct NetworkSnapshot: Equatable, Sendable {
    var ssid = "正在检测…"
    var interface = "—"
    var connectionID = "—"
    var service = "—"
    var mode: NetworkMode = .unknown
    var ip = "—"
    var subnet = "—"
    var gateway = "—"
    var dns = "—"
    var download = "0 KB/s"
    var upload = "0 KB/s"
}

struct NetworkBase: Sendable {
    var ssid: String
    var interface: String
    var connectionID: String
    var service: String
    var mode: NetworkMode
    var ip: String
    var subnet: String
    var gateway: String
    var dns: String
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "概览"
    case profiles = "Wi-Fi 配置"
    case logs = "操作日志"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.50percent"
        case .profiles: "wifi.router"
        case .logs: "doc.text.magnifyingglass"
        }
    }
}
