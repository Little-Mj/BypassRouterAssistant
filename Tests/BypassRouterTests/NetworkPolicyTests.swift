import XCTest
@testable import BypassRouter

@MainActor
final class NetworkPolicyTests: XCTestCase {
    private func snapshot(mode: NetworkMode = .dhcp) -> NetworkSnapshot {
        NetworkSnapshot(
            ssid: "Office",
            interface: "en0",
            service: "Wi-Fi",
            mode: mode,
            ip: mode == .bypass ? "192.168.5.188" : "192.168.5.100",
            subnet: "255.255.255.0",
            gateway: "192.168.5.202",
            dns: mode == .bypass ? "192.168.5.202" : "自动获取"
        )
    }

    func testDHCPWithoutProfileRequiresSetup() {
        guard case .setupBypass = NetworkPolicy.recommendedAction(snapshot: snapshot(), matchingProfile: nil) else {
            return XCTFail("DHCP without a profile should start setup")
        }
    }

    func testDHCPWithProfileAppliesSavedConfiguration() {
        let profile = WiFiProfile(ssid: "Office", mode: .bypass)
        guard case .applyBypass(let selected) = NetworkPolicy.recommendedAction(snapshot: snapshot(), matchingProfile: profile) else {
            return XCTFail("Saved bypass profile should be applied")
        }
        XCTAssertEqual(selected.id, profile.id)
    }

    func testAppliedBypassOffersDHCP() {
        let profile = WiFiProfile(ssid: "Office", mode: .bypass)
        guard case .restoreDHCP = NetworkPolicy.recommendedAction(snapshot: snapshot(mode: .bypass), matchingProfile: profile) else {
            return XCTFail("Applied bypass mode should offer DHCP")
        }
    }

    func testDriftedBypassReappliesProfile() {
        var current = snapshot(mode: .bypass)
        current.gateway = "192.168.5.1"
        let profile = WiFiProfile(ssid: "Office", mode: .bypass)
        guard case .applyBypass = NetworkPolicy.recommendedAction(snapshot: current, matchingProfile: profile) else {
            return XCTFail("Drifted settings should reapply the profile")
        }
    }

    func testEditingDraftUsesCurrentManualConfiguration() {
        let draft = NetworkPolicy.editingDraft(snapshot: snapshot(mode: .bypass), matchingProfile: nil)
        XCTAssertEqual(draft?.ip, "192.168.5.188")
        XCTAssertEqual(draft?.gateway, "192.168.5.202")
    }

    func testValidationRejectsNonContiguousMask() {
        var profile = WiFiProfile(ssid: "Office", mode: .bypass)
        profile.subnet = "255.0.255.0"
        XCTAssertNotNil(NetworkPolicy.validationError(for: profile))
    }

    func testDNSMatchRequiresACompleteAddress() {
        var current = snapshot(mode: .bypass)
        current.dns = "192.168.5.202"
        var profile = WiFiProfile(ssid: "Office", mode: .bypass)
        profile.dns = "192.168.5.20"
        XCTAssertFalse(NetworkPolicy.isApplied(profile, to: current))
    }

    func testDHCPWithManualDNSIsNotFullyApplied() {
        var current = snapshot(mode: .dhcp)
        current.dns = "8.8.8.8"
        let profile = WiFiProfile(ssid: "Office", mode: .dhcp)
        XCTAssertFalse(NetworkPolicy.isApplied(profile, to: current))
    }

    func testUpsertPreventsDuplicateSSID() {
        let first = WiFiProfile(ssid: "Office", mode: .dhcp)
        let replacement = WiFiProfile(ssid: "Office", mode: .bypass)
        let result = ProfileRepository.upserting(replacement, into: [first])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.mode, .bypass)
    }
}
