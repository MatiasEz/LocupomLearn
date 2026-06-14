import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: SongLibraryStore
    @State private var isShowingEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                LocupomLearningBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Canciones")
                                .font(.system(size: 39, weight: .black, design: .rounded))
                                .foregroundStyle(LocupomTheme.ink)

                            Text("Guardá letras, marcá tiempos y practicá línea por línea.")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(LocupomTheme.ink.opacity(0.56))
                        }

                        if store.songs.isEmpty {
                            EmptySongLibraryCard {
                                isShowingEditor = true
                            }
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.songs) { song in
                                    NavigationLink {
                                        SongDetailView(songID: song.id)
                                    } label: {
                                        SongRow(song: song)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            if let index = store.songs.firstIndex(where: { $0.id == song.id }) {
                                                store.delete(at: IndexSet(integer: index))
                                            }
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                    }
                                }
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

private struct EmptySongLibraryCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(LocupomTheme.primary)
                .frame(width: 66, height: 66)
                .background(LocupomTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Sin canciones")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)

                Text("Agregá un video de YouTube, pegá la letra y marcá los tiempos para practicar.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Label("Agregar canción", systemImage: "plus")
                    .font(.system(size: 18, weight: .black, design: .rounded))
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

private struct SongRow: View {
    let song: Song

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(LocupomTheme.secondary)
                .frame(width: 60, height: 60)
                .background(LocupomTheme.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(song.displayTitle)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)
                    .lineLimit(1)

                Text(song.displaySubtitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.55))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label("\(song.lines.count) líneas", systemImage: "text.quote")
                    Label("\(song.practiceStats.correct)/\(song.practiceStats.attempts)", systemImage: "checkmark.circle")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(LocupomTheme.muted)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(LocupomTheme.muted.opacity(0.70))
        }
        .padding(16)
        .background(LocupomTheme.surface.opacity(0.98), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(SongLibraryStore.preview)
}
