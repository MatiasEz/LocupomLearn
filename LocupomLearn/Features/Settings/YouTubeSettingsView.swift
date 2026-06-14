import SwiftUI

struct YouTubeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: YouTubeAPISettings

    var body: some View {
        NavigationStack {
            ZStack {
                LocupomLearningBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("YouTube")
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundStyle(LocupomTheme.ink)

                                Text("Conectá tendencias musicales para crear prácticas.")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LocupomTheme.ink.opacity(0.56))
                            }

                            Spacer()

                            Button("Listo") {
                                dismiss()
                            }
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(LocupomTheme.primary)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Label("YouTube Data API", systemImage: "key.fill")
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundStyle(LocupomTheme.ink)

                            SecureField("API key", text: $settings.apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Link(destination: URL(string: "https://console.cloud.google.com/apis/library/youtube.googleapis.com")!) {
                                Label("Crear API key en Google Cloud", systemImage: "arrow.up.right")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(LocupomTheme.primary)
                            }
                        }
                        .padding(18)
                        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Label("Tendencias", systemImage: "globe.americas.fill")
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundStyle(LocupomTheme.ink)

                            Picker("Región", selection: $settings.regionCode) {
                                ForEach(YouTubeAPISettings.supportedRegions) { region in
                                    Text(region.name).tag(region.code)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(LocupomTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(18)
                        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    YouTubeSettingsView()
        .environmentObject(YouTubeAPISettings())
}
