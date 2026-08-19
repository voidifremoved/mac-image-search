import SwiftUI

public struct SearchBarView: View {
    @Binding public var query: String
    public var onSearch: () -> Void
    public var onClear: () -> Void

    public init(query: Binding<String>, onSearch: @escaping () -> Void, onClear: @escaping () -> Void = {}) {
        self._query = query
        self.onSearch = onSearch
        self.onClear = onClear
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Describe the image you want to find…", text: $query)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSearch()
                }
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
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
