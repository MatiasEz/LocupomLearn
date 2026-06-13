import Foundation

struct LocupomRemoteTopic: Identifiable, Decodable {
    let id: String
    let title: String
    let level: String
    let category: String
    let summary: String
    let pattern: String
    let learningObjectives: [String]
    let examples: [String]
    let commonMistakes: [String]
    let practiceIdeas: [String]
    let quiz: LocupomRemoteTopicQuiz
}

struct LocupomRemoteTopicQuiz: Decodable {
    let question: String
    let options: [String]
    let answer: String
    let explanation: String
}

struct LocupomTopicsResponse: Decodable {
    let count: Int
    let topics: [LocupomRemoteTopic]
}

enum LocupomTopicsAPIClient {
    static let baseURL = URL(string: "https://locupom-topics-api.vercel.app")!

    static func fetchGrammarTopics(levels: [String]) async throws -> [LocupomRemoteTopic] {
        var fetchedTopics: [LocupomRemoteTopic] = []

        for level in levels {
            fetchedTopics.append(contentsOf: try await fetchGrammarTopics(level: level))
        }

        return fetchedTopics
    }

    private static func fetchGrammarTopics(level: String) async throws -> [LocupomRemoteTopic] {
        var components = URLComponents(url: baseURL.appending(path: "topics"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "level", value: level)
        ]

        guard let url = components.url else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            return []
        }

        return try JSONDecoder().decode(LocupomTopicsResponse.self, from: data).topics
    }
}
