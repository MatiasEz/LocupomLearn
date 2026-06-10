import Foundation

struct Song: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var artist: String
    var language: String
    var youtubeURL: String
    var videoID: String
    var lines: [LyricLine]
    var createdAt: Date
    var updatedAt: Date
    var practiceStats: PracticeStats

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sin titulo" : title
    }

    var displaySubtitle: String {
        let cleanedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedArtist.isEmpty ? language : "\(cleanedArtist) • \(language)"
    }

    var sortedLines: [LyricLine] {
        lines.sorted {
            if $0.startTime == $1.startTime {
                return $0.index < $1.index
            }
            return $0.startTime < $1.startTime
        }
    }
}

struct LyricLine: Identifiable, Codable, Equatable {
    var id: UUID
    var index: Int
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval

    var duration: TimeInterval {
        max(0, endTime - startTime)
    }
}

struct PracticeStats: Codable, Equatable {
    var attempts: Int
    var correct: Int
    var lastPracticedAt: Date?

    static let empty = PracticeStats(attempts: 0, correct: 0, lastPracticedAt: nil)

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts)
    }

    mutating func recordAttempt(wasCorrect: Bool) {
        attempts += 1
        if wasCorrect {
            correct += 1
        }
        lastPracticedAt = Date()
    }
}
