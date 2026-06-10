import SwiftUI

struct YouTubeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: YouTubeAPISettings

    var body: some View {
        NavigationStack {
            Form {
                Section("YouTube Data API") {
                    SecureField("API key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Link("Crear API key en Google Cloud", destination: URL(string: "https://console.cloud.google.com/apis/library/youtube.googleapis.com")!)
                }

                Section("Tendencias") {
                    Picker("Region", selection: $settings.regionCode) {
                        ForEach(YouTubeAPISettings.supportedRegions) { region in
                            Text(region.name).tag(region.code)
                        }
                    }
                }
            }
            .navigationTitle("YouTube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    YouTubeSettingsView()
        .environmentObject(YouTubeAPISettings())
}
