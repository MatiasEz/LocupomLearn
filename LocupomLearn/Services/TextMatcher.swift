import Foundation

enum TextComparisonStatus: Hashable {
    case exact
    case close
    case wrong
    case missing
    case extra
}

struct TextComparisonToken: Identifiable, Hashable {
    let id = UUID()
    let expected: String
    let actual: String?
    let status: TextComparisonStatus
}

enum TextMatcher {
    struct Result {
        let normalizedAnswer: String
        let normalizedTarget: String
        let similarity: Double

        var isExact: Bool {
            !normalizedTarget.isEmpty && normalizedAnswer == normalizedTarget
        }

        var isCorrect: Bool {
            similarity >= 0.88
        }

        var isClose: Bool {
            similarity >= 0.72
        }
    }

    static func evaluate(answer: String, target: String) -> Result {
        let normalizedAnswer = normalize(answer)
        let normalizedTarget = normalize(target)
        let similarity = similarity(between: normalizedAnswer, and: normalizedTarget)

        return Result(
            normalizedAnswer: normalizedAnswer,
            normalizedTarget: normalizedTarget,
            similarity: similarity
        )
    }

    static func normalize(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces)

        let cleaned = folded.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? String(scalar) : " "
        }
        .joined()

        return cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func similarity(between first: String, and second: String) -> Double {
        if first == second {
            return 1
        }

        guard !first.isEmpty, !second.isEmpty else {
            return 0
        }

        let distance = levenshteinDistance(first, second)
        let longest = max(first.count, second.count)
        return max(0, 1 - (Double(distance) / Double(longest)))
    }

    private static func levenshteinDistance(_ first: String, _ second: String) -> Int {
        let source = Array(first)
        let target = Array(second)

        var previous = Array(0...target.count)
        var current = Array(repeating: 0, count: target.count + 1)

        for sourceIndex in 1...source.count {
            current[0] = sourceIndex

            for targetIndex in 1...target.count {
                let substitutionCost = source[sourceIndex - 1] == target[targetIndex - 1] ? 0 : 1
                current[targetIndex] = min(
                    previous[targetIndex] + 1,
                    current[targetIndex - 1] + 1,
                    previous[targetIndex - 1] + substitutionCost
                )
            }

            swap(&previous, &current)
        }

        return previous[target.count]
    }

    static func wordComparison(answer: String, target: String) -> [TextComparisonToken] {
        let answerWords = normalize(answer).split(separator: " ").map(String.init)
        let targetWords = normalize(target).split(separator: " ").map(String.init)
        let count = max(answerWords.count, targetWords.count)

        return (0..<count).map { index in
            let expected = targetWords.indices.contains(index) ? targetWords[index] : ""
            let actual = answerWords.indices.contains(index) ? answerWords[index] : nil

            guard let actual else {
                return TextComparisonToken(expected: expected, actual: nil, status: .missing)
            }

            guard !expected.isEmpty else {
                return TextComparisonToken(expected: actual, actual: actual, status: .extra)
            }

            if actual == expected {
                return TextComparisonToken(expected: expected, actual: actual, status: .exact)
            }

            let similarity = similarity(between: actual, and: expected)
            return TextComparisonToken(
                expected: expected,
                actual: actual,
                status: similarity >= 0.72 ? .close : .wrong
            )
        }
    }
}
