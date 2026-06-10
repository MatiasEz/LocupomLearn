import Foundation

struct WordToolkit {
    let word: String
    let phonetic: String?
    let audioURL: URL?
    let definitions: [WordDefinition]
    let relatedWords: [WordSuggestion]
    let examples: [SentenceExample]

    var hasContent: Bool {
        !definitions.isEmpty || !relatedWords.isEmpty || !examples.isEmpty
    }
}

struct WordDefinition: Identifiable, Hashable {
    let id = UUID()
    let partOfSpeech: String
    let text: String
    let example: String?
}

struct WordSuggestion: Identifiable, Hashable {
    let id = UUID()
    let word: String
    let kind: String
}

struct SentenceExample: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let translation: String?
    let sourceLanguage: String
    let targetLanguage: String?
}

struct WritingCorrection: Identifiable, Hashable {
    let id = UUID()
    let message: String
    let shortMessage: String?
    let ruleDescription: String
    let context: String
    let offset: Int
    let length: Int
    let replacements: [String]
    let category: String

    var displayMessage: String {
        shortMessage?.isEmpty == false ? shortMessage! : message
    }
}

struct TranslationResult: Hashable {
    let original: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let confidence: Double?
}

enum LanguageLearningError: LocalizedError {
    case invalidQuery
    case invalidResponse
    case server(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Escribi una palabra o frase para buscar."
        case .invalidResponse:
            return "La API devolvio una respuesta que no pude leer."
        case .server(let statusCode):
            return "La API respondio con estado \(statusCode)."
        }
    }
}

struct LanguageLearningService {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func fetchWordToolkit(word: String) async -> WordToolkit {
        let cleanWord = word.trimmedForAPI

        guard !cleanWord.isEmpty else {
            return WordToolkit(
                word: word,
                phonetic: nil,
                audioURL: nil,
                definitions: [],
                relatedWords: [],
                examples: []
            )
        }

        async let dictionaryTask = safeDictionary(word: cleanWord)
        async let relatedTask = fetchRelatedWords(word: cleanWord)
        async let examplesTask = fetchSentenceExamples(word: cleanWord)

        let (dictionary, relatedWords, examples) = await (dictionaryTask, relatedTask, examplesTask)

        return WordToolkit(
            word: dictionary?.word ?? cleanWord,
            phonetic: dictionary?.phonetic,
            audioURL: dictionary?.audioURL,
            definitions: dictionary?.definitions ?? [],
            relatedWords: relatedWords,
            examples: examples
        )
    }

    func fetchDictionary(word: String) async throws -> WordLookupResult {
        let cleanWord = word.trimmedForAPI
        guard !cleanWord.isEmpty else { throw LanguageLearningError.invalidQuery }

        let escapedWord = cleanWord.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanWord
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(escapedWord)") else {
            throw LanguageLearningError.invalidQuery
        }

        let entries = try await decode([DictionaryAPIEntry].self, from: url)
        guard let firstEntry = entries.first else {
            throw LanguageLearningError.invalidResponse
        }

        let definitions = entries.flatMap { entry in
            entry.meanings.flatMap { meaning in
                meaning.definitions.prefix(3).map { definition in
                    WordDefinition(
                        partOfSpeech: meaning.partOfSpeech,
                        text: definition.definition,
                        example: definition.example
                    )
                }
            }
        }

        let audio = entries
            .flatMap(\.phonetics)
            .compactMap(\.audio)
            .first { !$0.isEmpty }
            .flatMap(URL.init(string:))

        let phonetic = firstEntry.phonetic
            ?? entries.flatMap(\.phonetics).compactMap(\.text).first

        return WordLookupResult(
            word: firstEntry.word,
            phonetic: phonetic,
            audioURL: audio,
            definitions: Array(definitions.prefix(6))
        )
    }

    func fetchRelatedWords(word: String) async -> [WordSuggestion] {
        let cleanWord = word.trimmedForAPI
        guard !cleanWord.isEmpty else { return [] }

        async let synonymsTask: [WordSuggestion] = fetchDatamuseWords(
            parameter: "rel_syn",
            value: cleanWord,
            kind: "Sinonimo"
        )
        async let relatedTask: [WordSuggestion] = fetchDatamuseWords(
            parameter: "ml",
            value: cleanWord,
            kind: "Relacionado"
        )

        let synonyms = (try? await synonymsTask) ?? []
        let related = (try? await relatedTask) ?? []

        var seen = Set<String>()
        return (synonyms + related).filter { suggestion in
            seen.insert(suggestion.word.lowercased()).inserted
        }
        .prefix(12)
        .map { $0 }
    }

    func fetchSentenceExamples(word: String, limit: Int = 6) async -> [SentenceExample] {
        let cleanWord = word.trimmedForAPI
        guard !cleanWord.isEmpty else { return [] }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.tatoeba.org"
        components.path = "/v1/sentences"
        components.queryItems = [
            URLQueryItem(name: "lang", value: "eng"),
            URLQueryItem(name: "q", value: cleanWord),
            URLQueryItem(name: "trans:lang", value: "spa"),
            URLQueryItem(name: "trans:is_direct", value: "yes"),
            URLQueryItem(name: "is_unapproved", value: "no"),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components.url else { return [] }

        do {
            let response = try await decode(TatoebaResponse.self, from: url)
            return response.data.map { sentence in
                let translation = sentence.translations.first { $0.lang == "spa" }
                return SentenceExample(
                    text: sentence.text,
                    translation: translation?.text,
                    sourceLanguage: sentence.lang,
                    targetLanguage: translation?.lang
                )
            }
        } catch {
            return []
        }
    }

    func fetchPracticeSentences(seedWords: [String], level: LearningLevel, limit: Int = 8) async -> [SentenceExample] {
        let cleanSeeds = seedWords
            .map(\.trimmedForAPI)
            .filter { !$0.isEmpty }
            .prefix(4)

        guard !cleanSeeds.isEmpty else { return [] }

        var gathered: [SentenceExample] = []
        for seed in cleanSeeds {
            gathered.append(contentsOf: await fetchSentenceExamples(word: seed, limit: 24))
        }

        var seen = Set<String>()
        let filtered = gathered.filter { example in
            let normalizedText = TextMatcher.normalize(example.text)
            let wordCount = normalizedText.split(separator: " ").count

            guard !normalizedText.isEmpty,
                  level.sentenceWordRange.contains(wordCount),
                  example.translation?.trimmedForAPI.isEmpty == false,
                  !example.text.contains("\n") else {
                return false
            }

            return seen.insert(normalizedText).inserted
        }

        return Array(filtered.shuffled().prefix(limit))
    }

    func checkWriting(text: String, language: String = "en-US") async throws -> [WritingCorrection] {
        let cleanText = text.trimmedForAPI
        guard !cleanText.isEmpty else { throw LanguageLearningError.invalidQuery }

        guard let url = URL(string: "https://api.languagetool.org/v2/check") else {
            throw LanguageLearningError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "text", value: cleanText)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let response = try await decode(LanguageToolResponse.self, from: request)
        return response.matches.prefix(12).map { match in
            WritingCorrection(
                message: match.message,
                shortMessage: match.shortMessage,
                ruleDescription: match.rule.description,
                context: match.context.text,
                offset: match.offset,
                length: match.length,
                replacements: match.replacements.prefix(4).map(\.value),
                category: match.rule.category.name
            )
        }
    }

    func translate(text: String, sourceLanguage: String = "en", targetLanguage: String = "es") async throws -> TranslationResult {
        let cleanText = text.trimmedForAPI
        guard !cleanText.isEmpty else { throw LanguageLearningError.invalidQuery }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.mymemory.translated.net"
        components.path = "/get"
        components.queryItems = [
            URLQueryItem(name: "q", value: String(cleanText.prefix(480))),
            URLQueryItem(name: "langpair", value: "\(sourceLanguage)|\(targetLanguage)")
        ]

        guard let url = components.url else { throw LanguageLearningError.invalidQuery }

        let response = try await decode(MyMemoryResponse.self, from: url)
        let translated = response.responseData.translatedText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !translated.isEmpty else {
            throw LanguageLearningError.invalidResponse
        }

        return TranslationResult(
            original: cleanText,
            translatedText: translated,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            confidence: response.responseData.match
        )
    }

    private func safeDictionary(word: String) async -> WordLookupResult? {
        try? await fetchDictionary(word: word)
    }

    private func fetchDatamuseWords(parameter: String, value: String, kind: String) async throws -> [WordSuggestion] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.datamuse.com"
        components.path = "/words"
        components.queryItems = [
            URLQueryItem(name: parameter, value: value),
            URLQueryItem(name: "max", value: "8")
        ]

        guard let url = components.url else { throw LanguageLearningError.invalidQuery }

        let words = try await decode([DatamuseWord].self, from: url)
        return words.map { WordSuggestion(word: $0.word, kind: kind) }
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LanguageLearningError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LanguageLearningError.server(statusCode: httpResponse.statusCode)
        }
    }
}

struct WordLookupResult {
    let word: String
    let phonetic: String?
    let audioURL: URL?
    let definitions: [WordDefinition]
}

private struct DictionaryAPIEntry: Decodable {
    let word: String
    let phonetic: String?
    let phonetics: [DictionaryAPIPhonetic]
    let meanings: [DictionaryAPIMeaning]
}

private struct DictionaryAPIPhonetic: Decodable {
    let text: String?
    let audio: String?
}

private struct DictionaryAPIMeaning: Decodable {
    let partOfSpeech: String
    let definitions: [DictionaryAPIDefinition]
}

private struct DictionaryAPIDefinition: Decodable {
    let definition: String
    let example: String?
}

private struct DatamuseWord: Decodable {
    let word: String
}

private struct TatoebaResponse: Decodable {
    let data: [TatoebaSentence]
}

private struct TatoebaSentence: Decodable {
    let text: String
    let lang: String
    let translations: [TatoebaTranslation]
}

private struct TatoebaTranslation: Decodable {
    let text: String
    let lang: String
}

private struct LanguageToolResponse: Decodable {
    let matches: [LanguageToolMatch]
}

private struct LanguageToolMatch: Decodable {
    let message: String
    let shortMessage: String?
    let replacements: [LanguageToolReplacement]
    let offset: Int
    let length: Int
    let context: LanguageToolContext
    let rule: LanguageToolRule
}

private struct LanguageToolReplacement: Decodable {
    let value: String
}

private struct LanguageToolContext: Decodable {
    let text: String
}

private struct LanguageToolRule: Decodable {
    let description: String
    let category: LanguageToolCategory
}

private struct LanguageToolCategory: Decodable {
    let name: String
}

private struct MyMemoryResponse: Decodable {
    let responseData: MyMemoryResponseData
}

private struct MyMemoryResponseData: Decodable {
    let translatedText: String
    let match: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translatedText = try container.decode(String.self, forKey: .translatedText)

        if let doubleMatch = try? container.decode(Double.self, forKey: .match) {
            match = doubleMatch
        } else if let stringMatch = try? container.decode(String.self, forKey: .match) {
            match = Double(stringMatch)
        } else {
            match = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case translatedText
        case match
    }
}

private extension String {
    var trimmedForAPI: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
