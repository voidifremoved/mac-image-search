import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var env: AppEnvironment
    @State private var apiKey: String = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    @State private var showSavedBanner = false
    @Environment(\.dismiss) private var dismiss

    public init(env: AppEnvironment) {
        self.env = env
    }

    public var body: some View {
        TabView {
            aiProviderTab
                .tabItem {
                    Label("AI Provider", systemImage: "sparkles")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .padding(20)
        .frame(width: 580, height: 520)
        .onAppear {
            if let key = try? env.secretStore.getSecret(forKey: env.providerConfig.apiKeyIdentifier) {
                apiKey = key
            }
        }
    }

    private var aiProviderTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Section {
                    Picker("Provider:", selection: $env.providerConfig.preset) {
                        Text("OpenRouter (Recommended)").tag(ProviderPreset.openRouter)
                        Text("Custom OpenAI-Compatible").tag(ProviderPreset.customOpenAICompatible)
                    }
                    .onChange(of: env.providerConfig.preset) { _, newPreset in
                        if newPreset == .openRouter {
                            env.providerConfig.baseURLString = AIProviderConfiguration.defaultOpenRouterBaseURL
                            if env.providerConfig.model.isEmpty {
                                env.providerConfig.model = "google/gemini-2.5-flash"
                            }
                        }
                    }

                    TextField("Base URL:", text: $env.providerConfig.baseURLString)

                    TextField("Model Name:", text: $env.providerConfig.model)

                    SecureField("API Key:", text: $apiKey)
                        .onChange(of: apiKey) { _, newKey in
                            try? env.secretStore.setSecret(newKey, forKey: env.providerConfig.apiKeyIdentifier)
                        }
                } header: {
                    Text("Endpoint & Credentials").bold()
                }

                Section {
                    Stepper("Max Concurrent Requests: \(env.providerConfig.maxParallelRequests)", value: $env.providerConfig.maxParallelRequests, in: 1...4)
                    Stepper("Request Timeout: \(Int(env.providerConfig.requestTimeout))s", value: $env.providerConfig.requestTimeout, in: 10...300, step: 10)
                } header: {
                    Text("Performance & Limits").bold()
                }
            }
            .formStyle(.grouped)

            // Bottom Action Area
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button(action: testConnection) {
                        if isTestingConnection {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Testing...")
                            }
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTestingConnection || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Save Configuration") {
                        saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)

                    if showSavedBanner {
                        Label("Saved successfully", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }

                    Spacer()

                    Button("Done") {
                        saveConfiguration()
                        dismiss()
                    }
                }

                if let connectionTestResult {
                    Text(connectionTestResult)
                        .font(.caption)
                        .foregroundColor(connectionTestResult.hasPrefix("Success") ? .green : .red)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(connectionTestResult.hasPrefix("Success") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(6)
                }

                Text("Privacy Notice: Only downsampled preview images with metadata stripped are sent to your configured API endpoint.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Watched Folders").bold()
            let folders = (try? env.folderRepo.getAll()) ?? []
            List(folders) { folder in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.displayName).font(.body).bold()
                        Text(folder.lastResolvedPath).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Remove") {
                        try? env.folderAccessStore.removeFolder(id: folder.id)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }
            .cornerRadius(8)

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding(8)
    }

    private func saveConfiguration() {
        env.providerConfig.saveToUserDefaults()
        try? env.secretStore.setSecret(apiKey, forKey: env.providerConfig.apiKeyIdentifier)
        showSavedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showSavedBanner = false
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil

        // Save current key before testing
        saveConfiguration()

        Task {
            do {
                _ = try env.providerConfig.validatedBaseURL()
                let client = OpenAICompatibleVisionClient(
                    configuration: env.providerConfig,
                    secretStore: env.secretStore
                )
                let testFixture = AnalysisPreviewBuilder.createValidTestJPEG()
                let response = try await client.analyze(testFixture)
                connectionTestResult = "Success: Model responded with title \"\(response.shortTitle)\""
            } catch {
                connectionTestResult = "Error: \(error.localizedDescription)"
            }
            isTestingConnection = false
        }
    }
}
