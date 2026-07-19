import AppKit
import SwiftUI

struct LogsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("操作日志").font(.largeTitle.bold())
                Spacer()
                Button("在访达中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([state.logURL])
                }
                Button("清除") { state.clearLogs() }
            }
            .padding(24)
            List(state.logs, id: \.self) {
                Text($0)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.vertical, 2)
            }
        }
    }
}
