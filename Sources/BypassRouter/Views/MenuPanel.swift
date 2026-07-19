import AppKit
import SwiftUI

struct MenuPanel: View {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    private var actionPresentation: (title: String, icon: String, color: Color, enabled: Bool, needsSetup: Bool) {
        switch state.recommendedAction {
        case .setupBypass:
            ("设置此 Wi-Fi", NetworkMode.bypass.symbol, .orange, true, true)
        case .applyBypass:
            ("应用旁路由配置", NetworkMode.bypass.symbol, .orange, true, false)
        case .restoreDHCP:
            ("恢复 DHCP", NetworkMode.dhcp.symbol, .blue, true, false)
        case .unavailable:
            ("等待网络", "wifi.exclamationmark", .gray, false, false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text(state.snapshot.ssid).font(.headline)
                    Text("\(state.snapshot.service) · \(state.snapshot.interface)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "wifi").font(.title2).foregroundStyle(.cyan)
            }

            Divider()
            HStack {
                Label(state.snapshot.download, systemImage: "arrow.down.circle")
                Spacer()
                Label(state.snapshot.upload, systemImage: "arrow.up.circle")
            }
            .font(.system(.body, design: .rounded, weight: .medium))
            .padding(.vertical, 2)
            Divider()

            VStack(spacing: 8) {
                ConfigRow(title: "IP 地址", value: state.snapshot.ip)
                ConfigRow(title: "子网掩码", value: state.snapshot.subnet)
                ConfigRow(title: "网关", value: state.snapshot.gateway)
                ConfigRow(title: "DNS", value: state.snapshot.dns)
            }
            .padding(12)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                let action = actionPresentation
                VStack(alignment: .leading, spacing: 5) {
                    Text("当前状态").font(.caption).foregroundStyle(.secondary)
                    StatusPill(mode: state.snapshot.mode)
                }
                Spacer()
                Button {
                    if action.needsSetup {
                        state.requestCurrentWiFiSetup()
                        openMainWindow()
                    } else {
                        state.performRecommendedAction()
                    }
                } label: {
                    Label(action.title, systemImage: action.icon).frame(minWidth: 126)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(action.color)
                .disabled(!action.enabled || state.isApplying)
            }

            if let profile = state.matchingProfile {
                HStack {
                    Label("已匹配 \(profile.mode.rawValue) 配置\(profile.autoApply ? " · 自动" : "")", systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("编辑") {
                        state.requestCurrentWiFiSetup()
                        openMainWindow()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            } else if state.snapshot.mode == .bypass {
                HStack {
                    Label("当前旁路由参数尚未保存", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("保存或修改") {
                        state.requestCurrentWiFiSetup()
                        openMainWindow()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }

            switch state.operation {
            case .idle:
                EmptyView()
            case .applying(let title, _):
                ProgressView(title).controlSize(.small)
            case .succeeded(let title, _):
                Label(title, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            case .failed(let title, _):
                Label(title, systemImage: "xmark.circle.fill").font(.caption).foregroundStyle(.red)
            }

            Divider()
            HStack {
                Button("打开控制中心") { openMainWindow() }
                Spacer()
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ConfigRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 18)
            Text(value.replacingOccurrences(of: "\n", with: ", "))
                .font(.system(.callout, design: .monospaced, weight: .medium))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
