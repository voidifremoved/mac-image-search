import SwiftUI

public struct MainContentView: View {
    private enum LibraryDestination: Hashable {
        case all
        case recent
        case folder(UUID)
        case category(String)
    }

    @ObservedObject public var env: AppEnvironment
    @State private var query = ""
    @State private var exactImageTextOnly = false
    @State private var searchResults: [SearchResult] = []
    @State private var selectedResult: SearchResult?
    @State private var destination: LibraryDestination?
    @State private var categories: [CategorySummary] = []
    @State private var indexProgress: IndexProgress = .idle
    @State private var isLoading = false
    @State private var searchError: String?
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    @State private var lastCategoryRefreshCount = -1

    public init(env: AppEnvironment) {
        self.env = env
    }

    public var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } content: {
            mainContent.navigationSplitViewColumnWidth(min: 420, ideal: 700)
        } detail: {
            InspectorView(result: selectedResult, thumbnailStore: env.thumbnailStore)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: rescan) { Image(systemName: "arrow.clockwise") }
                    .help("Rescan Folders")
                    .disabled(indexProgress.state == .scanning)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showingSettings = true }) { Image(systemName: "gear") }
                    .help("Settings")
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView(env: env) }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(env: env) {
                showingOnboarding = false
                startIndexing()
            }
        }
        .onAppear(perform: handleFirstAppearance)
        .task { await monitorIndexing() }
        .onChange(of: destination) { _, newValue in
            guard let newValue else { return }
            browse(newValue)
        }
    }

    private var sidebar: some View {
        List(selection: $destination) {
            Section("Library") {
                Label("All Images", systemImage: "photo.stack").tag(LibraryDestination.all)
                Label("Recent", systemImage: "clock").tag(LibraryDestination.recent)
            }

            if !categories.isEmpty {
                Section("Categories") {
                    ForEach(categories) { category in
                        HStack {
                            Label(category.name, systemImage: "tag")
                            Spacer()
                            Text(category.imageCount, format: .number)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .tag(LibraryDestination.category(category.name))
                    }
                }
            }

            Section("Watched Folders") {
                let folders = (try? env.folderRepo.getAll()) ?? []
                ForEach(folders) { folder in
                    Label(folder.displayName, systemImage: "folder")
                        .tag(LibraryDestination.folder(folder.id))
                }
                Button(action: addFolder) { Label("Add Folder…", systemImage: "plus.circle") }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
            }

            Section {
                IndexProgressView(
                    progress: indexProgress,
                    onPause: { Task { await env.coordinator.pause() } },
                    onResume: { Task { await env.coordinator.resume() } }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            SearchBarView(
                query: $query,
                exactImageTextOnly: $exactImageTextOnly,
                onSearch: performSearch,
                onClear: {
                    destination = nil
                    clearResults()
                }
            )
            .padding(12)
            Divider()

            Group {
                if isLoading {
                    ProgressView("Searching your library…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let searchError {
                    ContentUnavailableView("Search Failed", systemImage: "exclamationmark.magnifyingglass", description: Text(searchError))
                } else if searchResults.isEmpty {
                    emptyContent
                } else {
                    VStack(spacing: 0) {
                        resultHeader
                        ImageGridView(results: searchResults, selectedResult: $selectedResult, thumbnailStore: env.thumbnailStore)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || destination != nil {
            ContentUnavailableView(
                "No Matching Images",
                systemImage: "photo.badge.magnifyingglass",
                description: Text("Try a broader description or choose another category.")
            )
        } else {
            VStack(spacing: 20) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                VStack(spacing: 8) {
                    Text("Search your image library").font(.title2.weight(.semibold))
                    Text("Describe a scene, object, color, or text in an image.\nOr choose a category in the sidebar to browse.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    suggestion("sunset at the beach")
                    suggestion("screenshots with invoices")
                    suggestion("red car in snow")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
        }
    }

    private var resultHeader: some View {
        HStack {
            Text(resultTitle).font(.headline)
            Spacer()
            Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var resultTitle: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let prefix = exactImageTextOnly ? "Exact text" : "Results"
            return "\(prefix) for “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”"
        }
        switch destination {
        case .category(let name): return name
        case .folder(let id): return ((try? env.folderRepo.getAll()) ?? []).first(where: { $0.id == id })?.displayName ?? "Folder"
        case .recent: return "Recent Images"
        case .all: return "All Images"
        case nil: return "Results"
        }
    }

    private func suggestion(_ text: String) -> some View {
        Button(text) {
            query = text
            performSearch()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func handleFirstAppearance() {
        refreshCategories()
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let folders = (try? env.folderRepo.getAll()) ?? []
        if !hasCompleted && folders.isEmpty {
            showingOnboarding = true
        } else {
            startIndexing()
        }
    }

    private func startIndexing() {
        Task {
            do { try await env.coordinator.start() }
            catch { AppLogger.indexing.error("Could not start indexing: \(error.localizedDescription)") }
        }
    }

    private func monitorIndexing() async {
        while !Task.isCancelled {
            let snapshot = await env.coordinator.progressSnapshot()
            indexProgress = snapshot
            if snapshot.processedCount != lastCategoryRefreshCount {
                lastCategoryRefreshCount = snapshot.processedCount
                refreshCategories()
                if let destination, query.isEmpty {
                    browse(destination, showsLoading: false, preservesSelection: true)
                }
            }
            try? await Task.sleep(for: .milliseconds(350))
        }
    }

    private func performSearch() {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { clearResults(); return }
        destination = nil
        isLoading = true
        searchError = nil
        Task {
            do {
                searchResults = try await env.searchService.search(
                    query: cleanQuery,
                    filter: SearchFilter(exactImageTextOnly: exactImageTextOnly),
                    limit: 100
                )
                selectedResult = nil
            } catch {
                searchResults = []
                searchError = error.localizedDescription
                AppLogger.search.error("Search error: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    private func browse(
        _ destination: LibraryDestination,
        showsLoading: Bool = true,
        preservesSelection: Bool = false
    ) {
        query = ""
        if showsLoading { isLoading = true }
        searchError = nil
        Task {
            do {
                let refreshedResults: [SearchResult]
                switch destination {
                case .all:
                    refreshedResults = try await env.searchService.browse(filter: SearchFilter(), limit: 100)
                case .recent:
                    refreshedResults = try await env.searchService.getRecent(limit: 100)
                case .folder(let folderID):
                    refreshedResults = try await env.searchService.browse(filter: SearchFilter(folderID: folderID), limit: 100)
                case .category(let category):
                    refreshedResults = try await env.searchService.browse(filter: SearchFilter(category: category), limit: 100)
                }
                searchResults = refreshedResults
                selectedResult = ResultSelectionPolicy.selectionAfterRefresh(
                    current: selectedResult,
                    refreshedResults: refreshedResults,
                    preservesSelection: preservesSelection
                )
            } catch {
                searchResults = []
                searchError = error.localizedDescription
            }
            if showsLoading { isLoading = false }
        }
    }

    private func clearResults() {
        searchResults = []
        selectedResult = nil
        searchError = nil
        isLoading = false
    }

    private func refreshCategories() {
        categories = (try? env.searchService.categorySummaries(limit: 24)) ?? []
    }

    private func rescan() {
        Task {
            do { try await env.coordinator.scanAllFolders() }
            catch { AppLogger.indexing.error("Rescan failed: \(error.localizedDescription)") }
        }
    }

    private func addFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls { _ = try? env.folderAccessStore.addFolder(url: url, recursive: true) }
            rescan()
        }
        #endif
    }
}

enum ResultSelectionPolicy {
    static func selectionAfterRefresh(
        current: SearchResult?,
        refreshedResults: [SearchResult],
        preservesSelection: Bool
    ) -> SearchResult? {
        guard preservesSelection, let current else { return nil }
        // Prefer the refreshed value so newly available analysis/metadata appears in
        // the inspector. If filtering or a result limit moved the row off-screen, keep
        // the existing selection rather than making the detail pane disappear.
        return refreshedResults.first(where: { $0.id == current.id }) ?? current
    }
}
