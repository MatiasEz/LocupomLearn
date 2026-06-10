import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: SongLibraryStore
    @State private var isShowingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if store.songs.isEmpty {
                    ContentUnavailableView {
                        Label("Sin canciones", systemImage: "music.note")
                    } description: {
                        Text("Agrega un video de YouTube, pega la letra y marca los tiempos para practicar.")
                    } actions: {
                        Button {
                            isShowingEditor = true
                        } label: {
                            Label("Agregar cancion", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(store.songs) { song in
                            NavigationLink {
                                SongDetailView(songID: song.id)
                            } label: {
                                SongRow(song: song)
                            }
                        }
                        .onDelete(perform: store.delete)
                    }
                }
            }
            .navigationTitle("Locupom")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingEditor = true
                    } label: {
                        Label("Agregar", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingEditor) {
                SongEditorView(song: nil)
            }
        }
    }
}

private struct SongRow: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(song.displayTitle)
                .font(.headline)
                .lineLimit(1)

            Text(song.displaySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                Label("\(song.lines.count) lineas", systemImage: "text.quote")
                Label("\(song.practiceStats.correct)/\(song.practiceStats.attempts)", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LibraryView()
        .environmentObject(SongLibraryStore.preview)
}
