import Foundation

struct ImportedLyrics {
    let trackName: String
    let artistName: String
    let plainText: String
    let lines: [ImportedLyricLine]
    let usedSyncedTimings: Bool
}

struct ImportedLyricLine {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

enum LyricsImportError: LocalizedError {
    case missingSearchText
    case noMatch
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingSearchText:
            "Agrega un titulo o artista para buscar la letra."
        case .noMatch:
            "No encontre una letra para esa cancion."
        case .invalidResponse:
            "La respuesta de letras no fue valida."
        }
    }
}

struct LyricsImportService {
    private let baseURL = URL(string: "https://lrclib.net/api/search")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchBestMatch(title rawTitle: String, artist rawArtist: String) async throws -> ImportedLyrics {
        let searchTerms = Self.searchTerms(title: rawTitle, artist: rawArtist)
        guard !searchTerms.isEmpty else {
            throw LyricsImportError.missingSearchText
        }

        var records: [LRCLIBRecord] = []
        for term in searchTerms {
            records.append(contentsOf: try await search(term: term))
        }

        let uniqueRecords = Dictionary(grouping: records, by: \.id).compactMap { $0.value.first }
        guard let bestRecord = bestRecord(from: uniqueRecords, title: rawTitle, artist: rawArtist) else {
            throw LyricsImportError.noMatch
        }

        return importedLyrics(from: bestRecord)
    }

    private func search(term: LyricsSearchTerm) async throws -> [LRCLIBRecord] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = term.queryItems

        guard let url = components?.url else {
            throw LyricsImportError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Locupom/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            return []
        }

        return try JSONDecoder().decode([LRCLIBRecord].self, from: data)
    }

    private func bestRecord(from records: [LRCLIBRecord], title: String, artist: String) -> LRCLIBRecord? {
        let cleanedTitle = Self.cleanedSongTitle(from: title)
        let split = Self.splitArtistAndTitle(from: cleanedTitle)
        let expectedTitle = split.title.isEmpty ? cleanedTitle : split.title
        let expectedArtist = artist.trimmed.isEmpty ? split.artist : artist

        return records
            .filter { !$0.isInstrumental && (($0.syncedLyrics?.trimmed.isEmpty == false) || ($0.plainLyrics?.trimmed.isEmpty == false)) }
            .max { first, second in
                score(record: first, expectedTitle: expectedTitle, expectedArtist: expectedArtist) <
                    score(record: second, expectedTitle: expectedTitle, expectedArtist: expectedArtist)
            }
    }

    private func score(record: LRCLIBRecord, expectedTitle: String, expectedArtist: String) -> Double {
        var score = 0.0

        if record.syncedLyrics?.trimmed.isEmpty == false {
            score += 4
        }

        if record.plainLyrics?.trimmed.isEmpty == false {
            score += 2
        }

        score += TextMatcher.evaluate(answer: record.trackName, target: expectedTitle).similarity * 3

        if !expectedArtist.trimmed.isEmpty {
            score += TextMatcher.evaluate(answer: record.artistName, target: expectedArtist).similarity * 2
        }

        return score
    }

    private func importedLyrics(from record: LRCLIBRecord) -> ImportedLyrics {
        if let syncedLyrics = record.syncedLyrics?.trimmed, !syncedLyrics.isEmpty {
            let syncedLines = Self.parseSyncedLyrics(syncedLyrics, duration: record.duration)
            if !syncedLines.isEmpty {
                return ImportedLyrics(
                    trackName: record.trackName,
                    artistName: record.artistName,
                    plainText: syncedLines.map(\.text).joined(separator: "\n"),
                    lines: syncedLines,
                    usedSyncedTimings: true
                )
            }
        }

        let plainLyrics = record.plainLyrics?.trimmed ?? ""
        let plainLines = Self.plainLines(from: plainLyrics)

        return ImportedLyrics(
            trackName: record.trackName,
            artistName: record.artistName,
            plainText: plainLines.map(\.text).joined(separator: "\n"),
            lines: plainLines,
            usedSyncedTimings: false
        )
    }

    private static func searchTerms(title: String, artist: String) -> [LyricsSearchTerm] {
        let cleanedTitle = cleanedSongTitle(from: title)
        let split = splitArtistAndTitle(from: cleanedTitle)
        let inferredArtist = artist.trimmed.isEmpty ? split.artist : artist.trimmed
        let inferredTitle = split.title.isEmpty ? cleanedTitle : split.title

        let candidates: [LyricsSearchTerm] = [
            .keyword([inferredArtist, inferredTitle].filter { !$0.isEmpty }.joined(separator: " ")),
            .track(title: inferredTitle, artist: inferredArtist),
            .track(title: cleanedTitle, artist: artist.trimmed),
            .keyword(cleanedTitle)
        ]

        var seen = Set<String>()
        return candidates.filter { term in
            let key = term.cacheKey
            guard !key.isEmpty, !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    private static func cleanedSongTitle(from rawTitle: String) -> String {
        var value = rawTitle.trimmed

        let parentheticalPatterns = [
            #"\([^)]*(official|video|lyrics?|audio|visualizer|mv|hd|4k)[^)]*\)"#,
            #"\[[^\]]*(official|video|lyrics?|audio|visualizer|mv|hd|4k)[^\]]*\]"#
        ]

        for pattern in parentheticalPatterns {
            value = value.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmed
    }

    private static func splitArtistAndTitle(from value: String) -> (artist: String, title: String) {
        let separators = [" - ", " – ", " — "]
        for separator in separators where value.contains(separator) {
            let parts = value.components(separatedBy: separator)
            guard parts.count >= 2 else {
                continue
            }

            return (
                artist: parts[0].trimmed,
                title: parts.dropFirst().joined(separator: separator).trimmed
            )
        }

        return ("", value.trimmed)
    }

    private static func parseSyncedLyrics(_ value: String, duration: TimeInterval) -> [ImportedLyricLine] {
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        var timedLines: [(text: String, startTime: TimeInterval)] = []

        for rawLine in value.components(separatedBy: .newlines) {
            let line = rawLine.trimmed
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, range: range)
            guard let lastMatch = matches.last else {
                continue
            }

            let textStart = Range(lastMatch.range, in: line)?.upperBound ?? line.startIndex
            let text = String(line[textStart...]).trimmed
            guard !text.isEmpty else {
                continue
            }

            for match in matches {
                guard
                    let minutesRange = Range(match.range(at: 1), in: line),
                    let secondsRange = Range(match.range(at: 2), in: line)
                else {
                    continue
                }

                let minutes = Double(line[minutesRange]) ?? 0
                let seconds = Double(line[secondsRange]) ?? 0
                var fraction = 0.0

                if let fractionRange = Range(match.range(at: 3), in: line) {
                    let rawFraction = String(line[fractionRange])
                    fraction = (Double(rawFraction) ?? 0) / pow(10, Double(rawFraction.count))
                }

                timedLines.append((text: text, startTime: minutes * 60 + seconds + fraction))
            }
        }

        let sortedLines = timedLines.sorted { $0.startTime < $1.startTime }
        return sortedLines.enumerated().map { index, line in
            let nextStart = sortedLines[safe: index + 1]?.startTime
            let fallbackEnd = duration > line.startTime ? min(duration, line.startTime + 5) : line.startTime + 4.5
            let endTime = max(line.startTime + 0.5, nextStart ?? fallbackEnd)

            return ImportedLyricLine(
                text: line.text,
                startTime: line.startTime,
                endTime: endTime
            )
        }
    }

    private static func plainLines(from value: String) -> [ImportedLyricLine] {
        value.components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, text in
                let start = TimeInterval(index) * 5
                return ImportedLyricLine(
                    text: text,
                    startTime: start,
                    endTime: start + 4.5
                )
            }
    }
}

private struct LRCLIBRecord: Decodable {
    let id: Int
    let trackName: String
    let artistName: String
    let duration: TimeInterval
    let isInstrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?

    enum CodingKeys: String, CodingKey {
        case id
        case trackName
        case artistName
        case duration
        case isInstrumental = "instrumental"
        case plainLyrics
        case syncedLyrics
    }
}

private enum LyricsSearchTerm {
    case keyword(String)
    case track(title: String, artist: String)

    var queryItems: [URLQueryItem] {
        switch self {
        case let .keyword(query):
            return [URLQueryItem(name: "q", value: query.trimmed)]
        case let .track(title, artist):
            var items = [URLQueryItem(name: "track_name", value: title.trimmed)]
            if !artist.trimmed.isEmpty {
                items.append(URLQueryItem(name: "artist_name", value: artist.trimmed))
            }
            return items
        }
    }

    var cacheKey: String {
        queryItems
            .map { "\($0.name)=\(($0.value ?? "").lowercased())" }
            .joined(separator: "&")
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
