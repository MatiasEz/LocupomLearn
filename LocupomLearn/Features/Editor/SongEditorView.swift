import SwiftUI

struct SongEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SongLibraryStore

    let song: Song?

    @State private var title: String
    @State private var artist: String
    @State private var language: String
    @State private var youtubeInput: String
    @State private var lyricsText: String
    @State private var draftLines: [DraftLine]
    @State private var currentTime: TimeInterval = 0
    @State private var command: YouTubePlayerCommand?
    @State private var validationMessage: String?
    @State private var practiceSongID: UUID?
    @State private var isShowingPractice = false
    @State private var isImportingLyrics = false
    @State private var lyricsImportMessage: String?
    @State private var attemptedAutomaticLyricsImport = false

    init(song: Song?, seed: SongEditorSeed? = nil) {
        self.song = song
        _title = State(initialValue: song?.title ?? seed?.title ?? "")
        _artist = State(initialValue: song?.artist ?? seed?.artist ?? "")
        _language = State(initialValue: song?.language ?? seed?.language ?? "English")
        _youtubeInput = State(initialValue: song?.youtubeURL ?? seed?.youtubeInput ?? "")
        _lyricsText = State(initialValue: song?.sortedLines.map(\.text).joined(separator: "\n") ?? "")
        _draftLines = State(initialValue: song?.sortedLines.map(DraftLine.init(line:)) ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox("Datos") {
                        VStack(spacing: 12) {
                            TextField("Titulo", text: $title)
                                .textInputAutocapitalization(.words)
                            TextField("Artista", text: $artist)
                                .textInputAutocapitalization(.words)
                            TextField("Idioma", text: $language)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    GroupBox("Video") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("URL o ID de YouTube", text: $youtubeInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)

                            if let videoID {
                                YouTubePlayerView(videoID: videoID, command: $command, onEvent: handlePlayerEvent)
                                    .aspectRatio(16 / 9, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                HStack {
                                    Label(formatTime(currentTime), systemImage: "timer")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button {
                                        command = .play()
                                    } label: {
                                        Image(systemName: "play.fill")
                                    }
                                    .buttonStyle(.bordered)

                                    Button {
                                        command = .pause()
                                    } label: {
                                        Image(systemName: "pause.fill")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                Label("Pega un link valido de YouTube para ver el reproductor.", systemImage: "link")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    GroupBox("Letra") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextEditor(text: $lyricsText)
                                .frame(minHeight: 160)
                                .scrollContentBackground(.hidden)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                            HStack(spacing: 10) {
                                Button {
                                    Task { await importLyrics() }
                                } label: {
                                    Label(isImportingLyrics ? "Buscando..." : "Importar letra", systemImage: "text.magnifyingglass")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isImportingLyrics || title.trimmed.isEmpty)

                                Button {
                                    generateLinesFromLyrics()
                                } label: {
                                    Label("Generar lineas", systemImage: "text.badge.plus")
                                }
                                .buttonStyle(.bordered)
                                .disabled(lyricsText.trimmed.isEmpty)
                            }

                            if isImportingLyrics {
                                ProgressView()
                            }

                            if let lyricsImportMessage {
                                Label(lyricsImportMessage, systemImage: "info.circle")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    GroupBox("Tiempos") {
                        VStack(alignment: .leading, spacing: 14) {
                            if draftLines.isEmpty {
                                Text("Genera lineas desde la letra y despues marca inicio/fin mientras escuchas.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach($draftLines) { $line in
                                    LineTimingRow(
                                        line: $line,
                                        currentTime: currentTime,
                                        seek: { command = .seek(to: line.startTime) }
                                    )
                                    Divider()
                                }
                            }
                        }
                    }

                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Button {
                        saveAndPractice()
                    } label: {
                        Label("Guardar y practicar", systemImage: "gamecontroller")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(videoID == nil)
                }
                .padding()
            }
            .navigationTitle(song == nil ? "Nueva cancion" : "Editar cancion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(videoID == nil)
                }
            }
            .navigationDestination(isPresented: $isShowingPractice) {
                if let practiceSongID {
                    PracticeView(songID: practiceSongID)
                }
            }
            .task {
                await importLyricsAutomaticallyIfNeeded()
            }
        }
    }

    private var videoID: String? {
        YouTubeURLParser.videoID(from: youtubeInput)
    }

    private func handlePlayerEvent(_ event: YouTubePlayerEvent) {
        if case let .time(time) = event {
            currentTime = time
        }
    }

    private func generateLinesFromLyrics() {
        let lines = lyricsText
            .components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        draftLines = lines.enumerated().map { index, text in
            let start = Double(index) * 5
            return DraftLine(
                id: UUID(),
                text: text,
                startTime: start,
                endTime: start + 4.5
            )
        }
    }

    private func importLyricsAutomaticallyIfNeeded() async {
        guard !attemptedAutomaticLyricsImport else {
            return
        }

        attemptedAutomaticLyricsImport = true

        guard song == nil, lyricsText.trimmed.isEmpty, videoID != nil else {
            return
        }

        await importLyrics(isAutomatic: true)
    }

    @MainActor
    private func importLyrics(isAutomatic: Bool = false) async {
        guard !isImportingLyrics else {
            return
        }

        if isAutomatic && !lyricsText.trimmed.isEmpty {
            return
        }

        isImportingLyrics = true
        lyricsImportMessage = nil
        validationMessage = nil

        do {
            let imported = try await LyricsImportService().fetchBestMatch(title: title, artist: artist)

            title = imported.trackName
            artist = imported.artistName
            lyricsText = imported.plainText
            draftLines = imported.lines.enumerated().map { index, line in
                DraftLine(
                    id: UUID(),
                    text: line.text,
                    startTime: line.startTime,
                    endTime: line.endTime
                )
            }

            let timingText = imported.usedSyncedTimings ? "con tiempos sincronizados" : "con tramos de 5 segundos"
            lyricsImportMessage = "Letra importada: \(imported.artistName) - \(imported.trackName) (\(timingText))."
        } catch {
            if !isAutomatic {
                lyricsImportMessage = error.localizedDescription
            }
        }

        isImportingLyrics = false
    }

    @discardableResult
    private func save(dismissAfterSave: Bool = true) -> Song? {
        guard let videoID else {
            validationMessage = "El video de YouTube no parece valido."
            return nil
        }

        if draftLines.isEmpty {
            generateLinesFromLyrics()
        }

        guard !draftLines.isEmpty else {
            validationMessage = "Agrega al menos una linea de letra."
            return nil
        }

        let now = Date()
        let normalizedLines = draftLines.enumerated().map { index, draft in
            LyricLine(
                id: draft.existingLineID ?? UUID(),
                index: index,
                text: draft.text.trimmed,
                startTime: max(0, draft.startTime),
                endTime: max(draft.startTime + 0.5, draft.endTime)
            )
        }

        let savedSong = Song(
            id: song?.id ?? UUID(),
            title: title.trimmed.isEmpty ? "Sin titulo" : title.trimmed,
            artist: artist.trimmed,
            language: language.trimmed.isEmpty ? "Unknown" : language.trimmed,
            youtubeURL: youtubeInput.trimmed,
            videoID: videoID,
            lines: normalizedLines,
            createdAt: song?.createdAt ?? now,
            updatedAt: now,
            practiceStats: song?.practiceStats ?? .empty
        )

        store.upsert(savedSong)
        if dismissAfterSave {
            dismiss()
        }

        return savedSong
    }

    private func saveAndPractice() {
        guard let savedSong = save(dismissAfterSave: false) else {
            return
        }

        practiceSongID = savedSong.id
        isShowingPractice = true
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let minutes = Int(value) / 60
        let seconds = Int(value) % 60
        let tenths = Int((value - floor(value)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

private struct LineTimingRow: View {
    @Binding var line: DraftLine
    let currentTime: TimeInterval
    let seek: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(line.text)
                .font(.subheadline)
                .lineLimit(3)

            HStack(spacing: 8) {
                TimeField(title: "Inicio", value: $line.startTime)
                Button {
                    line.startTime = currentTime
                    if line.endTime <= line.startTime {
                        line.endTime = line.startTime + 4.5
                    }
                } label: {
                    Image(systemName: "flag")
                }
                .buttonStyle(.bordered)

                TimeField(title: "Fin", value: $line.endTime)
                Button {
                    line.endTime = max(currentTime, line.startTime + 0.5)
                } label: {
                    Image(systemName: "flag.checkered")
                }
                .buttonStyle(.bordered)

                Button(action: seek) {
                    Image(systemName: "gobackward")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TimeField: View {
    let title: String
    @Binding var value: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            TextField(title, value: $value, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 64)
        }
    }
}

private struct DraftLine: Identifiable {
    var id: UUID
    var existingLineID: UUID?
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval

    init(id: UUID, existingLineID: UUID? = nil, text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.id = id
        self.existingLineID = existingLineID
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }

    init(line: LyricLine) {
        id = line.id
        existingLineID = line.id
        text = line.text
        startTime = line.startTime
        endTime = line.endTime
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
