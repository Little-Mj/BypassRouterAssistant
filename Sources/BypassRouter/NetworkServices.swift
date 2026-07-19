import Foundation
import CoreWLAN
import SystemConfiguration
import Darwin

enum Shell {
    static func run(_ executable: String, _ arguments: [String]) -> (String, Int32) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", process.terminationStatus)
        } catch {
            return (error.localizedDescription, -1)
        }
    }
}

enum NetworkReader {
    static func read() -> NetworkBase {
        let interface = wifiInterface()
        let ssid = currentSSID(interface: interface)
        let summary = interface == "—" ? "" : Shell.run("/usr/sbin/ipconfig", ["getsummary", interface]).0
        let connectionID = value(after: "ConnectionID :", in: summary) ?? "—"
        let service = currentService(interface: interface)
        let info = service == "—" ? "" : Shell.run("/usr/sbin/networksetup", ["-getinfo", service]).0
        let mode: NetworkMode = info.contains("Manual Configuration") ? .bypass : (info.contains("DHCP Configuration") ? .dhcp : .unknown)
        let ip = value(after: "IP address:", in: info) ?? Shell.run("/usr/sbin/ipconfig", ["getifaddr", interface]).0.nilIfEmpty ?? "—"
        let subnet = value(after: "Subnet mask:", in: info) ?? "—"
        let gateway = value(after: "Router:", in: info) ?? "—"
        let dnsOutput = service == "—" ? "" : Shell.run("/usr/sbin/networksetup", ["-getdnsservers", service]).0
        let dns = dnsOutput.contains("aren't any DNS") ? "自动获取" : (dnsOutput.nilIfEmpty ?? "—")
        return NetworkBase(
            ssid: ssid,
            interface: interface,
            connectionID: connectionID,
            service: service,
            mode: mode,
            ip: ip,
            subnet: subnet,
            gateway: gateway,
            dns: dns
        )
    }

    static func interfaceBytes(_ interface: String) -> (UInt64, UInt64) {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return (0, 0) }
        defer { freeifaddrs(pointer) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            let data = item.pointee
            if String(cString: data.ifa_name) == interface, let raw = data.ifa_data {
                let stats = raw.assumingMemoryBound(to: if_data.self).pointee
                return (UInt64(stats.ifi_ibytes), UInt64(stats.ifi_obytes))
            }
            cursor = data.ifa_next
        }
        return (0, 0)
    }

    private static func wifiInterface() -> String {
        if let name = CWWiFiClient.shared().interface()?.interfaceName { return name }
        let output = Shell.run("/usr/sbin/networksetup", ["-listallhardwareports"]).0
        let lines = output.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() where line.contains("Wi-Fi") || line.contains("AirPort") {
            if index + 1 < lines.count, lines[index + 1].hasPrefix("Device: ") {
                return String(lines[index + 1].dropFirst(8))
            }
        }
        return "—"
    }

    private static func currentSSID(interface: String) -> String {
        if interface != "—", let ssid = CWWiFiClient.shared().interface(withName: interface)?.ssid(), !ssid.isEmpty { return ssid }
        let output = Shell.run("/usr/sbin/networksetup", ["-getairportnetwork", interface]).0
        if let range = output.range(of: "Current Wi-Fi Network: ") { return String(output[range.upperBound...]) }
        return "未读取到 SSID"
    }

    private static func currentService(interface: String) -> String {
        if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
           let id = global["PrimaryService"] as? String,
           let setup = SCDynamicStoreCopyValue(nil, "Setup:/Network/Service/\(id)" as CFString) as? [String: Any],
           let name = setup["UserDefinedName"] as? String {
            let routeInterface = value(after: "interface:", in: Shell.run("/sbin/route", ["-n", "get", "default"]).0)
            if routeInterface == interface { return name }
        }
        let output = Shell.run("/usr/sbin/networksetup", ["-listnetworkserviceorder"]).0
        let lines = output.components(separatedBy: .newlines)
        var candidate = ""
        for line in lines {
            if line.range(of: #"^\([0-9]+\) "#, options: .regularExpression) != nil {
                candidate = line.replacingOccurrences(of: #"^\([0-9]+\) \*?"#, with: "", options: .regularExpression)
            } else if line.contains("Device: \(interface)") {
                return candidate
            }
        }
        return "—"
    }

    private static func value(after key: String, in text: String) -> String? {
        text.components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(key) }
            .map { String($0.trimmingCharacters(in: .whitespaces).dropFirst(key.count)).trimmingCharacters(in: .whitespaces) }
    }
}
