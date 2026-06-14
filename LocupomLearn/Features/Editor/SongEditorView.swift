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
            ZStack {
                LocupomLearningBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        editorHeader

                        EditorCard(title: "Datos", systemImage: "music.mic") {
                            VStack(spacing: 12) {
                                editorTextField("Título", text: $title, autocapitalization: .words)
                                editorTextField("Artista", text: $artist, autocapitalization: .words)
                                editorTextField("Idioma", text: $language, autocapitalization: .words)
                            }
                        }

                        EditorCard(title: "Video", systemImage: "play.rectangle.fill") {
                            VStack(alignment: .leading, spacing: 14) {
                                editorTextField("URL o ID de YouTube", text: $youtubeInput, autocapitalization: .never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)

                                if let videoID {
                                    YouTubePlayerView(videoID: videoID, command: $command, onEvent: handlePlayerEvent)
                                        .aspectRatio(16 / 9, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(LocupomTheme.ink.opacity(0.08), lineWidth: 1)
                                        }

                                    HStack {
                                        Label(formatTime(currentTime), systemImage: "timer")
                                            .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                                            .foregroundStyle(LocupomTheme.muted)

                                        Spacer()

                                        Button {
                                            command = .play()
                                        } label: {
                                            Image(systemName: "play.fill")
                                        }
                                        .buttonStyle(EditorIconButtonStyle(isPrimary: true))

                                        Button {
                                            command = .pause()
                                        } label: {
                                            Image(systemName: "pause.fill")
                                        }
                                        .buttonStyle(EditorIconButtonStyle(isPrimary: false))
                                    }
                                } else {
                                    Label("Pegá un link válido de YouTube para ver el reproductor.", systemImage: "link")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LocupomTheme.muted)
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }

                        EditorCard(title: "Letra", systemImage: "text.quote") {
                            VStack(alignment: .leading, spacing: 14) {
                                TextEditor(text: $lyricsText)
                                    .frame(minHeight: 170)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
                                    }

                                HStack(spacing: 10) {
                                    Button {
                                        Task { await importLyrics() }
                                    } label: {
                                        Label(isImportingLyrics ? "Buscando..." : "Importar", systemImage: "text.magnifyingglass")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(EditorPrimaryButtonStyle())
                                    .disabled(isImportingLyrics || title.trimmed.isEmpty)

                                    Button {
                                        generateLinesFromLyrics()
                                    } label: {
                                        Label("Generar", systemImage: "text.badge.plus")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(EditorSecondaryButtonStyle())
                                    .disabled(lyricsText.trimmed.isEmpty)
                                }

                                if isImportingLyrics {
                                    ProgressView()
                                        .tint(LocupomTheme.primary)
                                }

                                if let lyricsImportMessage {
                                    Label(lyricsImportMessage, systemImage: "info.circle")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LocupomTheme.muted)
                                }
                            }
                        }

                        EditorCard(title: "Tiempos", systemImage: "timer") {
                            VStack(alignment: .leading, spacing: 12) {
                                if draftLines.isEmpty {
                                    Text("Generá líneas desde la letra y después marcá inicio/fin mientras escuchás.")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LocupomTheme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    ForEach($draftLines) { $line in
                                        LineTimingRow(
                                            line: $line,
                                            currentTime: currentTime,
                                            seek: { command = .seek(to: line.startTime) }
                                        )
                                    }
                                }
                            }
                        }

                        if let validationMessage {
                            Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        Button {
                            saveAndPractice()
                        } label: {
                            Label("Guardar y practicar", systemImage: "gamecontroller.fill")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(EditorPrimaryButtonStyle())
                        .disabled(videoID == nil)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
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

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(LocupomTheme.muted)

                Spacer()

                Button("Guardar") {
                    save()
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(videoID == nil ? LocupomTheme.muted.opacity(0.60) : LocupomTheme.primary)
                .disabled(videoID == nil)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(song == nil ? "Nueva canción" : "Editar canción")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text("Prepará la letra y los tiempos para practicar con música.")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.56))
            }
        }
    }

    private func editorTextField(
        _ placeholder: String,
        text: Binding<String>,
        autocapitalization: TextInputAutocapitalization
    ) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(autocapitalization)
            .padding(14)
            .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
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

private struct EditorCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(LocupomTheme.ink)

            content()
        }
        .padding(18)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: LocupomTheme.primary.opacity(0.07), radius: 18, x: 0, y: 10)
    }
}

private struct EditorPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [LocupomTheme.primary, LocupomTheme.secondary]
                        : [Color.gray.opacity(0.45), Color.gray.opacity(0.36)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct EditorSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(isEnabled ? LocupomTheme.primary : LocupomTheme.muted.opacity(0.65))
            .padding(.vertical, 15)
            .background(LocupomTheme.primary.opacity(isEnabled ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct EditorIconButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .black))
            .foregroundStyle(isPrimary ? .white : LocupomTheme.primary)
            .frame(width: 44, height: 44)
            .background(isPrimary ? LocupomTheme.primary : LocupomTheme.primary.opacity(0.10), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

private struct LineTimingRow: View {
    @Binding var line: DraftLine
    let currentTime: TimeInterval
    let seek: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(line.text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(LocupomTheme.ink)
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
                .buttonStyle(EditorIconButtonStyle(isPrimary: false))

                TimeField(title: "Fin", value: $line.endTime)
                Button {
                    line.endTime = max(currentTime, line.startTime + 0.5)
                } label: {
                    Image(systemName: "flag.checkered")
                }
                .buttonStyle(EditorIconButtonStyle(isPrimary: false))

                Button(action: seek) {
                    Image(systemName: "gobackward")
                }
                .buttonStyle(EditorIconButtonStyle(isPrimary: true))
            }
        }
        .padding(14)
        .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TimeField: View {
    let title: String
    @Binding var value: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(LocupomTheme.muted)

            TextField(title, value: $value, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(LocupomTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(LocupomTheme.elevatedSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(minWidth: 58)
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
