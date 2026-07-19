import AppKit
import SwiftUI

struct MainView: View {
    @ObservedObject var state: AppState
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: state.snapshot.mode.symbol).foregroundStyle(state.snapshot.mode.color)
                        Text(state.snapshot.ssid).font(.headline).lineLimit(1)
                    }
                    HStack {
                        Text(state.snapshot.mode.rawValue)
                        Spacer()
                        Text(state.snapshot.ip)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    HStack {
                        Label(state.snapshot.download, systemImage: "arrow.down")
                        Spacer()
                        Label(state.snapshot.upload, systemImage: "arrow.up")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .padding(10)
                List(SidebarItem.allCases, selection: $selection) {
                    Label($0.rawValue, systemImage: $0.icon).tag($0)
                }
                .listStyle(.sidebar)
                Button { NSApplication.shared.terminate(nil) } label: {
                    Label("退出应用", systemImage: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding()
            }
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard: DashboardView(state: state)
            case .profiles: ProfilesView(state: state)
            case .logs: LogsView(state: state)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .sheet(item: $state.editorRoute) { route in
            switch route.context {
            case .currentWiFi:
                CurrentWiFiSetupSheet(state: state, profile: route.profile)
            case .library:
                ProfileEditor(
                    state: state,
                    profile: route.profile,
                    canApplyNow: route.profile.ssid == state.snapshot.ssid,
                    onSave: { profile in
                        state.save(profile)
                    },
                    onSaveAndApply: { profile in
                        state.save(profile)
                        state.apply(profile: profile, automatic: false)
                    }
                )
            }
        }
    }
}
