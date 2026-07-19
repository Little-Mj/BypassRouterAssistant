import Foundation

@MainActor
final class ProfileRepository {
    private let defaults: UserDefaults
    private let key = "wifiProfiles.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [WiFiProfile] {
        guard let data = defaults.data(forKey: key),
              let profiles = try? JSONDecoder().decode([WiFiProfile].self, from: data) else { return [] }
        return profiles.sorted(by: Self.sort)
    }

    func save(_ profiles: [WiFiProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: key)
    }

    static func upserting(_ profile: WiFiProfile, into profiles: [WiFiProfile]) -> [WiFiProfile] {
        var result = profiles
        var normalized = profile
        normalized.ssid = normalized.ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        if let duplicate = result.first(where: { $0.ssid == normalized.ssid && $0.id != normalized.id }) {
            normalized.id = duplicate.id
            result.removeAll { $0.id == profile.id || $0.ssid == normalized.ssid }
            result.append(normalized)
        } else if let index = result.firstIndex(where: { $0.id == normalized.id }) {
            result[index] = normalized
        } else {
            result.append(normalized)
        }
        return result.sorted(by: sort)
    }

    private static func sort(_ lhs: WiFiProfile, _ rhs: WiFiProfile) -> Bool {
        lhs.ssid.localizedStandardCompare(rhs.ssid) == .orderedAscending
    }
}
