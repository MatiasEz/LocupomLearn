import SwiftUI

struct TrendingView: View {
    @EnvironmentObject private var settings: YouTubeAPISettings

    @State private var videos: [TrendingVideo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingSettings = false
    @State private var selectedVideo: TrendingVideo?

    var body: some View {
        NavigationStack {
            ZStack {
                LocupomLearningBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            LocupomLogoMark(size: 42)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tendencias")
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundStyle(LocupomTheme.ink)

                                Text(settings.regionCode)
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(LocupomTheme.primary)
                            }

                            Spacer()

                            Button {
                                isShowingSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(LocupomTheme.ink)
                                    .frame(width: 44, height: 44)
                                    .background(LocupomTheme.surface.opacity(0.92), in: Circle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await loadTrending() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(LocupomTheme.primary)
                                    .frame(width: 44, height: 44)
                                    .background(LocupomTheme.surface.opacity(0.92), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(settings.apiKey.trimmed.isEmpty || isLoading)
                        }

                        if settings.apiKey.trimmed.isEmpty {
                            TrendingStateCard(
                                systemImage: "key.fill",
                                title: "Falta API key",
                                detail: "Agregá una API key de YouTube Data API para cargar videos populares de música.",
                                actionTitle: "Configurar YouTube",
                                actionImage: "gearshape.fill",
                                action: { isShowingSettings = true }
                            )
                        } else if isLoading && videos.isEmpty {
                            TrendingLoadingCard()
                        } else if videos.isEmpty {
                            TrendingStateCard(
                                systemImage: "music.note",
                                title: "Sin tendencias",
                                detail: errorMessage ?? "Tocá actualizar para consultar YouTube.",
                                actionTitle: "Actualizar",
                                actionImage: "arrow.clockwise",
                                action: { Task { await loadTrending() } }
                            )
                        } else {
                            VStack(spacing: 12) {
                                ForEach(videos) { video in
                                    TrendingVideoRow(video: video) {
                                        selectedVideo = video
                                    }
                                }
                            }
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
            .task {
                if !settings.apiKey.trimmed.isEmpty && videos.isEmpty {
                    await loadTrending()
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                YouTubeSettingsView()
            }
            .sheet(item: $selectedVideo) { video in
                SongEditorView(song: nil, seed: video.editorSeed)
            }
        }
    }

    private func loadTrending() async {
        guard !settings.apiKey.trimmed.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            videos = try await YouTubeTrendingService.fetchTrendingMusic(
                apiKey: settings.apiKey,
                regionCode: settings.regionCode
            )
        } catch {
            errorMessage = error.localizedDescription
            videos = []
        }

        isLoading = false
    }
}

private struct TrendingStateCard: View {
    let systemImage: String
    let title: String
    let detail: String
    let actionTitle: String
    let actionImage: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(LocupomTheme.primary)
                .frame(width: 66, height: 66)
                .background(LocupomTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)

                Text(detail)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Label(actionTitle, systemImage: actionImage)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [LocupomTheme.primary, LocupomTheme.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: LocupomTheme.primary.opacity(0.08), radius: 20, x: 0, y: 11)
    }
}

private struct TrendingLoadingCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(LocupomTheme.primary)

            Text("Cargando tendencias...")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(LocupomTheme.ink)

            Spacer()
        }
        .padding(20)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: LocupomTheme.primary.opacity(0.07), radius: 18, x: 0, y: 10)
    }
}

private struct TrendingVideoRow: View {
    let video: TrendingVideo
    let addAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: video.thumbnailURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 104, height: 72)
            .background(LocupomTheme.softSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)
                    .lineLimit(2)

                Text(video.channelTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.55))
                    .lineLimit(1)

                Button(action: addAction) {
                    Label("Usar", systemImage: "plus")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LocupomTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LocupomTheme.primary.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(LocupomTheme.surface.opacity(0.98), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
        }
    }
}

#Preview {
    TrendingView()
        .environmentObject(YouTubeAPISettings())
        .environmentObject(SongLibraryStore.preview)
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
