import SwiftUI

/// Kept under its original name to avoid churn at call sites. Results are intentionally
/// presented as a compact list: titles and summaries need horizontal room more than
/// screenshots need large grid cells.
public struct ImageGridView: View {
    public let results: [SearchResult]
    @Binding public var selectedResult: SearchResult?
    public let thumbnailStore: ThumbnailStore

    public init(
        results: [SearchResult],
        selectedResult: Binding<SearchResult?>,
        thumbnailStore: ThumbnailStore
    ) {
        self.results = results
        self._selectedResult = selectedResult
        self.thumbnailStore = thumbnailStore
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results) { result in
                    ResultRow(
                        result: result,
                        isSelected: selectedResult?.id == result.id,
                        thumbnailStore: thumbnailStore
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectedResult = result }
                    .contextMenu { contextMenu(for: result) }

                    if result.id != results.last?.id {
                        Divider().padding(.leading, 132)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    @ViewBuilder
    private func contextMenu(for result: SearchResult) -> some View {
        Button("Reveal in Finder") {
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([result.resolvedURL])
            #endif
        }
        Button("Open Image") {
            #if os(macOS)
            NSWorkspace.shared.open(result.resolvedURL)
            #endif
        }
        Divider()
        Button("Copy File Path") {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.resolvedURL.path, forType: .string)
            #endif
        }
        if let summary = result.analysis?.description {
            Button("Copy Summary") {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(summary, forType: .string)
                #endif
            }
        }
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let thumbnailStore: ThumbnailStore

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(result.analysis?.shortTitle ?? result.resolvedURL.lastPathComponent)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let summary = result.analysis?.description, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Text(result.resolvedURL.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let categories = result.analysis?.categories, let first = categories.first {
                        Text(first.capitalized)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.quaternary)
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result.analysis?.shortTitle ?? result.resolvedURL.lastPathComponent)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(.quaternary)
            if let image = thumbnailStore.thumbnail(
                for: result.content?.hexSHA256 ?? result.asset.relativePath,
                sourceURL: result.resolvedURL,
                maxPixelSize: 240
            ) {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #endif
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 104, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(.separator.opacity(0.45), lineWidth: 1)
        }
    }
}
