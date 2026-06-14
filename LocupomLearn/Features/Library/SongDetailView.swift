import SwiftUI

struct SongDetailView: View {
    @EnvironmentObject private var store: SongLibraryStore
    let songID: UUID

    @State private var command: YouTubePlayerCommand?
    @State private var isShowingEditor = false

    var body: some View {
        Group {
            if let song = store.song(withID: songID) {
                ZStack {
                    LocupomLearningBackground()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(song.displayTitle)
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundStyle(LocupomTheme.ink)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.78)

                                Text(song.displaySubtitle)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LocupomTheme.ink.opacity(0.56))
                                    .lineLimit(2)
                            }

                            YouTubePlayerView(videoID: song.videoID, command: $command)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(LocupomTheme.ink.opacity(0.08), lineWidth: 1)
                                }
                                .shadow(color: LocupomTheme.primary.opacity(0.10), radius: 20, x: 0, y: 11)

                            HStack(spacing: 12) {
                                NavigationLink {
                                    PracticeView(songID: song.id)
                                } label: {
                                    Label("Practicar", systemImage: "play.fill")
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
                                .disabled(song.lines.isEmpty)

                                Button {
                                    isShowingEditor = true
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundStyle(LocupomTheme.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 15)
                                        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(LocupomTheme.primary.opacity(0.18), lineWidth: 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            }

                            StatsGrid(song: song)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Líneas")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(LocupomTheme.ink)

                                ForEach(song.sortedLines) { line in
                                    SongLinePreviewRow(line: line, formatTime: formatTime)
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                }
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
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
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
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
                .font(.system(size: 21, weight: .black))
                .frame(width: 42, height: 42)
                .foregroundStyle(LocupomTheme.primary)
                .background(LocupomTheme.primary.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(LocupomTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct SongLinePreviewRow: View {
    let line: LyricLine
    let formatTime: (TimeInterval) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(line.text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LocupomTheme.ink)
                .lineLimit(3)

            Text("\(formatTime(line.startTime)) - \(formatTime(line.endTime))")
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(LocupomTheme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.06), lineWidth: 1)
        }
    }
}
