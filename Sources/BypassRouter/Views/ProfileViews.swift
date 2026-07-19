import SwiftUI

struct CurrentWiFiSetupSheet: View {
    @ObservedObject var state: AppState
    @State var profile: WiFiProfile

    private var validation: String? { state.validationError(for: profile) }
    private var isEditing: Bool {
        state.matchingProfile?.mode == .bypass || state.snapshot.mode == .bypass
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: NetworkMode.bypass.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 52, height: 52)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(isEditing ? "修改 \(profile.ssid) 的旁路由配置" : "为 \(profile.ssid) 设置旁路由")
                        .font(.title2.bold())
                    Text(isEditing ? "修改后可直接保存并应用，不需要返回列表再次操作。" : "确认下面的参数，然后保存并立即应用。")
                        .foregroundStyle(.secondary)
                }
            }

            Form {
                LabeledContent("Wi-Fi", value: profile.ssid)
                TextField("静态 IP", text: $profile.ip)
                TextField("子网掩码", text: $profile.subnet)
                TextField("网关", text: $profile.gateway)
                TextField("DNS", text: $profile.dns)
                Toggle("以后连接到该 Wi-Fi 时自动应用", isOn: $profile.autoApply)
            }
            .formStyle(.grouped)

            if let validation {
                Label(validation, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Label("应用时 macOS 会请求管理员授权。", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("取消") { state.dismissEditor() }
                Spacer()
                Button("仅保存") {
                    state.saveCurrentWiFiSetup(profile, applyNow: false)
                }
                .disabled(validation != nil)
                Button("保存并应用") {
                    state.saveCurrentWiFiSetup(profile, applyNow: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
                .disabled(validation != nil)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

struct ProfileEditor: View {
    @ObservedObject var state: AppState
    @State var profile: WiFiProfile
    let canApplyNow: Bool
    let onSave: (WiFiProfile) -> Void
    let onSaveAndApply: (WiFiProfile) -> Void

    private var validation: String? { state.validationError(for: profile) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Wi-Fi 配置").font(.title2.bold())
            Form {
                TextField("Wi-Fi 名称（SSID）", text: $profile.ssid)
                Picker("连接模式", selection: $profile.mode) {
                    Text("旁路由").tag(NetworkMode.bypass)
                    Text("DHCP").tag(NetworkMode.dhcp)
                }
                .pickerStyle(.segmented)
                if profile.mode == .bypass {
                    TextField("静态 IP", text: $profile.ip)
                    TextField("子网掩码", text: $profile.subnet)
                    TextField("网关", text: $profile.gateway)
                    TextField("DNS", text: $profile.dns)
                }
                Toggle("连接到该 Wi-Fi 后自动应用", isOn: $profile.autoApply)
            }
            .formStyle(.grouped)
            if let validation {
                Label(validation, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { state.dismissEditor() }
                if canApplyNow {
                    Button("仅保存") {
                        onSave(profile)
                        state.dismissEditor()
                    }
                        .disabled(validation != nil)
                    Button("保存并应用") {
                        onSaveAndApply(profile)
                        state.dismissEditor()
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(validation != nil)
                } else {
                    Button("保存") {
                        onSave(profile)
                        state.dismissEditor()
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(validation != nil)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

struct ProfilesView: View {
    @ObservedObject var state: AppState
    @State private var deleting: WiFiProfile?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Wi-Fi 配置").font(.largeTitle.bold())
                Spacer()
                Button {
                    state.requestLibraryEditor(WiFiProfile(
                        ssid: state.snapshot.ssid == "未连接" || state.snapshot.ssid == "未读取到 SSID" ? "" : state.snapshot.ssid,
                        mode: .bypass
                    ))
                } label: {
                    Label("新建配置", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            if state.profiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.router").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text("还没有配置").font(.title2.bold())
                    Text("为常用 Wi-Fi 保存旁路由或 DHCP 设置").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(state.profiles) { profile in
                        HStack(spacing: 14) {
                            Image(systemName: profile.mode.symbol)
                                .font(.title2)
                                .foregroundStyle(profile.mode.color)
                                .frame(width: 32)
                            VStack(alignment: .leading) {
                                Text(profile.ssid).font(.headline)
                                Text(profile.mode == .bypass ? "\(profile.ip) · 网关 \(profile.gateway)" : "自动获取 IP 与 DNS")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if profile.autoApply {
                                Label("自动", systemImage: "bolt.fill").font(.caption).foregroundStyle(.orange)
                            }
                            if profile.ssid == state.snapshot.ssid {
                                Button("应用") { state.apply(profile: profile, automatic: false) }
                                    .disabled(state.isApplying)
                            } else {
                                Text("当前未连接").font(.caption).foregroundStyle(.tertiary)
                            }
                            Button { state.requestLibraryEditor(profile) } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .buttonStyle(.borderless)
                            Button { deleting = profile } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                            .help("删除配置")
                        }
                        .padding(.vertical, 7)
                    }
                    .onDelete(perform: state.deleteProfiles)
                }
            }
        }
        .alert("删除 Wi-Fi 配置？", isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) {
                if let deleting { state.deleteProfile(deleting) }
                deleting = nil
            }
        } message: {
            Text("将删除“\(deleting?.ssid ?? "")”的已保存配置。当前系统网络设置不会被修改。")
        }
    }
}
