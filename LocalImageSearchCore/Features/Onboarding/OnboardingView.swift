import SwiftUI

public struct OnboardingView: View {
    @ObservedObject public var env: AppEnvironment
    public var onComplete: () -> Void

    @State private var apiKey: String = ""

    public init(env: AppEnvironment, onComplete: @escaping () -> Void) {
        self.env = env
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Welcome to Local Image Search")
                    .font(.title)
                    .bold()
                Text("Find photos and screenshots using natural language. Your catalog and vector database stay 100% on your Mac.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("AI Provider Setup (OpenRouter)").font(.headline)
                SecureField("Enter your OpenRouter or OpenAI API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        if let key = try? env.secretStore.getSecret(forKey: env.providerConfig.apiKeyIdentifier) {
                            apiKey = key
                        }
                    }
                    .onChange(of: apiKey) { _, newKey in
                        try? env.secretStore.setSecret(newKey, forKey: env.providerConfig.apiKeyIdentifier)
                    }

                Text("Image previews are downsampled and metadata-stripped before analysis.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)

            HStack {
                Button("Choose Folder...") {
                    #if os(macOS)
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = true
                    if panel.runModal() == .OK {
                        for url in panel.urls {
                            _ = try? env.folderAccessStore.addFolder(url: url, recursive: true)
                        }
                    }
                    #endif
                }

                Spacer()

                Button("Get Started") {
                    try? env.secretStore.setSecret(apiKey, forKey: env.providerConfig.apiKeyIdentifier)
                    env.providerConfig.saveToUserDefaults()
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 480, height: 420)
    }
}
