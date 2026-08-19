import SwiftUI

public struct SearchBarView: View {
    @Binding public var query: String
    @Binding public var exactImageTextOnly: Bool
    public var onSearch: () -> Void
    public var onClear: () -> Void

    public init(
        query: Binding<String>,
        exactImageTextOnly: Binding<Bool>,
        onSearch: @escaping () -> Void,
        onClear: @escaping () -> Void = {}
    ) {
        self._query = query
        self._exactImageTextOnly = exactImageTextOnly
        self.onSearch = onSearch
        self.onClear = onClear
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: exactImageTextOnly ? "text.viewfinder" : "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(
                    exactImageTextOnly ? "Enter the exact phrase shown in the image…" : "Describe the image you want to find…",
                    text: $query
                )
                    .textFieldStyle(.plain)
                    .onSubmit { onSearch() }
                if !query.isEmpty {
                    Button(action: { query = ""; onClear() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button("Search", action: onSearch)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Toggle(isOn: $exactImageTextOnly) {
                Label("Exact image text", systemImage: "text.viewfinder")
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .help("Only return images whose transcription contains this exact phrase, ignoring case")
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
