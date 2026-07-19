import SwiftUI

struct StatusPill: View {
    let mode: NetworkMode

    var body: some View {
        Label(mode.rawValue, systemImage: mode.symbol)
            .font(.callout.weight(.semibold))
            .foregroundStyle(mode.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(mode.color.opacity(0.12), in: Capsule())
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct OperationFeedbackView: View {
    @ObservedObject var state: AppState

    private var icon: String {
        switch state.operation {
        case .idle: ""
        case .applying: "hourglass"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch state.operation {
        case .idle, .applying: .accentColor
        case .succeeded: .green
        case .failed: .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.operation.title).font(.headline)
                Text(state.operation.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if state.isApplying {
                ProgressView().controlSize(.small)
            } else if case .failed = state.operation {
                Button("重试") { state.performRecommendedAction() }
                    .disabled(state.isApplying)
            }
        }
        .padding(14)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}
