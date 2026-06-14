import Foundation

enum LearningLevel: String, CaseIterable, Identifiable, Codable {
    case beginner
    case intermediate
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .beginner: "Principiante"
        case .intermediate: "Intermedio"
        case .advanced: "Avanzado"
        }
    }

    var shortCode: String {
        switch self {
        case .beginner: "A1"
        case .intermediate: "B1"
        case .advanced: "C1"
        }
    }

    var courseName: String {
        switch self {
        case .beginner: "Beginner A1"
        case .intermediate: "Intermediate B1"
        case .advanced: "Advanced C1"
        }
    }

    var detail: String {
        switch self {
        case .beginner: "Frases cortas, mas ayuda y repaso frecuente."
        case .intermediate: "Mas variedad, listening y escritura."
        case .advanced: "Menos pistas y frases mas naturales."
        }
    }

    var sentenceWordRange: ClosedRange<Int> {
        switch self {
        case .beginner: 3...6
        case .intermediate: 5...9
        case .advanced: 8...14
        }
    }

    var optionCount: Int {
        switch self {
        case .beginner: 3
        case .intermediate: 4
        case .advanced: 5
        }
    }

    var speechRate: Float {
        switch self {
        case .beginner: 0.38
        case .intermediate: 0.45
        case .advanced: 0.52
        }
    }

    var acceptsCloseAnswers: Bool {
        switch self {
        case .beginner: true
        case .intermediate: true
        case .advanced: false
        }
    }

    var showsExtraHints: Bool {
        switch self {
        case .beginner: true
        case .intermediate: true
        case .advanced: false
        }
    }

    var practiceLimit: Int {
        switch self {
        case .beginner: 4
        case .intermediate: 6
        case .advanced: 8
        }
    }

    var nextLevel: LearningLevel {
        switch self {
        case .beginner: .intermediate
        case .intermediate: .advanced
        case .advanced: .advanced
        }
    }

    var previousLevel: LearningLevel {
        switch self {
        case .beginner: .beginner
        case .intermediate: .beginner
        case .advanced: .intermediate
        }
    }

    static func fromCEFRCode(_ code: String) -> LearningLevel {
        switch LearningLevel.normalizedCEFRCode(code) {
        case "Pre-A1", "A1", "A2":
            return .beginner
        case "B1", "B2":
            return .intermediate
        default:
            return .advanced
        }
    }

    static func normalizedCEFRCode(_ code: String) -> String {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "PRE-A1", "PRE A1", "PREA1":
            return "Pre-A1"
        case "A1":
            return "A1"
        case "A2":
            return "A2"
        case "B1":
            return "B1"
        case "B2":
            return "B2"
        case "C1":
            return "C1"
        case "C2":
            return "C2"
        default:
            return "A1"
        }
    }
}

enum LearningFocus: String, CaseIterable, Identifiable, Codable {
    case songs
    case vocabulary
    case speaking

    var id: Self { self }

    var title: String {
        switch self {
        case .songs: "Canciones"
        case .vocabulary: "Vocabulario"
        case .speaking: "Speaking"
        }
    }
}

struct LearningProfile: Codable, Equatable {
    var onboardingCompleted = false
    var level: LearningLevel = .beginner
    var cefrLevel: String?
    var focus: LearningFocus = .songs
    var dailyGoalMinutes = 15
    var streak = 0
    var lastPracticeDay: Date?
}

struct SavedVocabularyItem: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var word: String
    var note: String
    var source: String
    var createdAt = Date()
    var lastReviewedAt: Date?
    var nextReviewAt = Date()
    var attempts = 0
    var correct = 0

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts)
    }
}

struct LearningModuleStat: Identifiable, Codable, Equatable {
    var id: String { module }
    var module: String
    var attempts = 0
    var correct = 0
    var lastPracticedAt: Date?

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts)
    }

    mutating func record(wasCorrect: Bool) {
        attempts += 1
        if wasCorrect {
            correct += 1
        }
        lastPracticedAt = Date()
    }
}

struct LearningErrorPattern: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var module: String
    var expected: String
    var actual: String
    var context: String
    var count = 1
    var resolvedCount = 0
    var createdAt = Date()
    var lastSeenAt = Date()

    var title: String {
        expected.isEmpty ? "Respuesta incompleta" : expected
    }

    var detail: String {
        if actual.isEmpty {
            return context.isEmpty ? "Falto completar esta parte." : context
        }

        return "\(actual) -> \(expected)"
    }

    var mastery: Double {
        let total = count + resolvedCount
        guard total > 0 else { return 0 }
        return Double(resolvedCount) / Double(total)
    }

    func matches(module otherModule: String, expected otherExpected: String, actual otherActual: String) -> Bool {
        module == otherModule
            && TextMatcher.normalize(expected) == TextMatcher.normalize(otherExpected)
            && TextMatcher.normalize(actual) == TextMatcher.normalize(otherActual)
    }
}

struct CachedSentence: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var text: String
    var translation: String
    var sourceLanguage: String
    var targetLanguage: String
    var cachedAt = Date()

    init(example: SentenceExample) {
        text = example.text
        translation = example.translation ?? ""
        sourceLanguage = example.sourceLanguage
        targetLanguage = example.targetLanguage ?? "spa"
    }

    var sentenceExample: SentenceExample {
        SentenceExample(
            text: text,
            translation: translation,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }
}

@MainActor
final class LearningProgressStore: ObservableObject {
    @Published private(set) var profile = LearningProfile()
    @Published private(set) var savedWords: [SavedVocabularyItem] = []
    @Published private(set) var moduleStats: [LearningModuleStat] = []
    @Published private(set) var cachedSentences: [CachedSentence] = []
    @Published private(set) var errorPatterns: [LearningErrorPattern] = []
    @Published private(set) var apiLearnerId = "ios-\(UUID().uuidString)"
    @Published private(set) var completedRemoteContentKeys = Set<String>()

    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    func completeOnboarding(level: LearningLevel, focus: LearningFocus, dailyGoalMinutes: Int) {
        profile.level = level
        profile.cefrLevel = level.shortCode
        profile.focus = focus
        profile.dailyGoalMinutes = dailyGoalMinutes
        profile.onboardingCompleted = true
        save()
    }

    func updateLevel(_ level: LearningLevel) {
        profile.level = level
        profile.cefrLevel = level.shortCode
        save()
    }

    func updateCEFRLevel(_ levelCode: String) {
        let normalizedCode = LearningLevel.normalizedCEFRCode(levelCode)
        profile.cefrLevel = normalizedCode
        profile.level = LearningLevel.fromCEFRCode(normalizedCode)
        save()
    }

    var cefrLevelCode: String {
        LearningLevel.normalizedCEFRCode(profile.cefrLevel ?? profile.level.shortCode)
    }

    func updateFocus(_ focus: LearningFocus) {
        profile.focus = focus
        save()
    }

    func recordModule(_ module: String, wasCorrect: Bool = true) {
        if let index = moduleStats.firstIndex(where: { $0.module == module }) {
            moduleStats[index].record(wasCorrect: wasCorrect)
        } else {
            var stat = LearningModuleStat(module: module)
            stat.record(wasCorrect: wasCorrect)
            moduleStats.append(stat)
        }

        recordPracticeDay()
        save()
    }

    @discardableResult
    func saveWord(word rawWord: String, note rawNote: String, source: String) -> Bool {
        let word = TextMatcher.normalize(rawWord)
        let note = rawNote.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !word.isEmpty else {
            return false
        }

        if let index = savedWords.firstIndex(where: { TextMatcher.normalize($0.word) == word }) {
            if !note.isEmpty {
                savedWords[index].note = note
            }
            savedWords[index].source = source
            save()
            return false
        }

        savedWords.insert(
            SavedVocabularyItem(word: word, note: note, source: source),
            at: 0
        )
        save()
        return true
    }

    func recordWordReview(word rawWord: String, wasCorrect: Bool) {
        let word = TextMatcher.normalize(rawWord)
        guard let index = savedWords.firstIndex(where: { TextMatcher.normalize($0.word) == word }) else {
            return
        }

        savedWords[index].attempts += 1
        if wasCorrect {
            savedWords[index].correct += 1
        }
        savedWords[index].lastReviewedAt = Date()
        savedWords[index].nextReviewAt = nextReviewDate(for: savedWords[index], wasCorrect: wasCorrect)
        recordPracticeDay()
        save()
    }

    func dueVocabulary(limit: Int = 12) -> [SavedVocabularyItem] {
        let now = Date()
        return savedWords
            .filter { $0.nextReviewAt <= now }
            .sorted {
                let firstPriority = reviewPriority(for: $0)
                let secondPriority = reviewPriority(for: $1)
                if firstPriority != secondPriority {
                    return firstPriority > secondPriority
                }

                if $0.nextReviewAt == $1.nextReviewAt {
                    return $0.createdAt < $1.createdAt
                }
                return $0.nextReviewAt < $1.nextReviewAt
            }
            .prefix(limit)
            .map { $0 }
    }

    func cacheSentences(_ examples: [SentenceExample]) {
        let incoming = examples
            .filter { $0.translation?.isEmpty == false }
            .map(CachedSentence.init)

        guard !incoming.isEmpty else {
            return
        }

        var seen = Set(cachedSentences.map { TextMatcher.normalize($0.text) })
        let newItems = incoming.filter { seen.insert(TextMatcher.normalize($0.text)).inserted }
        cachedSentences = Array((newItems + cachedSentences).prefix(60))
        save()
    }

    func cachedSentenceExamples(limit: Int = 8) -> [SentenceExample] {
        Array(cachedSentences.prefix(limit)).map(\.sentenceExample)
    }

    func stat(for module: String) -> LearningModuleStat? {
        moduleStats.first { $0.module == module }
    }

    func recordError(module: String, expected rawExpected: String, actual rawActual: String, context rawContext: String = "") {
        let expected = TextMatcher.normalize(rawExpected)
        let actual = TextMatcher.normalize(rawActual)
        let context = rawContext.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !expected.isEmpty || !actual.isEmpty else {
            return
        }

        if let index = errorPatterns.firstIndex(where: { $0.matches(module: module, expected: expected, actual: actual) }) {
            errorPatterns[index].count += 1
            if !context.isEmpty {
                errorPatterns[index].context = context
            }
            errorPatterns[index].lastSeenAt = Date()
        } else {
            errorPatterns.insert(
                LearningErrorPattern(module: module, expected: expected, actual: actual, context: context),
                at: 0
            )
        }

        errorPatterns = Array(errorPatterns.sorted(by: errorSort).prefix(80))
        save()
    }

    func recordErrorResolved(module: String, expected rawExpected: String) {
        let expected = TextMatcher.normalize(rawExpected)
        guard !expected.isEmpty else { return }

        var didUpdate = false
        for index in errorPatterns.indices where errorPatterns[index].module == module && TextMatcher.normalize(errorPatterns[index].expected) == expected {
            errorPatterns[index].resolvedCount += 1
            errorPatterns[index].lastSeenAt = Date()
            didUpdate = true
        }

        if didUpdate {
            errorPatterns = Array(errorPatterns.sorted(by: errorSort).prefix(80))
            save()
        }
    }

    func isRemoteContentCompleted(kind: String, itemId: String?) -> Bool {
        guard let itemId else { return false }
        return completedRemoteContentKeys.contains(remoteContentKey(kind: kind, itemId: itemId))
    }

    @discardableResult
    func markRemoteContentCompleted(kind: String, itemId: String?) -> Bool {
        guard let itemId, !itemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let inserted = completedRemoteContentKeys.insert(remoteContentKey(kind: kind, itemId: itemId)).inserted
        if inserted {
            save()
        }
        return inserted
    }

    func topErrors(limit: Int = 6) -> [LearningErrorPattern] {
        Array(errorPatterns.sorted(by: errorSort).prefix(limit))
    }

    func errorSeeds(limit: Int = 6) -> [String] {
        topErrors(limit: limit)
            .flatMap { $0.expected.split(separator: " ").map(String.init) }
            .filter { $0.count >= 3 }
    }

    var totalAttempts: Int {
        moduleStats.reduce(0) { $0 + $1.attempts }
    }

    var totalCorrect: Int {
        moduleStats.reduce(0) { $0 + $1.correct }
    }

    var overallAccuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts)
    }

    var recommendedLevel: LearningLevel {
        guard totalAttempts >= 8 else {
            return profile.level
        }

        if overallAccuracy >= 0.88 {
            return profile.level.nextLevel
        }

        if overallAccuracy <= 0.55 {
            return profile.level.previousLevel
        }

        return profile.level
    }

    var adaptiveMessage: String {
        guard totalAttempts >= 4 else {
            return "Hace algunos ejercicios y ajusto la dificultad con tus resultados."
        }

        if recommendedLevel != profile.level {
            return "Sugerencia: probar \(recommendedLevel.title.lowercased()) segun tu precision."
        }

        if overallAccuracy >= 0.78 {
            return "Vas bien: mantengo el nivel y reduzco ayudas en ejercicios fuertes."
        }

        return "Refuerzo activado: priorizo repaso y mas pistas donde cuesta."
    }

    func effectiveLevel(for module: String) -> LearningLevel {
        guard let stat = stat(for: module), stat.attempts >= 5 else {
            return profile.level
        }

        if stat.accuracy >= 0.9 {
            return profile.level.nextLevel
        }

        if stat.accuracy <= 0.55 {
            return profile.level.previousLevel
        }

        return profile.level
    }

    private func recordPracticeDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastPracticeDay = profile.lastPracticeDay {
            let previous = calendar.startOfDay(for: lastPracticeDay)
            if previous == today {
                return
            }

            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            profile.streak = previous == yesterday ? profile.streak + 1 : 1
        } else {
            profile.streak = 1
        }

        profile.lastPracticeDay = today
    }

    private func nextReviewDate(for item: SavedVocabularyItem, wasCorrect: Bool) -> Date {
        if !wasCorrect {
            let delay: TimeInterval = item.attempts <= 2 ? 10 * 60 : 30 * 60
            return Date().addingTimeInterval(delay)
        }

        let interval: TimeInterval
        let accuracy = item.accuracy
        switch item.correct {
        case 0:
            interval = 4 * 60 * 60
        case 1:
            interval = 24 * 60 * 60
        case 2...3 where accuracy >= 0.75:
            interval = 3 * 24 * 60 * 60
        case 2...3:
            interval = 24 * 60 * 60
        default:
            interval = accuracy >= 0.85 ? 7 * 24 * 60 * 60 : 3 * 24 * 60 * 60
        }

        return Date().addingTimeInterval(interval)
    }

    private func reviewPriority(for item: SavedVocabularyItem) -> Double {
        let accuracyPenalty = 1 - item.accuracy
        let attemptWeight = item.attempts == 0 ? 0.7 : min(Double(item.attempts) / 8, 1)
        let overdueHours = max(0, Date().timeIntervalSince(item.nextReviewAt) / 3600)
        return accuracyPenalty + attemptWeight + min(overdueHours / 24, 1)
    }

    private func load() {
        do {
            let data = try Data(contentsOf: progressURL)
            let state = try decoder.decode(LearningProgressState.self, from: data)
            profile = state.profile
            savedWords = state.savedWords
            moduleStats = state.moduleStats
            cachedSentences = state.cachedSentences
            errorPatterns = state.errorPatterns
            apiLearnerId = state.apiLearnerId
            completedRemoteContentKeys = Set(state.completedRemoteContentKeys)
        } catch {
            profile = LearningProfile()
            savedWords = []
            moduleStats = []
            cachedSentences = []
            errorPatterns = []
            apiLearnerId = "ios-\(UUID().uuidString)"
            completedRemoteContentKeys = []
            save()
        }
    }

    private func save() {
        do {
            let directory = progressURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let state = LearningProgressState(
                profile: profile,
                savedWords: savedWords,
                moduleStats: moduleStats,
                cachedSentences: cachedSentences,
                errorPatterns: errorPatterns,
                apiLearnerId: apiLearnerId,
                completedRemoteContentKeys: Array(completedRemoteContentKeys).sorted()
            )
            let data = try encoder.encode(state)
            try data.write(to: progressURL, options: [.atomic])
        } catch {
            assertionFailure("Could not save learning progress: \(error)")
        }
    }

    private var progressURL: URL {
        fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("locupom-learning-progress.json")
    }

    private func errorSort(_ first: LearningErrorPattern, _ second: LearningErrorPattern) -> Bool {
        let firstScore = Double(first.count - first.resolvedCount) + min(Date().timeIntervalSince(first.lastSeenAt) / (24 * 60 * 60), 7) * -0.05
        let secondScore = Double(second.count - second.resolvedCount) + min(Date().timeIntervalSince(second.lastSeenAt) / (24 * 60 * 60), 7) * -0.05

        if firstScore == secondScore {
            return first.lastSeenAt > second.lastSeenAt
        }

        return firstScore > secondScore
    }

    private func remoteContentKey(kind: String, itemId: String) -> String {
        "\(kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()):\(itemId.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}

private struct LearningProgressState: Codable {
    var profile: LearningProfile
    var savedWords: [SavedVocabularyItem]
    var moduleStats: [LearningModuleStat]
    var cachedSentences: [CachedSentence]
    var errorPatterns: [LearningErrorPattern]
    var apiLearnerId: String
    var completedRemoteContentKeys: [String]

    init(
        profile: LearningProfile,
        savedWords: [SavedVocabularyItem],
        moduleStats: [LearningModuleStat],
        cachedSentences: [CachedSentence],
        errorPatterns: [LearningErrorPattern] = [],
        apiLearnerId: String = "ios-\(UUID().uuidString)",
        completedRemoteContentKeys: [String] = []
    ) {
        self.profile = profile
        self.savedWords = savedWords
        self.moduleStats = moduleStats
        self.cachedSentences = cachedSentences
        self.errorPatterns = errorPatterns
        self.apiLearnerId = apiLearnerId
        self.completedRemoteContentKeys = completedRemoteContentKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(LearningProfile.self, forKey: .profile)
        savedWords = try container.decode([SavedVocabularyItem].self, forKey: .savedWords)
        moduleStats = try container.decode([LearningModuleStat].self, forKey: .moduleStats)
        cachedSentences = try container.decode([CachedSentence].self, forKey: .cachedSentences)
        errorPatterns = try container.decodeIfPresent([LearningErrorPattern].self, forKey: .errorPatterns) ?? []
        apiLearnerId = try container.decodeIfPresent(String.self, forKey: .apiLearnerId) ?? "ios-\(UUID().uuidString)"
        completedRemoteContentKeys = try container.decodeIfPresent([String].self, forKey: .completedRemoteContentKeys) ?? []
    }
}

extension LearningProgressStore {
    static var preview: LearningProgressStore {
        let store = LearningProgressStore()
        store.profile = LearningProfile(onboardingCompleted: true, level: .intermediate, focus: .songs, dailyGoalMinutes: 15, streak: 3, lastPracticeDay: Date())
        store.savedWords = [
            SavedVocabularyItem(word: "belong", note: "pertenecer / encajar", source: "Preview"),
            SavedVocabularyItem(word: "through", note: "a traves de / por", source: "Preview")
        ]
        store.moduleStats = [
            LearningModuleStat(module: "vocabulary", attempts: 8, correct: 6, lastPracticedAt: Date())
        ]
        store.errorPatterns = [
            LearningErrorPattern(module: "sentences", expected: "although", actual: "because", context: "Conectores"),
            LearningErrorPattern(module: "listening", expected: "could you say that one more time", actual: "can you say one more time", context: "Dictado")
        ]
        return store
    }
}
