import Foundation

enum YouTubeTrendingService {
    static func fetchTrendingMusic(apiKey: String, regionCode: String, maxResults: Int = 25) async throws -> [TrendingVideo] {
        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAPIKey.isEmpty else {
            throw TrendingError.missingAPIKey
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "chart", value: "mostPopular"),
            URLQueryItem(name: "videoCategoryId", value: "10"),
            URLQueryItem(name: "regionCode", value: regionCode),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "key", value: cleanAPIKey)
        ]

        guard let url = components?.url else {
            throw TrendingError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let apiError = try? JSONDecoder.youtube.decode(YouTubeAPIErrorResponse.self, from: data)
            throw TrendingError.api(apiError?.error.message ?? "YouTube respondio con HTTP \(httpResponse.statusCode).")
        }

        let decoded = try JSONDecoder.youtube.decode(YouTubeVideosResponse.self, from: data)
        return decoded.items.map { item in
            TrendingVideo(
                id: item.id,
                title: item.snippet.title,
                channelTitle: item.snippet.channelTitle,
                thumbnailURL: item.snippet.thumbnails.bestURL,
                publishedAt: item.snippet.publishedAt
            )
        }
    }
}

enum TrendingError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Agrega una API key de YouTube Data API para cargar tendencias."
        case .invalidURL:
            return "No se pudo crear la URL de YouTube Data API."
        case let .api(message):
            return message
        }
    }
}

private struct YouTubeVideosResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: String
        let snippet: Snippet
    }

    struct Snippet: Decodable {
        let title: String
        let channelTitle: String
        let publishedAt: Date?
        let thumbnails: Thumbnails
    }

    struct Thumbnails: Decodable {
        let `default`: Thumbnail?
        let medium: Thumbnail?
        let high: Thumbnail?
        let standard: Thumbnail?
        let maxres: Thumbnail?

        var bestURL: URL? {
            maxres?.url ?? standard?.url ?? high?.url ?? medium?.url ?? `default`?.url
        }
    }

    struct Thumbnail: Decodable {
        let url: URL
    }
}

private struct YouTubeAPIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

private extension JSONDecoder {
    static var youtube: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
