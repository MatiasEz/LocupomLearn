import SwiftUI

struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SongLibraryStore
    @EnvironmentObject private var learningProgress: LearningProgressStore
    let songID: UUID

    @State private var currentIndex = 0
    @State private var mode: PracticeMode = .gated
    @State private var answer = ""
    @State private var letterInput = ""
    @State private var guessedKeys = Set<String>()
    @State private var wrongGuesses: [String] = []
    @State private var isRevealed = false
    @State private var feedback: PracticeFeedback?
    @State private var clozeHint: String?
    @State private var savedWordMessage: String?
    @State private var command: YouTubePlayerCommand?
    @State private var resultWasRecorded = false
    @State private var wrongClozeAttempts = 0
    @State private var contextualWord: String?
    @State private var contextualTranslation: TranslationResult?
    @State private var isTranslatingContextWord = false
    @State private var lineTranslation: TranslationResult?
    @State private var isTranslatingLine = false
    @State private var translatedLineID: UUID?
    @State private var lastFullLineAnswer = ""
    @State private var currentPlayerTime: TimeInterval = 0
    @State private var syncMessage: String?
    @State private var sessionCorrectCount = 0
    @State private var sessionMissCount = 0

    private let languageService = LanguageLearningService()
    private let maxWrongGuesses = 6
    private let ignoredLyricWords: Set<String> = [
        "ah", "ay", "ba", "da", "doo", "du", "dum", "eh", "ey", "ha", "hey",
        "hm", "hmm", "la", "mm", "mmm", "na", "nah", "oh", "ooh", "pa",
        "ra", "sha", "ta", "uh", "um", "wo", "woo", "ya", "yea", "yeah", "yo"
    ]
    private let optionColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        Group {
            if let song = store.song(withID: songID), !song.sortedLines.isEmpty {
                practiceContent(song: song)
            } else {
                ContentUnavailableView("No hay lineas para practicar", systemImage: "text.quote")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func practiceContent(song: Song) -> some View {
        let lines = song.sortedLines
        let line = lines[safe: currentIndex] ?? lines[0]
        let contextChallenge = clozeChallenge(for: line, lines: lines)

        return ZStack {
            MusicLessonBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MusicLessonHeader(
                        lessonNumber: currentIndex + 1,
                        totalLessons: lines.count,
                        hearts: max(0, 3 - sessionMissCount),
                        progress: progress(lines: lines),
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Learn with music")
                            .font(.title2.bold())
                            .foregroundStyle(MusicLessonTheme.ink)

                        Text("Listen and complete the missing word.")
                            .font(.subheadline)
                            .foregroundStyle(MusicLessonTheme.muted)
                    }

                    MusicSongPlayerCard(
                        song: song,
                        line: line,
                        progress: progress(lines: lines),
                        currentTimeText: formatTime(line.startTime),
                        durationText: formatTime(line.endTime),
                        player: {
                            YouTubePlayerView(videoID: song.videoID, command: $command, onEvent: handlePlayerEvent)
                                .aspectRatio(1, contentMode: .fill)
                        },
                        replayPrevious: {
                            movePrevious(total: lines.count)
                        },
                        play: {
                            replay(line)
                        },
                        replayNext: {
                            moveNext(total: lines.count)
                        }
                    )

                    MusicModeSelector(mode: $mode, level: songLevel)

                    switch mode {
                    case .gated:
                        musicClozeLessonPanel(
                            challenge: contextChallenge,
                            line: line,
                            lines: lines,
                            previousLine: lines[safe: currentIndex - 1],
                            nextLine: lines[safe: currentIndex + 1]
                        )
                    case .hangman:
                        MusicCard {
                            hangmanPanel(line: line, totalLines: lines.count)
                        }
                    case .fullLine:
                        MusicCard {
                            fullLinePanel(line: line, totalLines: lines.count)
                        }
                    }

                    SyncCalibrationPanel(
                        line: line,
                        currentTime: currentPlayerTime,
                        message: syncMessage,
                        shiftEarlier: { shiftSongTiming(by: -0.5, currentLine: line) },
                        alignToCurrentLine: { alignCurrentLineToPlayer(line) },
                        replay: { replay(line) },
                        shiftLater: { shiftSongTiming(by: 0.5, currentLine: line) }
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            if mode != .gated {
                mode = .gated
            }

            if let playableIndex = currentOrNextPracticeableIndex(from: currentIndex, lines: lines),
               playableIndex != currentIndex,
               let playableLine = lines[safe: playableIndex] {
                currentIndex = playableIndex
                resetRound()
                replay(playableLine)
            } else {
                replay(line)
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            if let nextLine = lines[safe: newIndex] {
                replay(nextLine)
            }
        }
        .task(id: line.id) {
            await translateLineIfNeeded(line)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: currentIndex)
        .animation(.easeInOut(duration: 0.2), value: feedback?.title)
    }

    private func musicClozeLessonPanel(
        challenge: ClozeChallenge?,
        line: LyricLine,
        lines: [LyricLine],
        previousLine: LyricLine?,
        nextLine: LyricLine?
    ) -> some View {
        MusicCard {
            VStack(alignment: .leading, spacing: 16) {
                if let challenge {
                    MusicLyricsPracticeCard(
                        challenge: challenge,
                        line: line,
                        previousLine: previousLine,
                        nextLine: nextLine,
                        selectedOption: answer,
                        isRevealed: isRevealed,
                        letterCount: songLevel.showsExtraHints ? challenge.targetWord.count : nil,
                        translation: translatedLineID == line.id ? lineTranslation?.translatedText : nil,
                        isTranslating: isTranslatingLine && translatedLineID == line.id,
                        optionAction: { option in
                            validateClozeOption(option, challenge: challenge, line: line, lines: lines)
                        }
                    )

                    MusicQuickActionsBar(
                        replay: { replay(line) },
                        slowMode: { replaySlow(line) },
                        translate: { Task { await translateLine(line) } }
                    )

                    if let clozeHint {
                        MusicInfoPill(text: clozeHint, systemImage: "lightbulb.fill", tint: .orange)
                    }

                    if let savedWordMessage {
                        MusicInfoPill(text: savedWordMessage, systemImage: "bookmark.fill", tint: MusicLessonTheme.mint)
                    }

                    if let feedback {
                        MusicFeedbackBanner(feedback: feedback)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    HStack(spacing: 10) {
                        if songLevel.showsExtraHints {
                            Button {
                                showClozeHint(challenge: challenge)
                            } label: {
                                Label("Hint", systemImage: "lightbulb")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MusicSmallButtonStyle())
                        }

                        Button {
                            saveClozeWord(challenge: challenge, line: line)
                        } label: {
                            Label("Save word", systemImage: "bookmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MusicSmallButtonStyle())
                    }

                    Button {
                        if feedback?.isCorrect == true || isRevealed {
                            advanceToNextLine(lines: lines)
                        } else {
                            replay(line)
                        }
                    } label: {
                        Text(feedback?.isCorrect == true || isRevealed ? "Next line" : "Replay line")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MusicPrimaryButtonStyle())

                    Text("Can't hear well? Try slow mode.")
                        .font(.caption)
                        .foregroundStyle(MusicLessonTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    MusicUnavailableLineCard(
                        lineText: line.text,
                        nextAction: { moveNext(total: lines.count) }
                    )
                }
            }
        }
    }

    private func replaySlow(_ line: LyricLine) {
        command = .setRate(0.75)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            command = .playSegment(start: line.startTime, end: line.endTime)
        }
    }

    private func handlePlayerEvent(_ event: YouTubePlayerEvent) {
        if case let .time(time) = event {
            currentPlayerTime = time
        }
    }

    private func gatedPanel(line: LyricLine, lines: [LyricLine]) -> some View {
        let challenge = clozeChallenge(for: line, lines: lines)

        return VStack(alignment: .leading, spacing: 14) {
            if let challenge {
                Text("Escucha el tramo y elegi la palabra que falta.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ClozeLineCard(
                    challenge: challenge,
                    selectedOption: answer,
                    isRevealed: isRevealed,
                    showsLetterCount: songLevel.showsExtraHints
                )

                HStack {
                    Label("\(formatTime(line.startTime)) - \(formatTime(line.endTime))", systemImage: "timer")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Avanza solo si acertas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let clozeHint {
                    Label(clozeHint, systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let savedWordMessage {
                    Label(savedWordMessage, systemImage: "bookmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: optionColumns, spacing: 10) {
                    ForEach(challenge.options, id: \.self) { option in
                        Button {
                            validateClozeOption(option, challenge: challenge, line: line, lines: lines)
                        } label: {
                            Text(option)
                                .font(.headline)
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(optionForeground(option, challenge: challenge))
                        .background(optionBackground(option, challenge: challenge), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(optionBorder(option, challenge: challenge), lineWidth: 1)
                        }
                        .disabled(isRevealed || feedback?.isCorrect == true)
                    }
                }

                if let feedback {
                    FeedbackView(feedback: feedback)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    PracticeCoachInsight(
                        feedback: feedback,
                        focusText: challenge.targetWord,
                        sourceLine: line.text,
                        modeTitle: mode.rawValue
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        replay(line)
                    } label: {
                        Label("Escuchar otra vez", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        revealCloze(challenge: challenge)
                    } label: {
                        Label("Mostrar", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 10) {
                    if songLevel.showsExtraHints {
                        Button {
                            showClozeHint(challenge: challenge)
                        } label: {
                            Label("Pista", systemImage: "lightbulb")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        saveClozeWord(challenge: challenge, line: line)
                    } label: {
                        Label("Guardar palabra", systemImage: "bookmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    moveNext(total: lines.count)
                } label: {
                    Label("Saltar palabra", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Text(line.text)
                    .font(.title3)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                ContentUnavailableView("No encontre una palabra para ocultar", systemImage: "text.badge.xmark")

                Button {
                    moveNext(total: lines.count)
                } label: {
                    Label("Siguiente tramo", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func hangmanPanel(line: LyricLine, totalLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(displayedHangmanText(for: line))
                .font(.title3.monospaced())
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Label("Errores \(wrongGuesses.count)/\(maxWrongGuesses)", systemImage: "xmark.circle")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(wrongGuesses.count >= maxWrongGuesses ? .red : .secondary)

                Spacer()

                if !wrongGuesses.isEmpty {
                    Text(wrongGuesses.map { $0.uppercased() }.joined(separator: " "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                TextField("Letra", text: $letterInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: letterInput) { _, newValue in
                        letterInput = String(newValue.suffix(1))
                    }
                    .onSubmit {
                        submitLetter(letterInput, line: line)
                    }

                Button {
                    submitLetter(letterInput, line: line)
                } label: {
                    Label("Probar", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(letterInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRoundFinished(for: line))
            }

            LetterKeyboardView(usedKeys: guessedKeys) { key in
                submitLetter(key, line: line)
            }
            .disabled(isRoundFinished(for: line))

            if let feedback {
                FeedbackView(feedback: feedback)
                    .transition(.move(edge: .top).combined(with: .opacity))
                PracticeCoachInsight(
                    feedback: feedback,
                    focusText: "letras de la linea",
                    sourceLine: line.text,
                    modeTitle: mode.rawValue
                )
                if !feedback.isCorrect && !lastFullLineAnswer.isEmpty {
                    PracticeWordDiffView(answer: lastFullLineAnswer, target: line.text)
                }
            }

            controlButtons(line: line, totalLines: totalLines, allowsHint: true)
        }
    }

    private func fullLinePanel(line: LyricLine, totalLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isRevealed ? line.text : maskedFullLineText(for: line.text))
                .font(.title3.monospaced())
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            TextEditor(text: $answer)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let feedback {
                FeedbackView(feedback: feedback)
                    .transition(.move(edge: .top).combined(with: .opacity))
                PracticeCoachInsight(
                    feedback: feedback,
                    focusText: "linea completa",
                    sourceLine: line.text,
                    modeTitle: mode.rawValue
                )
            }

            HStack(spacing: 10) {
                Button {
                    replay(line)
                } label: {
                    Label("Repetir", systemImage: "gobackward.10")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    checkFullLine(line: line)
                } label: {
                    Label("Validar", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            controlButtons(line: line, totalLines: totalLines, allowsHint: false)
        }
    }

    private func controlButtons(line: LyricLine, totalLines: Int, allowsHint: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                replay(line)
            } label: {
                Label("Repetir", systemImage: "gobackward.10")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if allowsHint && songLevel.showsExtraHints {
                Button {
                    revealHint(for: line)
                } label: {
                    Label("Pista", systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRoundFinished(for: line))
            }

            Button {
                reveal(line: line)
            } label: {
                Label("Revelar", systemImage: "eye")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                moveNext(total: totalLines)
            } label: {
                Label("Siguiente", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func replay(_ line: LyricLine) {
        command = .playSegment(start: line.startTime, end: line.endTime)
    }

    private func shiftSongTiming(by offset: TimeInterval, currentLine line: LyricLine) {
        store.shiftTimings(songID: songID, by: offset)
        syncMessage = offset < 0 ? "Letra adelantada 0.5s" : "Letra atrasada 0.5s"

        let startTime = max(0, line.startTime + offset)
        let duration = max(0.5, line.endTime - line.startTime)
        command = .playSegment(start: startTime, end: startTime + duration)
    }

    private func alignCurrentLineToPlayer(_ line: LyricLine) {
        let offset = currentPlayerTime - line.startTime
        store.shiftTimings(songID: songID, by: offset)
        syncMessage = String(format: "Linea alineada (%+.1fs)", offset)

        let duration = max(0.5, line.endTime - line.startTime)
        command = .playSegment(start: max(0, currentPlayerTime), end: max(0, currentPlayerTime) + duration)
    }

    private func submitLetter(_ rawValue: String, line: LyricLine) {
        let key = normalizedGuessKey(rawValue)
        letterInput = ""

        guard !key.isEmpty, !guessedKeys.contains(key), !isRoundFinished(for: line) else {
            return
        }

        guessedKeys.insert(key)

        if targetKeys(for: line).contains(key) {
            if isHangmanSolved(for: line) {
                feedback = PracticeFeedback(
                    title: "Correcto",
                    detail: "Coincide con la letra fuente.",
                    score: 1,
                    isCorrect: true
                )
                recordSessionPulse(wasCorrect: true)
                recordHangmanResult(wasCorrect: true)
            } else {
                feedback = PracticeFeedback(
                    title: "Bien",
                    detail: "La letra aparece en la linea.",
                    score: hangmanProgress(for: line),
                    isCorrect: true
                )
            }
        } else {
            wrongGuesses.append(key)

            if wrongGuesses.count >= maxWrongGuesses {
                isRevealed = true
                feedback = PracticeFeedback(
                    title: "A revisar",
                    detail: "Respuesta: \(line.text)",
                    score: hangmanProgress(for: line),
                    isCorrect: false
                )
                recordSessionPulse(wasCorrect: false)
                recordHangmanResult(wasCorrect: false)
            } else {
                feedback = PracticeFeedback(
                    title: "No esta",
                    detail: "Quedan \(maxWrongGuesses - wrongGuesses.count) errores.",
                    score: hangmanProgress(for: line),
                    isCorrect: false
                )
            }
        }
    }

    private func checkFullLine(line: LyricLine) {
        lastFullLineAnswer = answer
        let result = TextMatcher.evaluate(answer: answer, target: line.text)
        let title: String
        let detail: String

        if result.isCorrect {
            title = "Correcto"
            detail = "Coincide con la letra fuente."
        } else if result.isClose {
            title = "Casi"
            detail = "Hay diferencias con la letra fuente."
        } else {
            title = "A revisar"
            detail = "Respuesta: \(line.text)"
        }

        feedback = PracticeFeedback(title: title, detail: detail, score: result.similarity, isCorrect: result.isCorrect)
        store.recordAttempt(songID: songID, wasCorrect: result.isCorrect)
        learningProgress.recordModule("songs", wasCorrect: result.isCorrect)
        recordSessionPulse(wasCorrect: result.isCorrect)
        if result.isCorrect {
            learningProgress.recordErrorResolved(module: "songs", expected: line.text)
        } else {
            learningProgress.recordError(
                module: "songs",
                expected: line.text,
                actual: answer,
                context: "Linea completa"
            )
        }
    }

    private func validateClozeOption(_ option: String, challenge: ClozeChallenge, line: LyricLine, lines: [LyricLine]) {
        answer = option

        let result = TextMatcher.evaluate(answer: option, target: challenge.targetWord)
        guard result.isExact else {
            wrongClozeAttempts += 1
            recordSessionPulse(wasCorrect: false)
            store.recordAttempt(songID: songID, wasCorrect: false)
            learningProgress.recordModule("songs", wasCorrect: false)
            learningProgress.saveWord(word: challenge.targetWord, note: line.text, source: "Cancion")
            learningProgress.recordWordReview(word: challenge.targetWord, wasCorrect: false)
            learningProgress.recordError(
                module: "songs",
                expected: challenge.targetWord,
                actual: option,
                context: line.text
            )
            if songLevel.showsExtraHints {
                clozeHint = wrongClozeAttempts == 1
                    ? "Empieza con \(challenge.targetWord.prefix(1).uppercased())."
                    : "Tiene \(challenge.targetWord.count) letras y aparece exactamente en la letra."
            }
            feedback = PracticeFeedback(
                title: "Probemos otra vez",
                detail: "La palabra elegida no encaja en este tramo.",
                score: 0,
                isCorrect: false
            )
            return
        }

        store.recordAttempt(songID: songID, wasCorrect: true)
        recordSessionPulse(wasCorrect: true)
        learningProgress.saveWord(word: challenge.targetWord, note: line.text, source: "Cancion")
        learningProgress.recordWordReview(word: challenge.targetWord, wasCorrect: true)
        learningProgress.recordModule("songs", wasCorrect: true)
        learningProgress.recordErrorResolved(module: "songs", expected: challenge.targetWord)
        feedback = PracticeFeedback(
            title: "Correcto",
            detail: "La palabra era \(challenge.targetWord).",
            score: 1,
            isCorrect: true
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            guard lines[safe: currentIndex]?.id == line.id else {
                return
            }

            advanceToNextLine(lines: lines)
        }
    }

    private func revealCloze(challenge: ClozeChallenge) {
        answer = challenge.targetWord
        isRevealed = true
        recordSessionPulse(wasCorrect: false)
        learningProgress.saveWord(word: challenge.targetWord, note: "Revelada en una cancion.", source: "Cancion")
        feedback = PracticeFeedback(
            title: "Revelado",
            detail: "La palabra era \(challenge.targetWord).",
            score: 0,
            isCorrect: false
        )
    }

    private func validateAndContinue(line: LyricLine, lines: [LyricLine]) {
        let result = TextMatcher.evaluate(answer: answer, target: line.text)

        guard result.isExact else {
            feedback = PracticeFeedback(
                title: result.isClose ? "Casi" : "A revisar",
                detail: "El tramo no avanza hasta coincidir con la letra cargada.",
                score: result.similarity,
                isCorrect: false
            )
            return
        }

        store.recordAttempt(songID: songID, wasCorrect: true)
        feedback = PracticeFeedback(
            title: "Correcto",
            detail: "Avanzando al siguiente tramo.",
            score: 1,
            isCorrect: true
        )

        let nextIndex = min(currentIndex + 1, lines.count - 1)
        guard nextIndex != currentIndex else {
            return
        }

        currentIndex = nextIndex
        resetRound()

        if let nextLine = lines[safe: nextIndex] {
            command = .playSegment(start: nextLine.startTime, end: nextLine.endTime)
        }
    }

    private func advanceToNextLine(lines: [LyricLine]) {
        let nextIndex = mode == .gated
            ? nextPracticeableIndex(after: currentIndex, lines: lines)
            : sequentialNextIndex(total: lines.count)

        guard let nextIndex, nextIndex != currentIndex else {
            feedback = PracticeFeedback(
                title: "Cancion completada",
                detail: "Volves al inicio para otra vuelta.",
                score: 1,
                isCorrect: true
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                currentIndex = 0
                resetRound()
            }
            return
        }

        currentIndex = nextIndex
        resetRound()

        if let nextLine = lines[safe: nextIndex] {
            command = .playSegment(start: nextLine.startTime, end: nextLine.endTime)
        }
    }

    private func revealHint(for line: LyricLine) {
        guard let nextKey = targetKeys(for: line).subtracting(guessedKeys).sorted().first else {
            return
        }

        guessedKeys.insert(nextKey)

        if isHangmanSolved(for: line) {
            feedback = PracticeFeedback(
                title: "Completo",
                detail: "La linea quedo revelada con pista.",
                score: 1,
                isCorrect: true
            )
        }
    }

    private func reveal(line: LyricLine) {
        isRevealed = true
        feedback = PracticeFeedback(
            title: "Revelado",
            detail: "Respuesta: \(line.text)",
            score: hangmanProgress(for: line),
            isCorrect: false
        )
    }

    private func moveNext(total: Int) {
        currentIndex = sequentialNextIndex(total: total) ?? currentIndex
        resetRound()
    }

    private func movePrevious(total: Int) {
        currentIndex = currentIndex <= 0 ? max(total - 1, 0) : currentIndex - 1
        resetRound()
    }

    private func sequentialNextIndex(total: Int) -> Int? {
        guard total > 0 else {
            return nil
        }

        return currentIndex >= total - 1 ? 0 : currentIndex + 1
    }

    private func currentOrNextPracticeableIndex(from index: Int, lines: [LyricLine]) -> Int? {
        guard !lines.isEmpty else {
            return nil
        }

        for offset in 0..<lines.count {
            let candidateIndex = (index + offset) % lines.count
            if let candidate = lines[safe: candidateIndex],
               clozeChallenge(for: candidate, lines: lines) != nil {
                return candidateIndex
            }
        }

        return nil
    }

    private func nextPracticeableIndex(after index: Int, lines: [LyricLine]) -> Int? {
        guard !lines.isEmpty else {
            return nil
        }

        for offset in 1...lines.count {
            let candidateIndex = (index + offset) % lines.count
            if let candidate = lines[safe: candidateIndex],
               clozeChallenge(for: candidate, lines: lines) != nil {
                return candidateIndex
            }
        }

        return nil
    }

    private func resetRound() {
        answer = ""
        letterInput = ""
        guessedKeys = []
        wrongGuesses = []
        isRevealed = false
        wrongClozeAttempts = 0
        clozeHint = nil
        savedWordMessage = nil
        feedback = nil
        resultWasRecorded = false
        contextualWord = nil
        contextualTranslation = nil
        isTranslatingContextWord = false
        lastFullLineAnswer = ""
    }

    private func recordSessionPulse(wasCorrect: Bool) {
        if wasCorrect {
            sessionCorrectCount += 1
        } else {
            sessionMissCount += 1
        }
    }

    private func recordHangmanResult(wasCorrect: Bool) {
        guard !resultWasRecorded else {
            return
        }

        resultWasRecorded = true
        store.recordAttempt(songID: songID, wasCorrect: wasCorrect)
        learningProgress.recordModule("songs", wasCorrect: wasCorrect)
    }

    private func progress(lines: [LyricLine]) -> Double {
        guard !lines.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(lines.count)
    }

    private func displayedHangmanText(for line: LyricLine) -> String {
        if isRevealed {
            return line.text
        }

        return hangmanMaskedText(for: line.text)
    }

    private func maskedFullLineText(for text: String) -> String {
        text.map { character in
            character.isLetter || character.isNumber ? "_" : String(character)
        }
        .joined()
    }

    private func targetKeys(for line: LyricLine) -> Set<String> {
        var keys: [String] = []

        for token in line.text.split(separator: " ") {
            let rawToken = String(token)
            guard !isIgnoredLyricWord(normalizedWord(rawToken)) else {
                continue
            }

            for character in rawToken where character.isLetter || character.isNumber {
                let key = normalizedGuessKey(String(character))
                if !key.isEmpty {
                    keys.append(key)
                }
            }
        }

        return Set(keys)
    }

    private func normalizedGuessKey(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstCharacter = trimmed.first else {
            return ""
        }

        return TextMatcher.normalize(String(firstCharacter))
    }

    private func isHangmanSolved(for line: LyricLine) -> Bool {
        let keys = targetKeys(for: line)
        return keys.isEmpty || keys.isSubset(of: guessedKeys)
    }

    private func isRoundFinished(for line: LyricLine) -> Bool {
        isRevealed || isHangmanSolved(for: line) || wrongGuesses.count >= maxWrongGuesses
    }

    private func hangmanProgress(for line: LyricLine) -> Double {
        let keys = targetKeys(for: line)
        guard !keys.isEmpty else {
            return 0
        }

        return Double(keys.intersection(guessedKeys).count) / Double(keys.count)
    }

    private func clozeChallenge(for line: LyricLine, lines: [LyricLine]) -> ClozeChallenge? {
        let level = songLevel
        let tokens = line.text.split(separator: " ").map(String.init)
        let candidates = tokens.enumerated().compactMap { index, token -> ClozeCandidate? in
            let word = normalizedWord(token)
            guard isWordSuitable(word, for: level) else {
                return nil
            }

            return ClozeCandidate(index: index, word: word)
        }

        guard !candidates.isEmpty else {
            return nil
        }

        let chosen = candidates[currentIndex % candidates.count]
        var displayTokens = tokens
        displayTokens[chosen.index] = clozeBlank(for: chosen.word)

        return ClozeChallenge(
            textWithBlank: displayTokens.joined(separator: " "),
            targetWord: chosen.word,
            options: clozeOptions(target: chosen.word, lines: lines, level: level)
        )
    }

    private func clozeOptions(target: String, lines: [LyricLine], level: LearningLevel) -> [String] {
        let lyricWords = lines
            .flatMap { $0.text.split(separator: " ").map(String.init) }
            .map(normalizedWord)
            .filter { isWordSuitable($0, for: level) && TextMatcher.normalize($0) != TextMatcher.normalize(target) }

        let fallbackWords: [String] = switch level {
        case .beginner:
            ["love", "time", "home", "song", "day", "heart", "music", "night"]
        case .intermediate:
            ["dream", "never", "again", "story", "believe", "follow", "strong", "better", "away"]
        case .advanced:
            ["through", "forever", "without", "believe", "remember", "another", "meaning", "silence", "promise"]
        }

        var seen = Set<String>()
        let distractors = (lyricWords + fallbackWords)
            .filter { word in
                let key = TextMatcher.normalize(word)
                guard !key.isEmpty, !seen.contains(key), key != TextMatcher.normalize(target) else {
                    return false
                }

                seen.insert(key)
                return true
            }
            .sorted {
                let firstDistance = abs($0.count - target.count)
                let secondDistance = abs($1.count - target.count)
                if firstDistance == secondDistance {
                    return $0 < $1
                }
                return firstDistance < secondDistance
            }
            .prefix(max(level.optionCount - 1, 1))

        return ([target] + distractors)
            .shuffledDeterministically(seed: "\(target)-\(level.rawValue)")
    }

    private func isWordSuitable(_ word: String, for level: LearningLevel) -> Bool {
        guard !word.isEmpty, !isIgnoredLyricWord(word) else { return false }

        switch level {
        case .beginner:
            return (3...5).contains(word.count)
        case .intermediate:
            return (4...8).contains(word.count)
        case .advanced:
            return word.count >= 6
        }
    }

    private var levelSummary: String {
        let level = songLevel

        switch level {
        case .beginner:
            return "\(level.title): palabras cortas, \(level.optionCount) opciones y pistas"
        case .intermediate:
            return "\(level.title): palabras medias, \(level.optionCount) opciones y pistas"
        case .advanced:
            return "\(level.title): palabras largas, \(level.optionCount) opciones y sin pistas"
        }
    }

    private var songLevel: LearningLevel {
        learningProgress.effectiveLevel(for: "songs")
    }

    private func normalizedWord(_ token: String) -> String {
        TextMatcher.normalize(token)
            .split(separator: " ")
            .first
            .map(String.init) ?? ""
    }

    private func isIgnoredLyricWord(_ rawWord: String) -> Bool {
        let word = normalizedWord(rawWord)
        guard !word.isEmpty else {
            return true
        }

        if word.count <= 2 || ignoredLyricWords.contains(word) {
            return true
        }

        let collapsed = collapsedRepeatedCharacters(in: word)
        if ignoredLyricWords.contains(collapsed) {
            return true
        }

        return isRepeatedLyricSyllable(word)
    }

    private func collapsedRepeatedCharacters(in word: String) -> String {
        var result = ""
        var lastCharacter: Character?

        for character in word {
            if character != lastCharacter {
                result.append(character)
                lastCharacter = character
            }
        }

        return result
    }

    private func isRepeatedLyricSyllable(_ word: String) -> Bool {
        let syllables = ["ah", "ay", "ba", "da", "doo", "du", "ha", "la", "na", "oh", "pa", "ra", "ta", "ya"]

        return syllables.contains { syllable in
            guard word.count >= syllable.count * 2 else {
                return false
            }

            var repeated = ""
            while repeated.count < word.count {
                repeated += syllable
            }

            return repeated == word
        }
    }

    private func hangmanMaskedText(for text: String) -> String {
        var output = ""
        var currentWord = ""

        func appendCurrentWord() {
            guard !currentWord.isEmpty else { return }
            output += hangmanMaskedWord(currentWord)
            currentWord = ""
        }

        for character in text {
            if character.isLetter || character.isNumber {
                currentWord.append(character)
            } else {
                appendCurrentWord()
                output.append(character)
            }
        }

        appendCurrentWord()
        return output
    }

    private func hangmanMaskedWord(_ rawWord: String) -> String {
        if isIgnoredLyricWord(rawWord) {
            return rawWord
        }

        return rawWord.map { character in
            let key = normalizedGuessKey(String(character))
            return guessedKeys.contains(key) ? String(character) : "_"
        }
        .joined()
    }

    private func clozeBlank(for word: String) -> String {
        word.map { _ in "□" }.joined(separator: " ")
    }

    private func showClozeHint(challenge: ClozeChallenge) {
        guard let first = challenge.targetWord.first else {
            return
        }

        clozeHint = "Empieza con \(String(first).uppercased()) y tiene \(challenge.targetWord.count) letras."
    }

    private func saveClozeWord(challenge: ClozeChallenge, line: LyricLine) {
        let inserted = learningProgress.saveWord(
            word: challenge.targetWord,
            note: line.text,
            source: "Cancion"
        )
        savedWordMessage = inserted ? "Guardada para repaso." : "Ya estaba en tu vocabulario."
    }

    @MainActor
    private func translateLineIfNeeded(_ line: LyricLine) async {
        guard translatedLineID != line.id || lineTranslation == nil else {
            return
        }

        await translateLine(line)
    }

    @MainActor
    private func translateLine(_ line: LyricLine) async {
        let cleanLine = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLine.isEmpty else { return }

        let requestedLineID = line.id
        translatedLineID = requestedLineID
        lineTranslation = nil
        isTranslatingLine = true

        do {
            let result = try await languageService.translate(text: cleanLine)
            guard translatedLineID == requestedLineID else { return }
            lineTranslation = result
        } catch {
            guard translatedLineID == requestedLineID else { return }
            lineTranslation = nil
        }

        if translatedLineID == requestedLineID {
            isTranslatingLine = false
        }
    }

    @MainActor
    private func inspectWord(_ word: String, in line: LyricLine) async {
        let cleanWord = TextMatcher.normalize(word)
        guard !cleanWord.isEmpty else { return }

        contextualWord = cleanWord
        contextualTranslation = nil
        isTranslatingContextWord = true
        learningProgress.saveWord(word: cleanWord, note: line.text, source: "Cancion")
        savedWordMessage = "Guardada: \(cleanWord)."

        do {
            contextualTranslation = try await languageService.translate(text: cleanWord)
        } catch {
            contextualTranslation = nil
        }

        isTranslatingContextWord = false
    }

    private func optionForeground(_ option: String, challenge: ClozeChallenge) -> Color {
        if isRevealed && TextMatcher.evaluate(answer: option, target: challenge.targetWord).isExact {
            return .green
        }

        if answer == option, let feedback {
            return feedback.isCorrect ? .green : .orange
        }

        return .primary
    }

    private func optionBackground(_ option: String, challenge: ClozeChallenge) -> Color {
        if isRevealed && TextMatcher.evaluate(answer: option, target: challenge.targetWord).isExact {
            return .green.opacity(0.14)
        }

        if answer == option, let feedback {
            return feedback.isCorrect ? .green.opacity(0.14) : .orange.opacity(0.14)
        }

        return Color(.secondarySystemBackground)
    }

    private func optionBorder(_ option: String, challenge: ClozeChallenge) -> Color {
        if isRevealed && TextMatcher.evaluate(answer: option, target: challenge.targetWord).isExact {
            return .green
        }

        if answer == option, let feedback {
            return feedback.isCorrect ? .green : .orange
        }

        return Color(.separator)
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let minutes = Int(value) / 60
        let seconds = Int(value) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func maskedContextText(for text: String) -> String {
        text.split(separator: " ")
            .map { token in
                let word = normalizedWord(String(token))
                guard isWordSuitable(word, for: songLevel) else {
                    return String(token)
                }

                return clozeBlank(for: word)
            }
            .joined(separator: " ")
    }

    private func keyContextWords(for line: LyricLine, excluding hiddenWord: String?) -> [String] {
        let hiddenKey = hiddenWord.map(TextMatcher.normalize)
        var seen = Set<String>()
        var words: [String] = []

        for token in line.text.split(separator: " ") {
            let word = normalizedWord(String(token))
            let key = TextMatcher.normalize(word)
            let isHiddenWord = hiddenKey.map { $0 == key } ?? false
            guard word.count >= 3,
                  !isHiddenWord,
                  !isIgnoredLyricWord(word),
                  seen.insert(key).inserted else {
                continue
            }

            words.append(word)
        }

        return Array(words.prefix(6))
    }
}

private enum PracticeMode: String, CaseIterable, Identifiable {
    case gated = "Palabra"
    case hangman = "Ahorcado"
    case fullLine = "Linea"

    var id: Self { self }
}

private enum MusicLessonTheme {
    static let ink = Color(red: 0.05, green: 0.08, blue: 0.24)
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.60)
    static let primary = Color(red: 0.20, green: 0.36, blue: 0.98)
    static let secondary = Color(red: 0.47, green: 0.35, blue: 0.98)
    static let mint = Color(red: 0.38, green: 0.78, blue: 0.73)
    static let surface = Color.white
    static let softSurface = Color(red: 0.96, green: 0.97, blue: 1.0)
}

private struct MusicLessonBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.99, blue: 1.0),
                Color(red: 0.93, green: 0.95, blue: 1.0),
                Color(red: 0.98, green: 0.99, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            MusicDotPattern()
                .foregroundStyle(MusicLessonTheme.secondary.opacity(0.20))
                .frame(width: 118, height: 90)
                .padding(.top, 24)
                .padding(.trailing, 18)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(MusicLessonTheme.primary.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: -140, y: 120)
        }
    }
}

private struct MusicDotPattern: View {
    private let columns = Array(repeating: GridItem(.fixed(9), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<36, id: \.self) { _ in
                Circle()
                    .frame(width: 4, height: 4)
            }
        }
    }
}

private struct MusicLessonHeader: View {
    let lessonNumber: Int
    let totalLessons: Int
    let hearts: Int
    let progress: Double
    let closeAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(MusicLessonTheme.ink)
                        .frame(width: 42, height: 42)
                        .background(MusicLessonTheme.surface.opacity(0.86), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Lesson \(lessonNumber) of \(totalLessons)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MusicLessonTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color.red.opacity(0.78))

                    Text("\(hearts)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                }
                .frame(width: 42, height: 42)
            }

            MusicProgressSegments(progress: progress)
        }
    }
}

private struct MusicProgressSegments: View {
    let progress: Double
    private let segmentCount = 5

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<segmentCount, id: \.self) { index in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(red: 0.86, green: 0.88, blue: 0.95))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [MusicLessonTheme.primary, MusicLessonTheme.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * fillAmount(for: index))
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func fillAmount(for index: Int) -> Double {
        let scaled = progress * Double(segmentCount)
        return min(max(scaled - Double(index), 0), 1)
    }
}

private struct MusicCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(MusicLessonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: MusicLessonTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct MusicSongPlayerCard<Player: View>: View {
    let song: Song
    let line: LyricLine
    let progress: Double
    let currentTimeText: String
    let durationText: String
    @ViewBuilder let player: () -> Player
    let replayPrevious: () -> Void
    let play: () -> Void
    let replayNext: () -> Void

    var body: some View {
        MusicCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    player()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.7), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(song.displayTitle)
                            .font(.headline)
                            .foregroundStyle(MusicLessonTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Text(song.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? song.language : song.artist)
                            .font(.caption)
                            .foregroundStyle(MusicLessonTheme.muted)
                            .lineLimit(1)

                        HStack {
                            Text(currentTimeText)
                            Spacer()
                            Text(durationText)
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(MusicLessonTheme.muted)

                        ProgressView(value: progress)
                            .tint(MusicLessonTheme.primary)

                        MusicWaveformView(progress: progress)
                            .frame(height: 26)
                    }
                }

                HStack(spacing: 28) {
                    Button(action: replayPrevious) {
                        Image(systemName: "backward.end.fill")
                    }
                    .buttonStyle(MusicPlayerControlButtonStyle(size: 40, isPrimary: false))

                    Button(action: play) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(MusicPlayerControlButtonStyle(size: 56, isPrimary: true))

                    Button(action: replayNext) {
                        Image(systemName: "forward.end.fill")
                    }
                    .buttonStyle(MusicPlayerControlButtonStyle(size: 40, isPrimary: false))
                }
                .font(.headline)
            }
        }
    }
}

private struct MusicWaveformView: View {
    let progress: Double
    private let bars: [CGFloat] = [0.30, 0.62, 0.42, 0.78, 0.35, 0.54, 0.88, 0.45, 0.70, 0.38, 0.58, 0.82, 0.48, 0.64, 0.36, 0.74, 0.52, 0.86, 0.40, 0.66]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(Double(index) / Double(max(bars.count - 1, 1)) <= progress ? MusicLessonTheme.primary.opacity(0.8) : MusicLessonTheme.primary.opacity(0.20))
                    .frame(width: 3, height: max(7, height * 26))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MusicModeSelector: View {
    @Binding var mode: PracticeMode
    let level: LearningLevel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PracticeMode.allCases) { option in
                MusicModePill(
                    option: option,
                    isSelected: mode == option,
                    action: {
                    mode = option
                    }
                )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text(level.shortCode)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MusicLessonTheme.mint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MusicLessonTheme.surface, in: Capsule())
                .offset(y: 22)
        }
        .padding(.bottom, 8)
    }
}

private struct MusicModePill: View {
    let option: PracticeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: option.systemImage)
                    .font(.caption.weight(.bold))

                Text(option.rawValue)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : MusicLessonTheme.primary)
        .background {
            if isSelected {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [MusicLessonTheme.primary, MusicLessonTheme.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else {
                Capsule()
                    .fill(MusicLessonTheme.surface)
            }
        }
        .overlay {
            Capsule()
                .stroke(isSelected ? .clear : MusicLessonTheme.primary.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct MusicLyricsPracticeCard: View {
    let challenge: ClozeChallenge
    let line: LyricLine
    let previousLine: LyricLine?
    let nextLine: LyricLine?
    let selectedOption: String
    let isRevealed: Bool
    let letterCount: Int?
    let translation: String?
    let isTranslating: Bool
    let optionAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 10) {
                if let previousLine {
                    MusicLyricLine(text: previousLine.text, isCurrent: false)
                }

                MusicLyricLine(text: displayText, isCurrent: true)

                if let nextLine {
                    MusicLyricLine(text: nextLine.text, isCurrent: false)
                }
            }

            if let letterCount {
                MusicInfoPill(
                    text: "The missing word has \(letterCount) letters.",
                    systemImage: "square.grid.2x2.fill",
                    tint: MusicLessonTheme.primary
                )
            }

            PracticeFlowLayout(spacing: 8) {
                ForEach(challenge.options, id: \.self) { option in
                    Button {
                        optionAction(option)
                    } label: {
                        Text(option)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedOption == option ? .white : MusicLessonTheme.primary)
                    .background(selectedOption == option ? MusicLessonTheme.primary : MusicLessonTheme.primary.opacity(0.08), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(MusicLessonTheme.primary.opacity(selectedOption == option ? 0 : 0.30), lineWidth: 1)
                    }
                    .disabled(isRevealed)
                }
            }

            if isTranslating || translation != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe.americas.fill")
                            .foregroundStyle(MusicLessonTheme.mint)

                        Text("Meaning")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MusicLessonTheme.muted)
                    }

                    if isTranslating {
                        ProgressView("Translating...")
                            .font(.caption)
                    } else if let translation {
                        Text(translation)
                            .font(.caption)
                            .foregroundStyle(MusicLessonTheme.ink)
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .background(MusicLessonTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var displayText: String {
        if isRevealed {
            return line.text
        }

        return challenge.textWithBlank
    }
}

private struct MusicLyricLine: View {
    let text: String
    let isCurrent: Bool

    var body: some View {
        Text(text)
            .font(isCurrent ? .body.weight(.semibold) : .callout)
            .foregroundStyle(isCurrent ? MusicLessonTheme.ink : MusicLessonTheme.muted)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isCurrent ? 12 : 0)
            .padding(.vertical, isCurrent ? 11 : 0)
            .background(isCurrent ? MusicLessonTheme.primary.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MusicQuickActionsBar: View {
    let replay: () -> Void
    let slowMode: () -> Void
    let translate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            MusicActionChip(title: "Replay line", systemImage: "arrow.counterclockwise", action: replay)
            MusicActionChip(title: "Slow mode", systemImage: "tortoise.fill", action: slowMode)
            MusicActionChip(title: "View translation", systemImage: "globe", action: translate)
        }
    }
}

private struct MusicActionChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MusicLessonTheme.primary)
        .background(MusicLessonTheme.softSurface, in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct MusicInfoPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MusicLessonTheme.ink)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MusicFeedbackBanner: View {
    let feedback: PracticeFeedback

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feedback.isCorrect ? "star.fill" : "sparkles")
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(feedback.isCorrect ? MusicLessonTheme.mint : Color.orange, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.isCorrect ? "Great listening!" : feedback.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(MusicLessonTheme.ink)

                Text(feedback.isCorrect ? "+20 XP" : feedback.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(feedback.isCorrect ? MusicLessonTheme.mint : MusicLessonTheme.muted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(MusicLessonTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MusicUnavailableLineCard: View {
    let lineText: String
    let nextAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lineText)
                .font(.body.weight(.semibold))
                .foregroundStyle(MusicLessonTheme.ink)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(MusicLessonTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

            ContentUnavailableView("No missing word here", systemImage: "text.badge.xmark")

            Button(action: nextAction) {
                Text("Next line")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MusicPrimaryButtonStyle())
        }
    }
}

private struct MusicPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [MusicLessonTheme.primary, MusicLessonTheme.secondary]
                        : [Color.gray.opacity(0.45), Color.gray.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .shadow(color: MusicLessonTheme.primary.opacity(isEnabled ? 0.22 : 0), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct MusicSmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(MusicLessonTheme.primary)
            .padding(.vertical, 11)
            .background(MusicLessonTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct MusicPlayerControlButtonStyle: ButtonStyle {
    let size: CGFloat
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isPrimary ? .white : MusicLessonTheme.ink)
            .frame(width: size, height: size)
            .background {
                if isPrimary {
                    Circle()
                        .fill(
                            LinearGradient(
                            colors: [MusicLessonTheme.primary, MusicLessonTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Circle()
                        .fill(MusicLessonTheme.softSurface)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

private struct SongPracticeMissionPanel: View {
    let mode: PracticeMode
    let level: LearningLevel
    let lineNumber: Int
    let totalLines: Int
    let focusWord: String?
    let correctCount: Int
    let missCount: Int

    private var streakText: String {
        if correctCount == 0 && missCount == 0 {
            return "primera ronda"
        }

        return "\(correctCount) bien · \(missCount) a revisar"
    }

    private var missionText: String {
        switch mode {
        case .gated:
            if let focusWord {
                return "Detecta el sentido y elegi \(focusWord.count) letras."
            }
            return "Usa contexto y completa la palabra."
        case .hangman:
            return "Revela la linea por sonido, no por memoria."
        case .fullLine:
            return "Escribi el tramo completo y compara diferencias."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: mode.systemImage)
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reto activo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(missionText)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                MissionPill(title: "Linea", value: "\(lineNumber)/\(totalLines)", systemImage: "text.quote")
                MissionPill(title: "Nivel", value: level.title, systemImage: "slider.horizontal.3")
                MissionPill(title: "Sesion", value: streakText, systemImage: "waveform.path.ecg")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MissionPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PracticeCoachInsight: View {
    let feedback: PracticeFeedback
    let focusText: String
    let sourceLine: String
    let modeTitle: String

    private var title: String {
        feedback.isCorrect ? "Buen patron" : "Pista de aprendizaje"
    }

    private var detail: String {
        if feedback.isCorrect {
            return "Conectaste \(focusText) con el tramo real. Repetilo una vez mas para fijar sonido y significado."
        }

        return "Antes de probar de nuevo, mira la linea completa y busca que palabra cambia el sentido: \(sourceLine)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.isCorrect ? "sparkles" : "lightbulb")
                .foregroundStyle(feedback.isCorrect ? Color.green : Color.orange)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))

                    Spacer()

                    Text(modeTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension PracticeMode {
    var systemImage: String {
        switch self {
        case .gated:
            return "rectangle.and.pencil.and.ellipsis"
        case .hangman:
            return "character.cursor.ibeam"
        case .fullLine:
            return "text.line.first.and.arrowtriangle.forward"
        }
    }
}

private struct LyricContextPanel: View {
    let currentLineText: String
    let previousLine: LyricLine?
    let nextLine: LyricLine?
    let translation: String?
    let isTranslating: Bool
    let keyWords: [String]
    let selectedWord: String?
    let wordTranslation: String?
    let isWordLoading: Bool
    let inspectWord: (String) -> Void
    let translateLine: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Contexto", systemImage: "quote.bubble")
                    .font(.headline)

                Spacer()

                Button(action: translateLine) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Actualizar traduccion")
            }

            VStack(alignment: .leading, spacing: 8) {
                if let previousLine {
                    ContextLineRow(title: "Antes", text: previousLine.text)
                }

                ContextLineRow(title: "Ahora", text: currentLineText, isCurrent: true)

                if let nextLine {
                    ContextLineRow(title: "Despues", text: nextLine.text)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "globe.americas.fill")
                        .foregroundStyle(.tint)

                    Text("Sentido en espanol")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if isTranslating {
                    ProgressView("Traduciendo linea...")
                        .font(.caption)
                } else {
                    Text(translation ?? "Toca actualizar para traducir este tramo.")
                        .font(.subheadline)
                        .foregroundStyle(translation == nil ? .secondary : .primary)
                        .lineLimit(3)
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            if !keyWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Palabras clave")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    PracticeFlowLayout(spacing: 7) {
                        ForEach(keyWords, id: \.self) { word in
                            Button {
                                inspectWord(word)
                            } label: {
                                Text(word)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedWord == word ? Color.white : Color.accentColor)
                            .background(selectedWord == word ? Color.accentColor : Color(.tertiarySystemBackground), in: Capsule())
                        }
                    }
                }
            }

            if let selectedWord {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedWord)
                            .font(.caption.weight(.semibold))

                        Text(wordTranslation ?? "Guardada para repaso.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if isWordLoading {
                        ProgressView()
                            .scaleEffect(0.75)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ContextLineRow: View {
    let title: String
    let text: String
    var isCurrent = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: 56, alignment: .leading)

            Text(text)
                .font(isCurrent ? .callout.weight(.semibold) : .caption)
                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                .lineLimit(isCurrent ? 4 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(isCurrent ? Color.accentColor.opacity(0.08) : Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SyncCalibrationPanel: View {
    @State private var isExpanded = false

    let line: LyricLine
    let currentTime: TimeInterval
    let message: String?
    let shiftEarlier: () -> Void
    let alignToCurrentLine: () -> Void
    let replay: () -> Void
    let shiftLater: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("\(formatTime(line.startTime)) - \(formatTime(line.endTime))", systemImage: "timer")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(formatTime(currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button(action: alignToCurrentLine) {
                    Label("Esta linea empieza ahora", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentTime <= 0)

                HStack(spacing: 8) {
                    Button(action: shiftEarlier) {
                        Label("Antes", systemImage: "backward.end")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: replay) {
                        Label("Probar", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: shiftLater) {
                        Label("Despues", systemImage: "forward.end")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let message {
                    Label(message, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Label("Sincronia avanzada", systemImage: "timer")
                    .font(.caption.weight(.semibold))

                Spacer()

                Text(formatTime(line.startTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let minutes = Int(value) / 60
        let seconds = Int(value) % 60
        let tenths = Int((value - floor(value)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

private struct ClozeChallenge {
    let textWithBlank: String
    let targetWord: String
    let options: [String]
}

private struct ClozeCandidate {
    let index: Int
    let word: String
}

private struct ClozeLineCard: View {
    let challenge: ClozeChallenge
    let selectedOption: String
    let isRevealed: Bool
    let showsLetterCount: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isRevealed ? challenge.textWithBlank.replacingOccurrences(of: clozePattern, with: challenge.targetWord) : challenge.textWithBlank)
                .font(.title3.monospaced())
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsLetterCount {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .foregroundStyle(.tint)

                    Text("La palabra tiene \(challenge.targetWord.count) letras")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            if !selectedOption.isEmpty && !isRevealed {
                Text("Elegiste: \(selectedOption)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var clozePattern: String {
        challenge.targetWord.map { _ in "□" }.joined(separator: " ")
    }
}

private struct LetterKeyboardView: View {
    let usedKeys: Set<String>
    let action: (String) -> Void

    private let keys = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").map(String.init)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(keys, id: \.self) { key in
                Button {
                    action(key)
                } label: {
                    Text(key)
                        .font(.callout.monospaced().weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(usedKeys.contains(TextMatcher.normalize(key)))
            }
        }
    }
}

private struct PracticeFeedback {
    let title: String
    let detail: String
    let score: Double
    let isCorrect: Bool
}

private struct FeedbackView: View {
    let feedback: PracticeFeedback

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(feedback.isCorrect ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(.headline)
                Text(feedback.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Progreso \(Int(feedback.score * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PracticeWordDiffView: View {
    let answer: String
    let target: String

    private var tokens: [TextComparisonToken] {
        TextMatcher.wordComparison(answer: answer, target: target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diferencias")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            PracticeFlowLayout(spacing: 6) {
                ForEach(tokens) { token in
                    Text(label(for: token))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(foreground(for: token.status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(background(for: token.status), in: Capsule())
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func label(for token: TextComparisonToken) -> String {
        switch token.status {
        case .exact:
            return token.expected
        case .close, .wrong:
            return "\(token.actual ?? "") -> \(token.expected)"
        case .missing:
            return "+ \(token.expected)"
        case .extra:
            return "- \(token.actual ?? token.expected)"
        }
    }

    private func foreground(for status: TextComparisonStatus) -> Color {
        switch status {
        case .exact:
            return .green
        case .close:
            return .yellow
        case .wrong:
            return .orange
        case .missing, .extra:
            return .secondary
        }
    }

    private func background(for status: TextComparisonStatus) -> Color {
        switch status {
        case .exact:
            return .green.opacity(0.14)
        case .close:
            return .yellow.opacity(0.18)
        case .wrong:
            return .orange.opacity(0.14)
        case .missing, .extra:
            return Color(.tertiarySystemBackground)
        }
    }
}

private struct PracticeFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }

            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x + size.width > bounds.maxX, point.x > bounds.minX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: point, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension Array where Element == String {
    func shuffledDeterministically(seed: String) -> [String] {
        enumerated()
            .sorted {
                let firstScore = "\($0.element)-\(seed)".stableScore
                let secondScore = "\($1.element)-\(seed)".stableScore
                if firstScore == secondScore {
                    return $0.offset < $1.offset
                }

                return firstScore < secondScore
            }
            .map(\.element)
    }
}

private extension String {
    var stableScore: Int {
        unicodeScalars.reduce(17) { partialResult, scalar in
            Int((Int64(partialResult) * 31 + Int64(scalar.value)) % 1_000_003)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
