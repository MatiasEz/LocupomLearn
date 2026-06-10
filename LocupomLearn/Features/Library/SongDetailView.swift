import SwiftUI

struct SongDetailView: View {
    @EnvironmentObject private var store: SongLibraryStore
    let songID: UUID

    @State private var command: YouTubePlayerCommand?
    @State private var isShowingEditor = false

    var body: some View {
        Group {
            if let song = store.song(withID: songID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        YouTubePlayerView(videoID: song.videoID, command: $command)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.displayTitle)
                                .font(.title2.bold())
                            Text(song.displaySubtitle)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            NavigationLink {
                                PracticeView(songID: song.id)
                            } label: {
                                Label("Practicar", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(song.lines.isEmpty)

                            Button {
                                isShowingEditor = true
                            } label: {
                                Label("Editar", systemImage: "pencil")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        StatsGrid(song: song)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Lineas")
                                .font(.headline)

                            ForEach(song.sortedLines) { line in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(line.text)
                                        .lineLimit(2)
                                    Text("\(formatTime(line.startTime)) - \(formatTime(line.endTime))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Cancion")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $isShowingEditor) {
                    SongEditorView(song: song)
                }
            } else {
                ContentUnavailableView("Cancion no encontrada", systemImage: "questionmark.folder")
            }
        }
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let minutes = Int(value) / 60
        let seconds = Int(value) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct StatsGrid: View {
    let song: Song

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                StatCell(title: "Lineas", value: "\(song.lines.count)", systemImage: "text.quote")
                StatCell(title: "Intentos", value: "\(song.practiceStats.attempts)", systemImage: "number")
            }
            GridRow {
                StatCell(title: "Aciertos", value: "\(song.practiceStats.correct)", systemImage: "checkmark.circle")
                StatCell(title: "Precision", value: "\(Int(song.practiceStats.accuracy * 100))%", systemImage: "target")
            }
        }
    }
}

private struct StatCell: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
