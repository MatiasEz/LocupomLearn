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
            Group {
                if settings.apiKey.trimmed.isEmpty {
                    ContentUnavailableView {
                        Label("Falta API key", systemImage: "key")
                    } description: {
                        Text("Agrega una API key de YouTube Data API para cargar videos populares de musica.")
                    } actions: {
                        Button {
                            isShowingSettings = true
                        } label: {
                            Label("Configurar YouTube", systemImage: "gearshape")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if isLoading && videos.isEmpty {
                    ProgressView("Cargando tendencias...")
                } else if videos.isEmpty {
                    ContentUnavailableView {
                        Label("Sin tendencias", systemImage: "music.note")
                    } description: {
                        Text(errorMessage ?? "Toca actualizar para consultar YouTube.")
                    } actions: {
                        Button {
                            Task { await loadTrending() }
                        } label: {
                            Label("Actualizar", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(videos) { video in
                        TrendingVideoRow(video: video) {
                            selectedVideo = video
                        }
                    }
                    .refreshable {
                        await loadTrending()
                    }
                }
            }
            .navigationTitle("Tendencias")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("YouTube", systemImage: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadTrending() }
                    } label: {
                        Label("Actualizar", systemImage: "arrow.clockwise")
                    }
                    .disabled(settings.apiKey.trimmed.isEmpty || isLoading)
                }
            }
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

private struct TrendingVideoRow: View {
    let video: TrendingVideo
    let addAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
            .frame(width: 96, height: 54)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(video.channelTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button(action: addAction) {
                    Label("Usar", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
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
