import SwiftUI

public struct ImageGridView: View {
    public let results: [SearchResult]
    @Binding public var selectedResult: SearchResult?
    public let thumbnailStore: ThumbnailStore

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

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
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(results) { result in
                    GridCell(
                        result: result,
                        isSelected: selectedResult?.id == result.id,
                        thumbnailStore: thumbnailStore
                    )
                    .onTapGesture {
                        selectedResult = result
                    }
                    .contextMenu {
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
                        Button("Copy File Path") {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result.resolvedURL.path, forType: .string)
                            #endif
                        }
                        if let desc = result.analysis?.description {
                            Button("Copy Description") {
                                #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(desc, forType: .string)
                                #endif
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct GridCell: View {
    let result: SearchResult
    let isSelected: Bool
    let thumbnailStore: ThumbnailStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color.secondary.opacity(0.1)
                if let thumb = thumbnailStore.thumbnail(
                    for: result.content?.hexSHA256 ?? result.asset.relativePath,
                    sourceURL: result.resolvedURL
                ) {
                    #if os(macOS)
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #endif
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 140)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            Text(result.analysis?.shortTitle ?? (result.resolvedURL.lastPathComponent))
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if let desc = result.analysis?.description {
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityLabel(result.analysis?.shortTitle ?? result.resolvedURL.lastPathComponent)
    }
}
