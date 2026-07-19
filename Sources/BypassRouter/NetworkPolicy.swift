import Foundation

enum NetworkPolicy {
    static func recommendedAction(snapshot: NetworkSnapshot, matchingProfile: WiFiProfile?) -> RecommendedAction {
        guard isUsable(snapshot) else { return .unavailable }
        switch snapshot.mode {
        case .bypass:
            if let matchingProfile, matchingProfile.mode == .bypass, !isApplied(matchingProfile, to: snapshot) {
                return .applyBypass(matchingProfile)
            }
            return .restoreDHCP
        case .dhcp:
            if let matchingProfile, matchingProfile.mode == .bypass {
                return .applyBypass(matchingProfile)
            }
            return .setupBypass
        case .unknown:
            return .unavailable
        }
    }

    static func isApplied(_ profile: WiFiProfile, to snapshot: NetworkSnapshot) -> Bool {
        guard snapshot.mode == profile.mode else { return false }
        guard profile.mode == .bypass else { return snapshot.dns == "自动获取" }
        return snapshot.ip == profile.ip
            && snapshot.subnet == profile.subnet
            && snapshot.gateway == profile.gateway
            && dnsServers(in: snapshot.dns).contains(profile.dns)
    }

    static func editingDraft(snapshot: NetworkSnapshot, matchingProfile: WiFiProfile?) -> WiFiProfile? {
        guard isUsable(snapshot) else { return nil }
        if let matchingProfile, matchingProfile.mode == .bypass { return matchingProfile }
        if snapshot.mode == .bypass,
           isIPv4(snapshot.ip), isIPv4(snapshot.subnet), isIPv4(snapshot.gateway) {
            let firstDNS = snapshot.dns.replacingOccurrences(of: "\n", with: ",")
                .split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) }
            return WiFiProfile(
                ssid: snapshot.ssid,
                mode: .bypass,
                ip: snapshot.ip,
                subnet: snapshot.subnet,
                gateway: snapshot.gateway,
                dns: firstDNS.flatMap { isIPv4($0) ? $0 : nil } ?? "192.168.5.202"
            )
        }
        return WiFiProfile(ssid: snapshot.ssid, mode: .bypass)
    }

    static func validationError(for profile: WiFiProfile) -> String? {
        if profile.ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Wi-Fi 名称不能为空" }
        guard profile.mode == .bypass else { return nil }
        if !isIPv4(profile.ip) { return "静态 IP 格式不正确" }
        if !isIPv4(profile.subnet) { return "子网掩码格式不正确" }
        if !isContiguousMask(profile.subnet) { return "子网掩码必须由连续的 1 和 0 组成" }
        if !isIPv4(profile.gateway) { return "网关格式不正确" }
        if !isIPv4(profile.dns) { return "DNS 格式不正确" }
        return nil
    }

    static func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in
            guard !part.isEmpty, part.count <= 3, let number = Int(part) else { return false }
            return (0...255).contains(number)
        }
    }

    private static func isUsable(_ snapshot: NetworkSnapshot) -> Bool {
        snapshot.service != "—"
            && snapshot.interface != "—"
            && !["正在检测…", "未读取到 SSID", "未连接"].contains(snapshot.ssid)
    }

    private static func isContiguousMask(_ value: String) -> Bool {
        let numbers = value.split(separator: ".").compactMap { UInt32($0) }
        guard numbers.count == 4 else { return false }
        let mask = numbers.reduce(UInt32(0)) { ($0 << 8) | $1 }
        let inverted = ~mask
        return inverted == 0 || (inverted & (inverted &+ 1)) == 0
    }

    private static func dnsServers(in value: String) -> [String] {
        value.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
            .filter { !$0.isEmpty }
    }
}
