import SwiftUI

public struct InspectorView: View {
    public let result: SearchResult?
    public let thumbnailStore: ThumbnailStore

    public init(result: SearchResult?, thumbnailStore: ThumbnailStore) {
        self.result = result
        self.thumbnailStore = thumbnailStore
    }

    public var body: some View {
        if let result {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preview
                    if let thumb = thumbnailStore.thumbnail(
                        for: result.content?.hexSHA256 ?? result.asset.relativePath,
                        sourceURL: result.resolvedURL,
                        maxPixelSize: 600
                    ) {
                        #if os(macOS)
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        #endif
                    }

                    // Title & Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.analysis?.shortTitle ?? result.resolvedURL.lastPathComponent)
                            .font(.headline)
                        if let desc = result.analysis?.description {
                            Text(desc)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Categories & Tags
                    if let categories = result.analysis?.categories, !categories.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Categories").font(.subheadline).bold()
                            FlowLayout(items: categories) { cat in
                                Text(cat)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Objects
                    if let objects = result.analysis?.objects, !objects.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Objects").font(.subheadline).bold()
                            FlowLayout(items: objects) { obj in
                                Text(obj)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Visible Text
                    if let text = result.analysis?.visibleText, !text.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Full Text Transcription").font(.subheadline).bold()
                                Spacer()
                                Button {
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(text, forType: .string)
                                    #endif
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            }
                            Text(text)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }

                    Divider()

                    // File Metadata
                    VStack(alignment: .leading, spacing: 4) {
                        Text("File Details").font(.subheadline).bold()
                        Text("Path: \(result.resolvedURL.path)").font(.caption2).foregroundColor(.secondary)
                        Text("Size: \(ByteCountFormatter.string(fromByteCount: result.asset.fileSize, countStyle: .file))").font(.caption2)
                        if let w = result.asset.pixelWidth, let h = result.asset.pixelHeight {
                            Text("Dimensions: \(w) × \(h) px").font(.caption2)
                        }
                    }

                    // Actions
                    HStack {
                        Button("Reveal in Finder") {
                            #if os(macOS)
                            NSWorkspace.shared.activateFileViewerSelecting([result.resolvedURL])
                            #endif
                        }
                        Button("Open") {
                            #if os(macOS)
                            NSWorkspace.shared.open(result.resolvedURL)
                            #endif
                        }
                    }
                }
                .padding(16)
            }
            .frame(minWidth: 260)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No Image Selected")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
