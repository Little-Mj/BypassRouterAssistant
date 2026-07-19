import SwiftUI

struct DashboardView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.snapshot.ssid).font(.largeTitle.bold())
                        Text("\(state.snapshot.service) · \(state.snapshot.interface)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(mode: state.snapshot.mode)
                }
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 12) {
                    MetricCard(title: "IP 地址", value: state.snapshot.ip, icon: "network")
                    MetricCard(title: "网关", value: state.snapshot.gateway, icon: "point.bottomleft.forward.to.point.topright.scurvepath")
                    MetricCard(title: "DNS", value: state.snapshot.dns, icon: "server.rack")
                    MetricCard(title: "下载速度", value: state.snapshot.download, icon: "arrow.down.circle", color: .green)
                    MetricCard(title: "上传速度", value: state.snapshot.upload, icon: "arrow.up.circle", color: .purple)
                    MetricCard(title: "子网掩码", value: state.snapshot.subnet, icon: "rectangle.split.3x1")
                }
                RecommendedActionCard(state: state)
                if state.operation.isVisible {
                    OperationFeedbackView(state: state)
                }
            }
            .padding(24)
        }
    }
}

private struct RecommendedActionCard: View {
    @ObservedObject var state: AppState

    private var canEditCurrentConfiguration: Bool {
        switch state.recommendedAction {
        case .applyBypass, .restoreDHCP: true
        case .setupBypass, .unavailable: false
        }
    }

    private var presentation: (eyebrow: String, title: String, detail: String, button: String, icon: String, color: Color, enabled: Bool) {
        switch state.recommendedAction {
        case .setupBypass:
            ("开始设置", "为 \(state.snapshot.ssid) 配置旁路由", "确认静态 IP、网关和 DNS，保存后立即应用。", "设置旁路由", NetworkMode.bypass.symbol, .orange, true)
        case .applyBypass(let profile):
            ("下一步", "应用已保存的旁路由配置", "将使用 \(profile.ip)，网关与 DNS 为 \(profile.gateway) / \(profile.dns)。", "应用配置", NetworkMode.bypass.symbol, .orange, true)
        case .restoreDHCP:
            ("当前已启用旁路由", "需要恢复自动网络配置吗？", "切换后 IP 与 DNS 将重新由当前网络自动分配。", "恢复 DHCP", NetworkMode.dhcp.symbol, .blue, true)
        case .unavailable:
            ("暂时不可操作", "正在等待可用的 Wi-Fi", "连接 Wi-Fi 并允许读取网络名称后即可继续。", "等待网络", "wifi.exclamationmark", .gray, false)
        }
    }

    var body: some View {
        let item = presentation
        HStack(spacing: 18) {
            Image(systemName: item.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(item.color)
                .frame(width: 54, height: 54)
                .background(item.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.eyebrow).font(.caption.weight(.semibold)).foregroundStyle(item.color)
                Text(item.title).font(.title3.weight(.semibold))
                Text(item.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    state.performRecommendedAction()
                } label: {
                    Label(item.button, systemImage: item.icon).frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(item.color)
                .disabled(!item.enabled || state.isApplying)
                if canEditCurrentConfiguration {
                    Button(state.matchingProfile?.mode == .bypass ? "编辑已保存配置" : "调整当前旁路由参数") {
                        state.requestCurrentWiFiSetup()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .disabled(state.isApplying)
                }
            }
        }
        .padding(18)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
    }
}
