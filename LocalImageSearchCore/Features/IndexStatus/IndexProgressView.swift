import SwiftUI

public struct IndexProgressView: View {
    public let progress: IndexProgress
    public let onPause: () -> Void
    public let onResume: () -> Void

    public init(progress: IndexProgress, onPause: @escaping () -> Void, onResume: @escaping () -> Void) {
        self.progress = progress
        self.onPause = onPause
        self.onResume = onResume
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: statusSymbol).foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(statusTitle).font(.subheadline.weight(.semibold))
                    Text(statusDetail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                if progress.state == .paused {
                    Button("Resume", action: onResume).controlSize(.small)
                } else if progress.state == .scanning || progress.state == .indexing {
                    Button("Pause", action: onPause).controlSize(.small)
                }
            }

            if progress.state == .scanning {
                ProgressView().progressViewStyle(.linear)
            } else if progress.totalJobCount > 0 {
                ProgressView(value: progress.fractionCompleted).progressViewStyle(.linear)
                HStack {
                    Text("\(progress.completedCount) analyzed")
                    if progress.failedCount > 0 {
                        Text("• \(progress.failedCount) failed").foregroundStyle(.red)
                    }
                    Spacer()
                    Text("\(progress.remainingCount) remaining")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI indexing progress, \(statusDetail)")
    }

    private var statusTitle: String {
        switch progress.state {
        case .scanning: "Finding images…"
        case .indexing: "AI image analysis"
        case .paused: "Analysis paused"
        case .idle where progress.remainingCount > 0: "Waiting to retry analysis"
        case .idle where progress.failedCount > 0: "Analysis finished with issues"
        case .idle: "Library is up to date"
        }
    }

    private var statusDetail: String {
        if let fileName = progress.currentFileName, progress.state == .indexing { return "Analyzing \(fileName)" }
        if progress.state == .scanning { return "Checking watched folders" }
        if progress.totalJobCount > 0 { return "\(progress.processedCount) of \(progress.totalJobCount) images processed" }
        return "\(progress.discoveredCount) images discovered"
    }

    private var statusSymbol: String {
        switch progress.state {
        case .scanning: "folder.badge.gearshape"
        case .indexing: "sparkles"
        case .paused: "pause.circle.fill"
        case .idle where progress.remainingCount > 0: "clock.arrow.circlepath"
        case .idle where progress.failedCount > 0: "exclamationmark.triangle.fill"
        case .idle: "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        if (progress.failedCount > 0 || progress.remainingCount > 0) && progress.state == .idle { return .orange }
        return progress.state == .idle ? .green : .accentColor
    }
}
