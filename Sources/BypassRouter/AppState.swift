import SwiftUI
import CoreLocation

@MainActor
final class AppState: NSObject, ObservableObject {
    @Published var snapshot = NetworkSnapshot()
    @Published var profiles: [WiFiProfile] = []
    @Published var logs: [String] = []
    @Published var operation: OperationState = .idle
    @Published var editorRoute: ProfileEditorRoute?

    private var timer: Timer?
    private var timerTicks = 0
    private var refreshInProgress = false
    private var lastBytes: (down: UInt64, up: UInt64, time: Date)?
    private var lastSSID = ""
    private var autoAppliedKey = ""
    private var feedbackDismissTask: Task<Void, Never>?
    private let locationManager = CLLocationManager()
    private let profileRepository: ProfileRepository
    private let logStore: AppLogStore
    private let configurationService: NetworkConfigurationService

    var logURL: URL { logStore.fileURL }
    var isApplying: Bool { operation.isApplying }
    var matchingProfile: WiFiProfile? { profiles.first { $0.ssid == snapshot.ssid } }
    var recommendedAction: RecommendedAction {
        NetworkPolicy.recommendedAction(snapshot: snapshot, matchingProfile: matchingProfile)
    }

    override init() {
        let repository = ProfileRepository()
        let logger = AppLogStore()
        let helperPath = Bundle.main.resourceURL?.appendingPathComponent("network-helper.sh").path ?? ""
        profileRepository = repository
        logStore = logger
        configurationService = NetworkConfigurationService(helperPath: helperPath, logPath: logger.fileURL.path)
        super.init()

        profiles = repository.load()
        logs = logger.lines
        locationManager.requestWhenInUseAuthorization()
        refreshFull()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        appendLog("应用启动（版本 \(version)）")
    }

    @objc private func timerFired() {
        timerTicks += 1
        updateSpeeds()
        if timerTicks.isMultiple(of: 5) { refreshFull() }
    }

    func refreshFull() {
        guard !refreshInProgress else { return }
        refreshInProgress = true
        Task { [weak self] in
            let base = await Task.detached(priority: .utility) { NetworkReader.read() }.value
            guard let self else { return }
            self.refreshInProgress = false
            self.snapshot.ssid = base.ssid
            self.snapshot.interface = base.interface
            self.snapshot.connectionID = base.connectionID
            self.snapshot.service = base.service
            self.snapshot.mode = base.mode
            self.snapshot.ip = base.ip
            self.snapshot.subnet = base.subnet
            self.snapshot.gateway = base.gateway
            self.snapshot.dns = base.dns

            if base.ssid != self.lastSSID {
                self.appendLog("Wi-Fi 变化：\(self.lastSSID.isEmpty ? "无" : self.lastSSID) → \(base.ssid)，服务=\(base.service)，网卡=\(base.interface)")
                self.lastSSID = base.ssid
                self.autoAppliedKey = ""
                self.lastBytes = nil
            }
            self.applyMatchingProfileIfNeeded()
        }
    }

    func quickApply(_ mode: NetworkMode) {
        let profile: WiFiProfile
        if mode == .bypass, let saved = matchingProfile, saved.mode == .bypass {
            profile = saved
        } else {
            profile = WiFiProfile(ssid: snapshot.ssid, mode: mode)
        }
        apply(profile: profile, automatic: false)
    }

    func performRecommendedAction() {
        switch recommendedAction {
        case .setupBypass:
            requestCurrentWiFiSetup()
        case .applyBypass(let profile):
            apply(profile: profile, automatic: false)
        case .restoreDHCP:
            quickApply(.dhcp)
        case .unavailable:
            break
        }
    }

    func requestCurrentWiFiSetup() {
        guard editorRoute == nil,
              let draft = NetworkPolicy.editingDraft(snapshot: snapshot, matchingProfile: matchingProfile) else { return }
        editorRoute = ProfileEditorRoute(context: .currentWiFi, profile: draft)
    }

    func requestLibraryEditor(_ profile: WiFiProfile) {
        guard editorRoute == nil else { return }
        editorRoute = ProfileEditorRoute(context: .library, profile: profile)
    }

    func dismissEditor() {
        editorRoute = nil
    }

    func saveCurrentWiFiSetup(_ profile: WiFiProfile, applyNow: Bool) {
        save(profile)
        dismissEditor()
        if applyNow {
            Task { @MainActor [weak self] in self?.apply(profile: profile, automatic: false) }
        }
    }

    func apply(profile: WiFiProfile, automatic: Bool) {
        guard !isApplying else { return }
        if let error = validationError(for: profile) {
            finish(.failed(title: "配置无效", detail: error))
            return
        }
        guard snapshot.service != "—", snapshot.interface != "—", snapshot.connectionID != "—" else {
            finish(.failed(title: "无法操作", detail: "没有检测到可用的 Wi-Fi 网络服务"))
            return
        }
        guard profile.ssid == snapshot.ssid || profile.ssid == "*" else {
            finish(.failed(title: "尚未连接该 Wi-Fi", detail: "请先连接 \(profile.ssid)，避免修改当前网络"))
            return
        }

        feedbackDismissTask?.cancel()
        operation = .applying(
            title: automatic ? "正在自动应用 \(profile.ssid)" : "正在切换到 \(profile.mode.rawValue)",
            detail: "等待系统管理员授权"
        )
        let service = snapshot.service
        let interface = snapshot.interface
        let expectedConnectionID = snapshot.connectionID
        appendLog("开始应用：SSID=\(snapshot.ssid)，服务=\(service)，模式=\(profile.mode.rawValue)")

        Task { [weak self, configurationService] in
            let result = await configurationService.apply(
                profile,
                to: service,
                interface: interface,
                expectedConnectionID: expectedConnectionID
            )
            guard let self else { return }
            switch result {
            case .success(let message):
                self.finish(.succeeded(title: "切换成功", detail: message.nilIfEmpty ?? "已应用 \(profile.mode.rawValue) 配置"))
            case .failure(let error):
                let detail = error.localizedDescription
                if detail.contains("User canceled") || detail.contains("-128") {
                    self.finish(.failed(title: "操作已取消", detail: "未修改网络设置"))
                } else {
                    self.finish(.failed(title: "切换失败", detail: detail))
                }
            }
            try? await Task.sleep(for: .seconds(1))
            self.refreshFull()
        }
    }

    func save(_ profile: WiFiProfile) {
        guard validationError(for: profile) == nil else { return }
        profiles = ProfileRepository.upserting(profile, into: profiles)
        profileRepository.save(profiles)
        appendLog("保存配置：SSID=\(profile.ssid.trimmingCharacters(in: .whitespacesAndNewlines))，模式=\(profile.mode.rawValue)，自动应用=\(profile.autoApply)")
    }

    func deleteProfiles(at offsets: IndexSet) {
        profiles.remove(atOffsets: offsets)
        profileRepository.save(profiles)
    }

    func deleteProfile(_ profile: WiFiProfile) {
        profiles.removeAll { $0.id == profile.id }
        profileRepository.save(profiles)
        appendLog("删除配置：SSID=\(profile.ssid)")
    }

    func clearLogs() {
        logs = logStore.clear()
    }

    func validationError(for profile: WiFiProfile) -> String? {
        NetworkPolicy.validationError(for: profile)
    }

    private func applyMatchingProfileIfNeeded() {
        guard let profile = matchingProfile, profile.autoApply else { return }
        let key = "\(profile.id.uuidString)-\(snapshot.ssid)"
        guard key != autoAppliedKey, !isApplying else { return }
        autoAppliedKey = key
        guard !NetworkPolicy.isApplied(profile, to: snapshot) else { return }
        apply(profile: profile, automatic: true)
    }

    private func updateSpeeds() {
        guard snapshot.interface != "—" else { return }
        let (down, up) = NetworkReader.interfaceBytes(snapshot.interface)
        let now = Date()
        defer { lastBytes = (down, up, now) }
        guard let previous = lastBytes else { return }
        let elapsed = max(now.timeIntervalSince(previous.time), 0.1)
        let downDelta = down >= previous.down ? down - previous.down : 0
        let upDelta = up >= previous.up ? up - previous.up : 0
        snapshot.download = formatRate(Double(downDelta) / elapsed)
        snapshot.upload = formatRate(Double(upDelta) / elapsed)
    }

    private func formatRate(_ bytes: Double) -> String {
        if bytes >= 1_048_576 { return String(format: "%.1f MB/s", bytes / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.0f KB/s", bytes / 1024) }
        return String(format: "%.0f B/s", bytes)
    }

    private func finish(_ state: OperationState) {
        feedbackDismissTask?.cancel()
        operation = state
        appendLog("\(state.title)：\(state.detail)")
        guard case .succeeded = state else { return }
        feedbackDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.operation = .idle
        }
    }

    private func appendLog(_ message: String) {
        logs = logStore.append(message)
    }
}
